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
      verifiedStudent: true,
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
