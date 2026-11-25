const crypto = require('crypto');
const express = require('express');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const {
  onDocumentWritten,
  onDocumentCreated,
} = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');

admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const STUDENT_DOMAINS = ['.edu', '.edu.bd', '.ac.bd', '.ac.uk'];

function isStudentEmail(email = '') {
  const lower = String(email).toLowerCase().trim();
  return STUDENT_DOMAINS.some((suffix) => lower.endsWith(suffix));
}

function generatePin() {
  return String(crypto.randomInt(1000, 10000));
}

async function getFeePolicy() {
  const snap = await db.collection('platform_settings').doc('fees').get();
  if (!snap.exists) {
    return { sellerListingFee: 20, buyerOrderFee: 50, feesEnabled: true };
  }
  const d = snap.data() || {};
  return {
    sellerListingFee: Number(d.sellerListingFee ?? 20),
    buyerOrderFee: Number(d.buyerOrderFee ?? 50),
    feesEnabled: d.feesEnabled !== false,
  };
}

async function isUserAdmin(uid) {
  const snap = await db.collection('users').doc(uid).get();
  const d = snap.data() || {};
  return d.role === 'admin' || d.isAdmin === true;
}

async function isUserBanned(uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.data()?.isBanned === true;
}

async function verifyPaymentToken({ paymentId, uid, expectedType, minAmount }) {
  if (minAmount <= 0) return null;
  if (!paymentId) {
    throw new Error('Payment required before completing this action');
  }
  const paySnap = await db.collection('payments').doc(paymentId).get();
  if (!paySnap.exists) {
    throw new Error('Payment record could not be found');
  }
  const pay = paySnap.data() || {};
  if (pay.userId !== uid) throw new Error('Payment belongs to another account');
  if (pay.type !== expectedType) throw new Error('Payment type mismatch');
  if (pay.status !== 'completed') {
    throw new Error(`Payment is not settled (status: ${pay.status})`);
  }
  if (Number(pay.amount || 0) < minAmount) {
    throw new Error('Paid amount is less than current platform fee');
  }
  if (pay.consumed === true) {
    throw new Error('This payment receipt has already been used');
  }
  return paySnap;
}

async function refundPaymentByTxnId(txnId, reason = 'auto_escrow_refund') {
  if (!txnId) return 0;
  const snap = await db
    .collection('payments')
    .where('transactionId', '==', txnId)
    .limit(5)
    .get();
  let refunded = 0;
  const batch = db.batch();
  for (const doc of snap.docs) {
    if (doc.data().status !== 'refunded') {
      batch.update(doc.ref, {
        status: 'refunded',
        refundReason: reason,
        refundedAt: FieldValue.serverTimestamp(),
      });
      refunded += 1;
    }
  }
  if (refunded > 0) await batch.commit();
  return refunded;
}

async function sendPushNotification({ targetUid, title, body, data = {} }) {
  try {
    const tokensSnap = await db
      .collection('users')
      .doc(targetUid)
      .collection('fcmTokens')
      .limit(10)
      .get();
    const tokens = tokensSnap.docs
      .map((d) => d.id)
      .filter((t) => t && t.length > 10);
    if (tokens.length === 0) return;
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
    });
  } catch (err) {
    logger.warn('FCM send skipped', { targetUid, error: err.message });
  }
}

// ============================================================================
// EXPRESS HTTP API (Verified with Firebase Auth ID Tokens)
// ============================================================================
const app = express();
app.use(express.json({ limit: '1mb' }));

// CORS middleware for Flutter Web & mobile HTTP calls
app.use((req, res, next) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  next();
});

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing Bearer authentication token' });
    return;
  }
  try {
    const idToken = header.slice('Bearer '.length).trim();
    const decoded = await admin.auth().verifyIdToken(idToken, true);
    if (await isUserBanned(decoded.uid)) {
      res.status(403).json({ error: 'Your account has been suspended by moderation' });
      return;
    }
    req.auth = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid or expired authentication token' });
  }
}

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'pass-it-on-api',
    sslcommerzConfigured: Boolean(
      process.env.SSLCOMMERZ_STORE_ID && process.env.SSLCOMMERZ_STORE_PASSWORD,
    ),
  });
});

// 1. Initiate Fee Payment (SSLCommerz live checkout if configured, else server-signed sandbox)
app.post('/payments/initiate', requireAuth, async (req, res) => {
  try {
    const { type, method = 'bKash', referenceId = '', referenceTitle = '', phone = '' } = req.body || {};
    if (type !== 'seller_listing_fee' && type !== 'buyer_order_fee') {
      res.status(400).json({ error: 'Unsupported payment type' });
      return;
    }

    const policy = await getFeePolicy();
    const requiredAmount = !policy.feesEnabled
      ? 0
      : type === 'seller_listing_fee'
        ? policy.sellerListingFee
        : policy.buyerOrderFee;

    const userSnap = await db.collection('users').doc(req.auth.uid).get();
    const profile = userSnap.data() || {};
    const userName = profile.name || req.auth.name || 'Campus Trader';
    const userEmail = profile.email || req.auth.email || '';

    const txnId = `PIO-${Date.now().toString(36).toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;

    const storeId = process.env.SSLCOMMERZ_STORE_ID;
    const storePass = process.env.SSLCOMMERZ_STORE_PASSWORD;
    const isLiveSsl = Boolean(storeId && storePass);

    if (isLiveSsl && requiredAmount > 0) {
      const apiBase =
        process.env.SSLCOMMERZ_SANDBOX === 'true'
          ? 'https://sandbox.sslcommerz.com/gwprocess/v4/api.php'
          : 'https://securepay.sslcommerz.com/gwprocess/v4/api.php';
      const baseCallback = process.env.PUBLIC_WEB_URL || 'https://pass-it-on-2f422.web.app';
      const fnBase = process.env.FUNCTIONS_BASE_URL || '';

      const form = new URLSearchParams({
        store_id: storeId,
        store_passwd: storePass,
        total_amount: String(requiredAmount),
        currency: 'BDT',
        tran_id: txnId,
        success_url: `${baseCallback}?payment=success&tran_id=${txnId}`,
        fail_url: `${baseCallback}?payment=failed&tran_id=${txnId}`,
        cancel_url: `${baseCallback}?payment=cancelled&tran_id=${txnId}`,
        ipn_url: `${fnBase}/payments/ipn`,
        product_name: referenceTitle || type,
        product_category: 'MarketplaceFee',
        product_profile: 'general',
        cus_name: userName,
        cus_email: userEmail || 'student@campus.local',
        cus_phone: phone || '01700000000',
        cus_add1: 'Campus Zone',
        cus_city: 'Dhaka',
        cus_country: 'Bangladesh',
        shipping_method: 'NO',
      });

      const gwRes = await fetch(apiBase, {
        method: 'POST',
        body: form,
      });
      const gwData = await gwRes.json();
      if (gwData.status !== 'SUCCESS' || !gwData.GatewayPageURL) {
        res.status(502).json({ error: gwData.failedreason || 'Payment gateway initiation failed' });
        return;
      }

      const payRef = await db.collection('payments').add({
        userId: req.auth.uid,
        userName,
        userEmail,
        type,
        amount: requiredAmount,
        currency: 'BDT',
        method: 'SSLCommerz',
        transactionId: txnId,
        referenceId,
        referenceTitle,
        status: 'pending',
        gatewayMode: 'sslcommerz',
        consumed: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      res.json({
        mode: 'redirect',
        gatewayUrl: gwData.GatewayPageURL,
        paymentId: payRef.id,
        transactionId: txnId,
        amount: requiredAmount,
      });
      return;
    }

    // Server-signed sandbox transaction (when merchant keys are not yet attached).
    // Clients still CANNOT write directly to `payments` due to firestore.rules.
    const payRef = await db.collection('payments').add({
      userId: req.auth.uid,
      userName,
      userEmail,
      type,
      amount: requiredAmount,
      currency: 'BDT',
      method,
      transactionId: txnId,
      referenceId,
      referenceTitle,
      status: 'completed',
      gatewayMode: 'sandbox',
      consumed: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    res.json({
      mode: 'sandbox_completed',
      payment: {
        id: payRef.id,
        userId: req.auth.uid,
        userName,
        userEmail,
        type,
        amount: requiredAmount,
        currency: 'BDT',
        method,
        transactionId: txnId,
        referenceId,
        referenceTitle,
        status: 'completed',
      },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 2. SSLCommerz Server-to-Server IPN Verification Webhook
app.post('/payments/ipn', express.urlencoded({ extended: true }), async (req, res) => {
  try {
    const { tran_id: tranId, val_id: valId, status } = req.body || {};
    if (!tranId || !valId || status !== 'VALID') {
      res.status(400).send('INVALID');
      return;
    }

    const storeId = process.env.SSLCOMMERZ_STORE_ID;
    const storePass = process.env.SSLCOMMERZ_STORE_PASSWORD;
    if (!storeId || !storePass) {
      res.status(500).send('GATEWAY_NOT_CONFIGURED');
      return;
    }

    const valBase =
      process.env.SSLCOMMERZ_SANDBOX === 'true'
        ? 'https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php'
        : 'https://securepay.sslcommerz.com/validator/api/validationserverAPI.php';

    const valUrl = `${valBase}?val_id=${encodeURIComponent(valId)}&store_id=${encodeURIComponent(storeId)}&store_passwd=${encodeURIComponent(storePass)}&format=json`;
    const check = await (await fetch(valUrl)).json();

    if (check.status !== 'VALID' && check.status !== 'VALIDATED') {
      res.status(400).send('VALIDATION_FAILED');
      return;
    }

    const snap = await db
      .collection('payments')
      .where('transactionId', '==', tranId)
      .limit(1)
      .get();

    if (snap.empty) {
      res.status(404).send('NOT_FOUND');
      return;
    }

    const doc = snap.docs[0];
    if (Number(check.amount) >= Number(doc.data().amount || 0)) {
      await doc.ref.update({
        status: 'completed',
        gatewayValId: valId,
        verifiedAt: FieldValue.serverTimestamp(),
      });
    }
    res.status(200).send('OK');
  } catch (err) {
    logger.error('IPN error', err);
    res.status(500).send('ERROR');
  }
});

// 3. Server-verified Listing Publish
app.post('/listings/publish', requireAuth, async (req, res) => {
  try {
    const {
      title = '',
      description = '',
      category = 'Other',
      condition = 'used',
      location = 'Campus Dorm / Hall',
      price = 0,
      negotiable = true,
      images = [],
      paymentId = '',
    } = req.body || {};

    const cleanTitle = String(title).trim();
    const cleanDesc = String(description).trim();
    const intPrice = parseInt(price, 10);
    if (cleanTitle.length < 3 || cleanDesc.length < 5 || !intPrice || intPrice <= 0) {
      res.status(400).json({ error: 'Invalid listing title, description, or price' });
      return;
    }

    const policy = await getFeePolicy();
    const requiredFee = policy.feesEnabled ? policy.sellerListingFee : 0;
    const payDoc = await verifyPaymentToken({
      paymentId,
      uid: req.auth.uid,
      expectedType: 'seller_listing_fee',
      minAmount: requiredFee,
    });

    const userSnap = await db.collection('users').doc(req.auth.uid).get();
    const sellerProfile = userSnap.data() || {};
    const sellerName = sellerProfile.name || req.auth.name || 'Campus Trader';
    const sellerPhotoUrl = sellerProfile.photoUrl || '';
    const cleanImages = Array.isArray(images)
      ? images.map((e) => String(e).trim()).filter(Boolean).slice(0, 3)
      : [];
    const keywords = cleanTitle
      .toLowerCase()
      .replace(/[^\w\s]/g, '')
      .split(/\s+/)
      .filter(Boolean);

    const listingRef = db.collection('listings').doc();
    await db.runTransaction(async (tx) => {
      if (payDoc) {
        tx.update(payDoc.ref, { consumed: true, referenceId: listingRef.id });
      }
      tx.set(listingRef, {
        title: cleanTitle,
        keywords,
        description: cleanDesc,
        category,
        condition,
        location: String(location).trim() || 'Campus Dorm / Hall',
        price: intPrice,
        negotiable: Boolean(negotiable),
        imageUrl: cleanImages[0] || '',
        images: cleanImages,
        sellerId: req.auth.uid,
        sellerName,
        sellerPhotoUrl,
        status: 'available',
        reservedFor: '',
        statsCounted: false,
        feePaid: Boolean(payDoc),
        feeTransactionId: payDoc?.data()?.transactionId || '',
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    res.json({ ok: true, listingId: listingRef.id });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 4. Server-verified Offer Submission
app.post('/offers/submit', requireAuth, async (req, res) => {
  try {
    const { listingId, amount, message = '', paymentId = '' } = req.body || {};
    const intAmount = parseInt(amount, 10);
    if (!listingId || !intAmount || intAmount <= 0) {
      res.status(400).json({ error: 'Valid listingId and positive amount required' });
      return;
    }

    const policy = await getFeePolicy();
    const requiredFee = policy.feesEnabled ? policy.buyerOrderFee : 0;

    const uid = req.auth.uid;
    const offerId = `${listingId}_${uid}`;
    const offerRef = db.collection('offers').doc(offerId);
    const listingRef = db.collection('listings').doc(listingId);

    const userSnap = await db.collection('users').doc(uid).get();
    const buyerProfile = userSnap.data() || {};
    const buyerName = buyerProfile.name || req.auth.name || 'Buyer';
    const buyerPhotoUrl = buyerProfile.photoUrl || '';

    await db.runTransaction(async (tx) => {
      const listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists) throw new Error('This listing no longer exists');
      const live = listingSnap.data();
      if (live.sellerId === uid) throw new Error('You cannot make an offer on your own listing');
      if (live.status !== 'available') throw new Error('This listing is no longer available');

      const offerSnap = await tx.get(offerRef);
      const existing = offerSnap.data();
      if (existing && (existing.status === 'accepted' || existing.status === 'completed')) {
        throw new Error('You already have an active accepted deal for this item');
      }

      const alreadyPaidActive =
        existing && existing.feePaid === true && existing.status === 'pending';

      let payDoc = null;
      if (!alreadyPaidActive && requiredFee > 0) {
        payDoc = await verifyPaymentToken({
          paymentId,
          uid,
          expectedType: 'buyer_order_fee',
          minAmount: requiredFee,
        });
      }

      if (payDoc) {
        tx.update(payDoc.ref, { consumed: true, referenceId: offerId });
      }

      const historyEntry = { by: uid, amount: intAmount, at: Timestamp.now() };
      const reopening =
        !existing || existing.status === 'declined' || existing.status === 'withdrawn';

      tx.set(
        offerRef,
        {
          listingId,
          listingTitle: live.title,
          sellerId: live.sellerId,
          sellerName: live.sellerName || '',
          sellerPhotoUrl: live.sellerPhotoUrl || '',
          buyerId: uid,
          buyerName,
          buyerPhotoUrl,
          amount: intAmount,
          lastUpdatedBy: uid,
          history: existing
            ? FieldValue.arrayUnion(historyEntry)
            : [historyEntry],
          message: String(message).trim(),
          status: 'pending',
          isRated: false,
          feePaid: Boolean(payDoc) || alreadyPaidActive,
          feeTransactionId:
            payDoc?.data()?.transactionId || existing?.feeTransactionId || '',
          createdAt: reopening ? FieldValue.serverTimestamp() : existing.createdAt,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    res.json({ ok: true, offerId });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 5. Atomic Offer Lifecycle Transitions + Private PIN Verification
app.post('/offers/transition', requireAuth, async (req, res) => {
  try {
    const { offerId, action, handoverPin = '', counterAmount = 0 } = req.body || {};
    if (!offerId || !action) {
      res.status(400).json({ error: 'offerId and action are required' });
      return;
    }

    const uid = req.auth.uid;
    const offerRef = db.collection('offers').doc(offerId);
    const pinRef = offerRef.collection('private').doc('pin');

    let acceptedListingId = null;
    let acceptedSellerId = null;
    let refundTxnId = null;

    await db.runTransaction(async (tx) => {
      const offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) throw new Error('Offer no longer exists');
      const current = offerSnap.data();
      const isBuyer = current.buyerId === uid;
      const isSeller = current.sellerId === uid;
      if (!isBuyer && !isSeller) throw new Error('Unauthorized for this offer');

      const listingRef = db.collection('listings').doc(current.listingId);
      const listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists) throw new Error('Listing no longer exists');
      const liveListing = listingSnap.data();

      if (action === 'counter') {
        const amt = parseInt(counterAmount, 10);
        if (!amt || amt <= 0) throw new Error('Counter amount must be positive');
        if (!['pending', 'countered'].includes(current.status)) {
          throw new Error('This offer can no longer be countered');
        }
        tx.update(offerRef, {
          amount: amt,
          status: 'countered',
          lastUpdatedBy: uid,
          updatedAt: FieldValue.serverTimestamp(),
          history: FieldValue.arrayUnion({ by: uid, amount: amt, at: Timestamp.now() }),
        });
      } else if (action === 'accept' || action === 'acceptCounter') {
        if (action === 'accept' && !isSeller) {
          throw new Error('Only the seller can accept a buyer offer');
        }
        if (action === 'acceptCounter' && current.lastUpdatedBy === uid) {
          throw new Error('Wait for the other trader to respond');
        }
        if (!['pending', 'countered'].includes(current.status)) {
          throw new Error('This offer is no longer actionable');
        }
        if (liveListing.status !== 'available') {
          throw new Error('This listing is already reserved or sold');
        }
        const pin = generatePin();
        // Store PIN in private buyer-only subcollection AND keep handoverCode empty on public offer doc.
        tx.set(pinRef, { code: pin, createdAt: FieldValue.serverTimestamp() });
        tx.update(offerRef, {
          status: 'accepted',
          handoverCode: '',
          hasPin: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(listingRef, {
          status: 'reserved',
          reservedFor: current.buyerId,
          updatedAt: FieldValue.serverTimestamp(),
        });
        acceptedListingId = current.listingId;
        acceptedSellerId = current.sellerId;
      } else if (action === 'complete') {
        if (!isSeller) throw new Error('Only the seller completes the handover');
        if (current.status !== 'accepted') {
          throw new Error('Only accepted trades can be completed');
        }
        const pinSnap = await tx.get(pinRef);
        const expected = pinSnap.data()?.code || current.handoverCode || '';
        if (!expected || String(handoverPin).trim() !== expected) {
          throw new Error('Invalid 4-digit handover PIN from buyer');
        }
        const alreadyCounted = liveListing.statsCounted === true;
        tx.update(offerRef, {
          status: 'completed',
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(listingRef, {
          status: 'sold',
          statsCounted: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (!alreadyCounted) {
          tx.set(
            db.collection('users').doc(current.sellerId),
            { soldCount: FieldValue.increment(1) },
            { merge: true },
          );
          tx.set(
            db.collection('users').doc(current.buyerId),
            { boughtCount: FieldValue.increment(1) },
            { merge: true },
          );
        }
      } else if (action === 'decline' || action === 'withdraw') {
        const nextStatus = action === 'withdraw' ? 'withdrawn' : 'declined';
        if (action === 'withdraw' && !isBuyer) {
          throw new Error('Only the buyer can withdraw');
        }
        if (action === 'decline' && !isSeller) {
          throw new Error('Only the seller can decline');
        }
        tx.update(offerRef, {
          status: nextStatus,
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (current.status === 'accepted' && liveListing.status === 'reserved') {
          tx.update(listingRef, {
            status: 'available',
            reservedFor: '',
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        if (current.feePaid === true && current.feeTransactionId) {
          refundTxnId = current.feeTransactionId;
        }
      } else {
        throw new Error(`Unsupported transition action: ${action}`);
      }
    });

    if (acceptedListingId && acceptedSellerId) {
      const competing = await db
        .collection('offers')
        .where('listingId', '==', acceptedListingId)
        .where('sellerId', '==', acceptedSellerId)
        .where('status', 'in', ['pending', 'countered'])
        .get();
      for (const doc of competing.docs) {
        if (doc.id === offerId) continue;
        await doc.ref.update({
          status: 'declined',
          updatedAt: FieldValue.serverTimestamp(),
        });
        const d = doc.data();
        if (d.feePaid === true && d.feeTransactionId) {
          await refundPaymentByTxnId(d.feeTransactionId, 'competing_offer_auto_refund');
        }
      }
    }

    if (refundTxnId) {
      await refundPaymentByTxnId(refundTxnId, `${action}_escrow_refund`);
    }

    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 6. Verified Sale Rating
app.post('/ratings/submit', requireAuth, async (req, res) => {
  try {
    const { listingId, sellerId, stars, comment = '', offerId = '' } = req.body || {};
    const score = parseInt(stars, 10);
    if (!listingId || !sellerId || !score || score < 1 || score > 5) {
      res.status(400).json({ error: 'Valid listingId, sellerId, and stars (1-5) required' });
      return;
    }

    const uid = req.auth.uid;
    const effectiveOfferId = offerId || `${listingId}_${uid}`;

    await db.runTransaction(async (tx) => {
      const offerRef = db.collection('offers').doc(effectiveOfferId);
      const offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) throw new Error('Completed order required before rating');
      const offer = offerSnap.data();
      if (offer.buyerId !== uid || offer.status !== 'completed') {
        throw new Error('Only the verified buyer of a completed trade can submit a rating');
      }

      const ratingRef = db.collection('ratings').doc(listingId);
      const existing = await tx.get(ratingRef);
      if (existing.exists) throw new Error('This sale has already been rated');

      const userSnap = await tx.get(db.collection('users').doc(uid));
      const buyerProfile = userSnap.data() || {};
      const buyerName = buyerProfile.name || req.auth.name || 'Verified Buyer';
      const buyerPhotoUrl = buyerProfile.photoUrl || '';

      tx.set(ratingRef, {
        sellerId,
        buyerId: uid,
        buyerName,
        buyerPhotoUrl,
        stars: score,
        comment: String(comment).trim(),
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        db.collection('users').doc(sellerId),
        {
          ratingSum: FieldValue.increment(score),
          ratingCount: FieldValue.increment(1),
        },
        { merge: true },
      );
      tx.update(offerRef, { isRated: true });
    });

    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// 7. GDPR / App Store Account Deletion
app.post('/account/delete', requireAuth, async (req, res) => {
  try {
    const uid = req.auth.uid;
    const listings = await db.collection('listings').where('sellerId', '==', uid).get();
    const batch = db.batch();
    for (const doc of listings.docs) {
      batch.delete(doc.ref);
    }
    const favs = await db.collection('users').doc(uid).collection('favorites').get();
    for (const doc of favs.docs) {
      batch.delete(doc.ref);
    }
    const phoneRefs = await db.collection('phone_directory').where('uid', '==', uid).get();
    for (const doc of phoneRefs.docs) {
      batch.delete(doc.ref);
    }
    batch.delete(db.collection('public_profiles').doc(uid));
    batch.delete(db.collection('users').doc(uid));
    await batch.commit();

    await admin.auth().deleteUser(uid);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 8. Admin Moderation Endpoints (Ban/Unban User & Issue Refund)
app.post('/admin/banUser', requireAuth, async (req, res) => {
  try {
    if (!(await isUserAdmin(req.auth.uid))) {
      res.status(403).json({ error: 'Administrator permission required' });
      return;
    }
    const { targetUid, banned = true } = req.body || {};
    if (!targetUid || targetUid === req.auth.uid) {
      res.status(400).json({ error: 'Valid targetUid required' });
      return;
    }
    await admin.auth().updateUser(targetUid, { disabled: Boolean(banned) });
    await db.collection('users').doc(targetUid).set(
      { isBanned: Boolean(banned), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    if (banned) {
      const userListings = await db
        .collection('listings')
        .where('sellerId', '==', targetUid)
        .where('status', '==', 'available')
        .get();
      const batch = db.batch();
      for (const doc of userListings.docs) {
        batch.update(doc.ref, { status: 'suspended', updatedAt: FieldValue.serverTimestamp() });
      }
      await batch.commit();
    }
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/admin/refund', requireAuth, async (req, res) => {
  try {
    if (!(await isUserAdmin(req.auth.uid))) {
      res.status(403).json({ error: 'Administrator permission required' });
      return;
    }
    const { paymentId } = req.body || {};
    if (!paymentId) {
      res.status(400).json({ error: 'paymentId required' });
      return;
    }
    await db.collection('payments').doc(paymentId).update({
      status: 'refunded',
      refundReason: 'admin_manual_refund',
      refundedBy: req.auth.uid,
      refundedAt: FieldValue.serverTimestamp(),
    });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

exports.api = onRequest({ region: 'us-central1', cors: true }, app);

// ============================================================================
// FIRESTORE TRIGGERS (Public Profiles, Server Metrics, Push Notifications)
// ============================================================================
exports.onUserWrite = onDocumentWritten('users/{userId}', async (event) => {
  const after = event.data?.after?.data();
  const publicRef = db.collection('public_profiles').doc(event.params.userId);
  if (!after) {
    await publicRef.delete().catch(() => {});
    return;
  }
    await publicRef.set(
    {
      name: after.name || 'PassItOn Member',
      photoUrl: after.photoUrl || '',
      bio: after.bio || '',
      department: after.department || '',
      location: after.location || '',
      batchYear: after.batchYear || '',
      meetupSpot: after.meetupSpot || '',
      phoneVerified: Boolean(after.phoneVerified),
      soldCount: Number(after.soldCount || 0),
      boughtCount: Number(after.boughtCount || 0),
      ratingSum: Number(after.ratingSum || 0),
      ratingCount: Number(after.ratingCount || 0),
      verifiedStudent: Boolean(after.verifiedStudent) || isStudentEmail(after.email),
      isBanned: Boolean(after.isBanned),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
});

exports.onPaymentWrite = onDocumentWritten('payments/{paymentId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();

  let revDelta = 0;
  let refundDelta = 0;
  let sellerDelta = 0;
  let buyerDelta = 0;

  const score = (doc) => {
    if (!doc) return { rev: 0, ref: 0, sell: 0, buy: 0 };
    const amt = Number(doc.amount || 0);
    if (doc.status === 'refunded') return { rev: 0, ref: amt, sell: 0, buy: 0 };
    if (doc.status !== 'completed') return { rev: 0, ref: 0, sell: 0, buy: 0 };
    return {
      rev: amt,
      ref: 0,
      sell: doc.type === 'seller_listing_fee' ? amt : 0,
      buy: doc.type === 'buyer_order_fee' ? amt : 0,
    };
  };

  const b = score(before);
  const a = score(after);
  revDelta = a.rev - b.rev;
  refundDelta = a.ref - b.ref;
  sellerDelta = a.sell - b.sell;
  buyerDelta = a.buy - b.buy;

  if (revDelta || refundDelta || sellerDelta || buyerDelta) {
    await db
      .collection('platform_metrics')
      .doc('global')
      .set(
        {
          totalRevenueBDT: FieldValue.increment(revDelta),
          refundedRevenueBDT: FieldValue.increment(refundDelta),
          sellerRevenueBDT: FieldValue.increment(sellerDelta),
          buyerRevenueBDT: FieldValue.increment(buyerDelta),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }
});

exports.onOfferWrite = onDocumentWritten('offers/{offerId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after || before?.status === after.status && before?.amount === after.amount) {
    return;
  }

  if (after.status === 'pending' && !before) {
    await sendPushNotification({
      targetUid: after.sellerId,
      title: 'New Offer Received',
      body: `${after.buyerName} offered ৳ ${after.amount} on "${after.listingTitle}"`,
      data: { offerId: event.params.offerId, type: 'offer_received' },
    });
  } else if (after.status === 'accepted' && before?.status !== 'accepted') {
    await sendPushNotification({
      targetUid: after.buyerId,
      title: 'Offer Accepted!',
      body: `Your ৳ ${after.amount} offer on "${after.listingTitle}" is reserved. Check your Handover PIN.`,
      data: { offerId: event.params.offerId, type: 'offer_accepted' },
    });
  } else if (after.status === 'countered') {
    const recipient = after.lastUpdatedBy === after.sellerId ? after.buyerId : after.sellerId;
    await sendPushNotification({
      targetUid: recipient,
      title: 'Counter Offer Updated',
      body: `New counter amount: ৳ ${after.amount} on "${after.listingTitle}"`,
      data: { offerId: event.params.offerId, type: 'counter_offer' },
    });
  }
});

exports.onChatMessageCreated = onDocumentCreated(
  'chats/{threadId}/messages/{msgId}',
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const threadSnap = await db.collection('chats').doc(event.params.threadId).get();
    const thread = threadSnap.data();
    if (!thread || !Array.isArray(thread.participants)) return;

    for (const uid of thread.participants) {
      if (uid && uid !== msg.senderId) {
        await sendPushNotification({
          targetUid: uid,
          title: `${msg.senderName || 'Trader'} · ${thread.listingTitle || 'Chat'}`,
          body: String(msg.text || '').slice(0, 120),
          data: { threadId: event.params.threadId, type: 'chat_message' },
        });
      }
    }
  },
);

// Scheduled cleanup for 48-hour stale pending/countered offers
exports.expireStaleOffers = onSchedule('every 60 minutes', async () => {
  const cutoff = Timestamp.fromDate(new Date(Date.now() - 48 * 60 * 60 * 1000));
  const staleSnap = await db
    .collection('offers')
    .where('status', 'in', ['pending', 'countered'])
    .where('createdAt', '<=', cutoff)
    .limit(50)
    .get();

  for (const doc of staleSnap.docs) {
    const d = doc.data();
    await doc.ref.update({
      status: 'expired',
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (d.feePaid === true && d.feeTransactionId) {
      await refundPaymentByTxnId(d.feeTransactionId, 'offer_48h_expired_auto_refund');
    }
  }
});
