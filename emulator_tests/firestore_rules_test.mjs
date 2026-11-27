import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test, { after, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  doc,
  getDoc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(__dirname, '..', 'firestore.rules');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'pass-it-on-p07-rules-test',
    firestore: {
      rules: readFileSync(rulesPath, 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

async function seedBaseline({ expiredOffer = false, acceptedOffer = false, soldListing = false } = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'seller1'), {
      uid: 'seller1',
      name: 'Alice Seller',
      email: 'alice@edu.bd',
      role: 'customer',
      isAdmin: false,
      isBanned: false,
      verifiedStudent: true,
      soldCount: 0,
      boughtCount: 0,
      ratingSum: 0,
      ratingCount: 0,
    });
    await setDoc(doc(db, 'public_profiles', 'seller1'), {
      name: 'Alice Seller',
      soldCount: 0,
      boughtCount: 0,
      ratingSum: 0,
      ratingCount: 0,
    });
    await setDoc(doc(db, 'users', 'buyer1'), {
      uid: 'buyer1',
      name: 'Bob Buyer',
      email: 'bob@edu.bd',
      role: 'customer',
      isAdmin: false,
      isBanned: false,
      verifiedStudent: false,
      soldCount: 0,
      boughtCount: 0,
      ratingSum: 0,
      ratingCount: 0,
    });
    await setDoc(doc(db, 'public_profiles', 'buyer1'), {
      name: 'Bob Buyer',
      soldCount: 0,
      boughtCount: 0,
      ratingSum: 0,
      ratingCount: 0,
    });
    await setDoc(doc(db, 'users', 'buyer2'), {
      uid: 'buyer2',
      name: 'Cara Buyer',
      email: 'cara@edu.bd',
      role: 'customer',
      isAdmin: false,
      isBanned: false,
      soldCount: 0,
      boughtCount: 0,
      ratingSum: 0,
      ratingCount: 0,
    });
    await setDoc(doc(db, 'users', 'banned1'), {
      uid: 'banned1',
      name: 'Banned Member',
      role: 'customer',
      isAdmin: false,
      isBanned: true,
      soldCount: 0,
      boughtCount: 0,
      ratingSum: 0,
      ratingCount: 0,
    });
    await setDoc(doc(db, 'listings', 'list1'), {
      sellerId: 'seller1',
      sellerName: 'Alice Seller',
      title: 'Calculus Textbook',
      description: 'Clean 3rd edition copy',
      category: 'Books',
      condition: 'like-new',
      location: 'Main Library',
      price: 500,
      negotiable: true,
      status: soldListing ? 'sold' : acceptedOffer ? 'reserved' : 'available',
      reservedFor: soldListing || acceptedOffer ? 'buyer1' : '',
      statsCounted: soldListing,
    });

    const offerCreatedAt = expiredOffer
      ? Timestamp.fromMillis(Date.now() - 49 * 3600 * 1000)
      : Timestamp.fromMillis(Date.now() - 60 * 1000);

    await setDoc(doc(db, 'offers', 'list1_buyer1'), {
      listingId: 'list1',
      listingTitle: 'Calculus Textbook',
      sellerId: 'seller1',
      sellerName: 'Alice Seller',
      buyerId: 'buyer1',
      buyerName: 'Bob Buyer',
      amount: 450,
      lastUpdatedBy: 'buyer1',
      status: soldListing ? 'completed' : acceptedOffer ? 'accepted' : 'pending',
      isRated: false,
      createdAt: offerCreatedAt,
      updatedAt: offerCreatedAt,
      ...(acceptedOffer || soldListing ? { handoverCode: '4321' } : {}),
    });

    if (!soldListing && !acceptedOffer) {
      await setDoc(doc(db, 'offers', 'list1_buyer2'), {
        listingId: 'list1',
        listingTitle: 'Calculus Textbook',
        sellerId: 'seller1',
        sellerName: 'Alice Seller',
        buyerId: 'buyer2',
        buyerName: 'Cara Buyer',
        amount: 470,
        lastUpdatedBy: 'buyer2',
        status: 'pending',
        isRated: false,
        createdAt: offerCreatedAt,
        updatedAt: offerCreatedAt,
      });
    }
  });
}

test('Users collection locks down cross-user PII reads and blocks role/stat tampering', async () => {
  await seedBaseline();
  const anonDb = testEnv.unauthenticatedContext().firestore();
  const buyerDb = testEnv.authenticatedContext('buyer1').firestore();

  await assertFails(getDoc(doc(anonDb, 'users', 'seller1')));
  await assertFails(getDoc(doc(buyerDb, 'users', 'seller1')));
  await assertSucceeds(getDoc(doc(buyerDb, 'users', 'buyer1')));
  await assertSucceeds(getDoc(doc(anonDb, 'public_profiles', 'seller1')));

  // Privilege escalation & direct stats tampering must fail
  await assertFails(updateDoc(doc(buyerDb, 'users', 'buyer1'), { role: 'admin', isAdmin: true }));
  await assertFails(updateDoc(doc(buyerDb, 'users', 'buyer1'), { verifiedStudent: true }));
  await assertFails(updateDoc(doc(buyerDb, 'users', 'buyer1'), { soldCount: 99 }));
  await assertFails(updateDoc(doc(buyerDb, 'public_profiles', 'buyer1'), { ratingSum: 50, ratingCount: 10 }));
});

test('Banned and unauthenticated users cannot create listings or offers', async () => {
  await seedBaseline();
  const anonDb = testEnv.unauthenticatedContext().firestore();
  const bannedDb = testEnv.authenticatedContext('banned1').firestore();

  await assertFails(
    setDoc(doc(anonDb, 'listings', 'list_anon'), {
      sellerId: 'anon',
      title: 'Illegal',
      price: 100,
      status: 'available',
    }),
  );

  await assertFails(
    setDoc(doc(bannedDb, 'listings', 'list_banned'), {
      sellerId: 'banned1',
      title: 'Banned Item',
      price: 100,
      status: 'available',
    }),
  );

  await assertFails(
    setDoc(doc(bannedDb, 'offers', 'list1_banned1'), {
      listingId: 'list1',
      sellerId: 'seller1',
      buyerId: 'banned1',
      lastUpdatedBy: 'banned1',
      amount: 400,
      status: 'pending',
    }),
  );
});

test('Offers enforce seller-only accept/counter and reject expired actions', async () => {
  await seedBaseline();
  const buyerDb = testEnv.authenticatedContext('buyer1').firestore();
  const buyer2Db = testEnv.authenticatedContext('buyer2').firestore();

  // Buyer cannot accept or counter a pending offer
  await assertFails(
    updateDoc(doc(buyerDb, 'offers', 'list1_buyer1'), {
      status: 'accepted',
      handoverCode: '1111',
    }),
  );
  await assertFails(
    updateDoc(doc(buyerDb, 'offers', 'list1_buyer1'), {
      status: 'countered',
      amount: 460,
      lastUpdatedBy: 'buyer1',
    }),
  );

  // Buyer cannot directly reserve a listing without an acceptCounter tx
  await assertFails(
    updateDoc(doc(buyer2Db, 'listings', 'list1'), {
      status: 'reserved',
      reservedFor: 'buyer2',
      updatedAt: serverTimestamp(),
    }),
  );

  // Expired (>48h) offer cannot be accepted by seller
  await seedBaseline({ expiredOffer: true });
  const sellerDb = testEnv.authenticatedContext('seller1').firestore();
  await assertFails(
    runTransaction(sellerDb, async (tx) => {
      tx.update(doc(sellerDb, 'offers', 'list1_buyer1'), {
        status: 'accepted',
        handoverCode: '1234',
        updatedAt: serverTimestamp(),
      });
      tx.update(doc(sellerDb, 'listings', 'list1'), {
        status: 'reserved',
        reservedFor: 'buyer1',
        updatedAt: serverTimestamp(),
      });
    }),
  );

  // Expired (>48h) offer CAN be transitioned cleanly to expired
  await assertSucceeds(
    updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
      status: 'expired',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('Atomic offer acceptance reserves listing and declines competing offers together', async () => {
  await seedBaseline();
  const sellerDb = testEnv.authenticatedContext('seller1').firestore();

  await assertSucceeds(
    runTransaction(sellerDb, async (tx) => {
      tx.update(doc(sellerDb, 'offers', 'list1_buyer1'), {
        status: 'accepted',
        handoverCode: '9876',
        updatedAt: serverTimestamp(),
      });
      tx.update(doc(sellerDb, 'offers', 'list1_buyer2'), {
        status: 'declined',
        updatedAt: serverTimestamp(),
      });
      tx.update(doc(sellerDb, 'listings', 'list1'), {
        status: 'reserved',
        reservedFor: 'buyer1',
        updatedAt: serverTimestamp(),
      });
    }),
  );
});

test('Ratings require completed sale + verified offer and prevent duplicates or tampering', async () => {
  // Pending offer cannot be rated
  await seedBaseline();
  const buyer1Db = testEnv.authenticatedContext('buyer1').firestore();
  const buyer2Db = testEnv.authenticatedContext('buyer2').firestore();

  await assertFails(
    setDoc(doc(buyer1Db, 'ratings', 'list1'), {
      listingId: 'list1',
      sellerId: 'seller1',
      buyerId: 'buyer1',
      stars: 5,
      comment: 'Premature rating',
    }),
  );

  // Completed sale allows atomic rating + seller stats increment once, blocks bystander & duplicate
  await seedBaseline({ soldListing: true });

  await assertFails(
    setDoc(doc(buyer2Db, 'ratings', 'list1'), {
      listingId: 'list1',
      sellerId: 'seller1',
      buyerId: 'buyer2',
      stars: 1,
      comment: 'Not my trade',
    }),
  );

  await assertSucceeds(
    runTransaction(buyer1Db, async (tx) => {
      tx.set(doc(buyer1Db, 'ratings', 'list1'), {
        listingId: 'list1',
        sellerId: 'seller1',
        buyerId: 'buyer1',
        stars: 5,
        comment: 'Smooth campus meetup',
        createdAt: serverTimestamp(),
      });
      tx.set(
        doc(buyer1Db, 'users', 'seller1'),
        { ratingSum: 5, ratingCount: 1, lastRatingId: 'list1' },
        { merge: true },
      );
      tx.set(
        doc(buyer1Db, 'public_profiles', 'seller1'),
        { ratingSum: 5, ratingCount: 1 },
        { merge: true },
      );
      tx.update(doc(buyer1Db, 'offers', 'list1_buyer1'), { isRated: true });
    }),
  );

  // Duplicate rating must fail
  await assertFails(
    setDoc(doc(buyer1Db, 'ratings', 'list1'), {
      listingId: 'list1',
      sellerId: 'seller1',
      buyerId: 'buyer1',
      stars: 4,
      comment: 'Second try',
    }),
  );
});

test('Seller listing updates restrict protected fields and enforce reservation release consistency', async () => {
  await seedBaseline();
  const sellerDb = testEnv.authenticatedContext('seller1').firestore();

  // Seller cannot spoof protected fields or arbitrarily reserve for a buyer
  await assertFails(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      statsCounted: true,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      feePaid: true,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      status: 'reserved',
      reservedFor: 'buyer1',
      updatedAt: serverTimestamp(),
    }),
  );

  // Seller CAN edit allowed details and manually reserve with reservedFor == ''
  await assertSucceeds(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      title: 'Calculus Textbook (Updated)',
      price: 550,
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      status: 'reserved',
      reservedFor: '',
      updatedAt: serverTimestamp(),
    }),
  );

  // Releasing a buyer-accepted reservation MUST update both listing and accepted offer atomically
  await seedBaseline({ acceptedOffer: true });
  await assertFails(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      status: 'available',
      reservedFor: '',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    runTransaction(sellerDb, async (tx) => {
      tx.update(doc(sellerDb, 'offers', 'list1_buyer1'), {
        status: 'declined',
        updatedAt: serverTimestamp(),
      });
      tx.update(doc(sellerDb, 'listings', 'list1'), {
        status: 'available',
        reservedFor: '',
        updatedAt: serverTimestamp(),
      });
    }),
  );

  // Sold listing details cannot be tampered with by seller
  await seedBaseline({ soldListing: true });
  await assertFails(
    updateDoc(doc(sellerDb, 'listings', 'list1'), {
      price: 1,
      status: 'available',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('Counter-offer turns, buyer reset blocking, premature expiry, and post-reserve stale cleanup', async () => {
  await seedBaseline();
  const sellerDb = testEnv.authenticatedContext('seller1').firestore();
  const buyer1Db = testEnv.authenticatedContext('buyer1').firestore();
  const buyer2Db = testEnv.authenticatedContext('buyer2').firestore();

  // Premature expiry (<48h) MUST fail via server request.time
  await assertFails(
    updateDoc(doc(buyer1Db, 'offers', 'list1_buyer1'), {
      status: 'expired',
      updatedAt: serverTimestamp(),
    }),
  );

  // Buyer updating active pending offer cannot alter createdAt to cheat 48h expiry
  await assertFails(
    updateDoc(doc(buyer1Db, 'offers', 'list1_buyer1'), {
      amount: 460,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  // Seller counters buyer1's pending offer
  await assertSucceeds(
    updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
      status: 'countered',
      amount: 480,
      lastUpdatedBy: 'seller1',
      updatedAt: serverTimestamp(),
    }),
  );

  // Seller CANNOT counter their own previous counter-offer (alternating turn check)
  await assertFails(
    updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
      status: 'countered',
      amount: 490,
      lastUpdatedBy: 'seller1',
      updatedAt: serverTimestamp(),
    }),
  );

  // Buyer CANNOT reset a countered offer back to pending directly
  await assertFails(
    updateDoc(doc(buyer1Db, 'offers', 'list1_buyer1'), {
      status: 'pending',
      amount: 455,
      lastUpdatedBy: 'buyer1',
      updatedAt: serverTimestamp(),
    }),
  );

  // Buyer1 accepts seller's counter atomically, then stale buyer2 cleanup succeeds cleanly
  await assertSucceeds(
    runTransaction(buyer1Db, async (tx) => {
      tx.update(doc(buyer1Db, 'offers', 'list1_buyer1'), {
        status: 'accepted',
        handoverCode: '6543',
        updatedAt: serverTimestamp(),
      });
      tx.update(doc(buyer1Db, 'listings', 'list1'), {
        status: 'reserved',
        reservedFor: 'buyer1',
        updatedAt: serverTimestamp(),
      });
    }),
  );
  // Post-commit overflow/concurrent stale cleanup works for winning buyer AND seller
  await assertSucceeds(
    updateDoc(doc(buyer1Db, 'offers', 'list1_buyer2'), {
      status: 'declined',
      updatedAt: serverTimestamp(),
    }),
  );
  // Competing buyer2 cannot decline buyer1's winning accepted offer
  await assertFails(
    updateDoc(doc(buyer2Db, 'offers', 'list1_buyer1'), {
      status: 'declined',
      updatedAt: serverTimestamp(),
    }),
  );
});


test('Verified handover completion atomically marks offer completed, listing sold, and increments stats cleanly while blocking direct forgery', async () => {
  await seedBaseline({ acceptedOffer: true });
  const sellerDb = testEnv.authenticatedContext('seller1').firestore();
  const buyerDb = testEnv.authenticatedContext('buyer1').firestore();

  // Direct forgery without atomic handover fails
  await assertFails(updateDoc(doc(sellerDb, 'listings', 'list1'), {
    status: 'sold',
    reservedFor: 'buyer1',
    statsCounted: true,
    updatedAt: serverTimestamp(),
  }));

  await assertFails(updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
    status: 'completed',
    updatedAt: serverTimestamp(),
  }));

  await assertFails(updateDoc(doc(sellerDb, 'users', 'seller1'), {
    soldCount: 1,
    lastCompletedOfferId: 'list1_buyer1',
  }));

  await assertFails(updateDoc(doc(buyerDb, 'users', 'buyer1'), {
    boughtCount: 1,
    lastCompletedOfferId: 'list1_buyer1',
  }));

  // Seller still cannot read buyer's private /users doc directly
  await assertFails(getDoc(doc(sellerDb, 'users', 'buyer1')));

  // Atomic verified handover transaction succeeds using FieldValue.increment without reading buyer PII
  await assertSucceeds(runTransaction(sellerDb, async (tx) => {
    const offerRef = doc(sellerDb, 'offers', 'list1_buyer1');
    const listingRef = doc(sellerDb, 'listings', 'list1');
    const sellerRef = doc(sellerDb, 'users', 'seller1');
    const buyerRef = doc(sellerDb, 'users', 'buyer1');
    const pubSellerRef = doc(sellerDb, 'public_profiles', 'seller1');
    const pubBuyerRef = doc(sellerDb, 'public_profiles', 'buyer1');

    const [oSnap, lSnap, psSnap, pbSnap] = await Promise.all([
      tx.get(offerRef),
      tx.get(listingRef),
      tx.get(pubSellerRef),
      tx.get(pubBuyerRef),
    ]);
    assert.equal(oSnap.data().status, 'accepted');
    assert.equal(lSnap.data().status, 'reserved');

    tx.update(offerRef, {
      status: 'completed',
      updatedAt: serverTimestamp(),
    });
    tx.update(listingRef, {
      status: 'sold',
      reservedFor: 'buyer1',
      statsCounted: true,
      updatedAt: serverTimestamp(),
    });
    tx.update(sellerRef, {
      soldCount: increment(1),
      lastCompletedOfferId: 'list1_buyer1',
    });
    tx.update(buyerRef, {
      boughtCount: increment(1),
      lastCompletedOfferId: 'list1_buyer1',
    });
    if (psSnap.exists()) {
      tx.update(pubSellerRef, {
        soldCount: increment(1),
      });
    }
    if (pbSnap.exists()) {
      tx.update(pubBuyerRef, {
        boughtCount: increment(1),
      });
    }
  }));

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    assert.equal((await getDoc(doc(db, 'offers', 'list1_buyer1'))).data().status, 'completed');
    assert.equal((await getDoc(doc(db, 'listings', 'list1'))).data().status, 'sold');
    assert.equal((await getDoc(doc(db, 'listings', 'list1'))).data().statsCounted, true);
    assert.equal((await getDoc(doc(db, 'users', 'seller1'))).data().soldCount, 1);
    assert.equal((await getDoc(doc(db, 'users', 'buyer1'))).data().boughtCount, 1);
    assert.equal((await getDoc(doc(db, 'public_profiles', 'seller1'))).data().soldCount, 1);
    assert.equal((await getDoc(doc(db, 'public_profiles', 'buyer1'))).data().boughtCount, 1);
  });
});

test('Expired offers reject decline, withdraw, counter, and pending edits while premature expiry is blocked', async () => {
  await seedBaseline({ expiredOffer: false });
  const sellerDb = testEnv.authenticatedContext('seller1').firestore();
  const buyerDb = testEnv.authenticatedContext('buyer1').firestore();

  // Premature expiry before 48h is blocked for both parties
  await assertFails(updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
    status: 'expired',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(buyerDb, 'offers', 'list1_buyer1'), {
    status: 'expired',
    updatedAt: serverTimestamp(),
  }));

  await testEnv.clearFirestore();
  await seedBaseline({ expiredOffer: true });

  // Once >48h old, decline, counter, accept, withdraw, and pending edits fail
  await assertFails(updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
    status: 'declined',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(sellerDb, 'offers', 'list1_buyer1'), {
    status: 'countered',
    amount: 480,
    lastUpdatedBy: 'seller1',
    history: [{ by: 'seller1', amount: 480 }],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(buyerDb, 'offers', 'list1_buyer1'), {
    status: 'withdrawn',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(buyerDb, 'offers', 'list1_buyer1'), {
    status: 'pending',
    amount: 460,
    lastUpdatedBy: 'buyer1',
    updatedAt: serverTimestamp(),
  }));

  // Cleanup transition to 'expired' succeeds once >=48h old
  await assertSucceeds(updateDoc(doc(buyerDb, 'offers', 'list1_buyer1'), {
    status: 'expired',
    updatedAt: serverTimestamp(),
  }));
});
