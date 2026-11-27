import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import 'member_lookup.dart';

abstract class OfferRepository {
  Stream<List<MarketOffer>> watchMadeOffers(String uid);
  Stream<List<MarketOffer>> watchReceivedOffers(String uid);
  Stream<Set<String>> watchReadNotifications(String uid);
  Future<void> saveReadNotifications(String uid, Set<String> ids);
  Future<String?> fetchBuyerHandoverPin(String offerId);

  Future<String?> verifyOfferEligibility({
    required Listing listing,
    required String buyerUid,
  });

  Future<OfferSubmissionPlan> submitOffer({
    required Listing listing,
    required String buyerUid,
    required String buyerFallbackName,
    required int amount,
    required String message,
    bool feePaid = false,
    String feeTransactionId = '',
  });

  Future<void> transitionOffer({
    required MarketOffer offer,
    required OfferAction action,
    required String actorUid,
    int? counterAmount,
    String? handoverPin,
  });

  Future<void> markExpiredIfDue(List<MarketOffer> offers, String actorUid);

  Future<void> releaseReservedListingWithOffers({
    required Listing listing,
    required String sellerUid,
  });

  Future<void> completeReservedListingBySeller({
    required Listing listing,
    required String sellerUid,
  });
}

class FirestoreOfferRepository implements OfferRepository {
  final FirebaseFirestore _db;

  /// Reserves headroom inside Firestore's 500-operation transaction limit
  /// (1 accepted offer + 1 reserved listing + up to 450 competing declines).
  static const int maxCompetingOffersInTransaction = 450;
  static const int maxOverflowCleanupBatches = 30;
  static const int overflowCleanupBatchSize = 300;

  FirestoreOfferRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<MarketOffer>> watchMadeOffers(String uid) {
    return _db
        .collection('offers')
        .where('buyerId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(MarketOffer.fromSnapshot).toList());
  }

  @override
  Stream<List<MarketOffer>> watchReceivedOffers(String uid) {
    return _db
        .collection('offers')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(MarketOffer.fromSnapshot).toList());
  }

  @override
  Stream<Set<String>> watchReadNotifications(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final saved = snap.data()?['readNotifications'];
      if (saved is List) {
        return saved.map((e) => e.toString()).toSet();
      }
      return const <String>{};
    });
  }

  @override
  Future<void> saveReadNotifications(String uid, Set<String> ids) async {
    await _db.collection('users').doc(uid).set({
      'readNotifications': ids.toList(),
    }, SetOptions(merge: true));
  }

  @override
  Future<String?> fetchBuyerHandoverPin(String offerId) async {
    try {
      final snap = await _db
          .collection('offers')
          .doc(offerId)
          .collection('private')
          .doc('pin')
          .get();
      final code = snap.data()?['code'] as String?;
      return (code != null && code.isNotEmpty) ? code : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> verifyOfferEligibility({
    required Listing listing,
    required String buyerUid,
  }) async {
    if (buyerUid.trim().isEmpty) {
      return 'You must be signed in to make an offer';
    }
    if (listing.sellerId == buyerUid) {
      return 'You cannot make an offer on your own listing';
    }
    final listingSnap = await _db.collection('listings').doc(listing.id).get();
    if (!listingSnap.exists) return 'This listing no longer exists';
    final live = listingSnap.data()!;
    if (live['status'] == 'sold') return 'This listing has already been sold';
    if (live['status'] != 'available') return 'This item is currently reserved';
    final offerSnap =
        await _db.collection('offers').doc('${listing.id}_$buyerUid').get();
    final existing = offerSnap.data();
    if (existing != null) {
      final s = existing['status'];
      if (s == 'accepted' || s == 'completed') {
        return 'You already have an active accepted deal on this listing.';
      }
    }
    return null;
  }

  @override
  Future<OfferSubmissionPlan> submitOffer({
    required Listing listing,
    required String buyerUid,
    required String buyerFallbackName,
    required int amount,
    required String message,
    bool feePaid = false,
    String feeTransactionId = '',
  }) async {
    final buyerMeta =
        await resolveMemberProfile(_db, buyerUid, buyerFallbackName);
    final sellerMeta =
        await resolveMemberProfile(_db, listing.sellerId, listing.sellerName);

    late OfferSubmissionPlan plan;
    await _db.runTransaction((tx) async {
      final listingRef = _db.collection('listings').doc(listing.id);
      final listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists) {
        throw const OfferValidationException(
          'This listing was removed and is no longer available',
        );
      }
      final liveListing = Listing.fromSnapshot(listingSnap);

      final offerRef = _db.collection('offers').doc('${listing.id}_$buyerUid');
      final existingSnap = await tx.get(offerRef);
      final existingOffer = existingSnap.exists
          ? MarketOffer.fromSnapshot(existingSnap)
          : null;

      plan = MarketplaceLogic.validateOfferSubmission(
        buyerUid: buyerUid,
        listing: liveListing,
        amount: amount,
        existingOffer: existingOffer,
      );

      final historyEntry = {
        'by': buyerUid,
        'amount': amount,
        'at': Timestamp.now(),
      };

      final effectiveSellerPhoto = sellerMeta.photoUrl.isNotEmpty
          ? sellerMeta.photoUrl
          : liveListing.sellerPhotoUrl;

      final offerPayload = <String, dynamic>{
        'listingId': liveListing.id,
        'listingTitle': liveListing.title,
        'sellerId': liveListing.sellerId,
        'sellerName': sellerMeta.name,
        'sellerPhotoUrl': effectiveSellerPhoto,
        'buyerId': buyerUid,
        'buyerName': buyerMeta.name,
        'buyerPhotoUrl': buyerMeta.photoUrl,
        'amount': amount,
        'lastUpdatedBy': buyerUid,
        'history': existingSnap.exists
            ? FieldValue.arrayUnion([historyEntry])
            : [historyEntry],
        'message': message.trim(),
        'status': 'pending',
        'isRated': false,
        'feePaid': feePaid || plan.alreadyPaidActive,
        'feeTransactionId': feeTransactionId.isNotEmpty
            ? feeTransactionId
            : (existingOffer?.feeTransactionId ?? ''),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existingSnap.exists || plan.isReopening) {
        offerPayload['createdAt'] = FieldValue.serverTimestamp();
      }
      tx.set(
        offerRef,
        offerPayload,
        SetOptions(merge: true),
      );
    });
    return plan;
  }

  @override
  Future<void> transitionOffer({
    required MarketOffer offer,
    required OfferAction action,
    required String actorUid,
    int? counterAmount,
    String? handoverPin,
  }) async {
    final offerRef = _db.collection('offers').doc(offer.id);
    final listingRef = _db.collection('listings').doc(offer.listingId);

    // Query competing active offers upfront when accepting so every competing
    // offer ref can be read-before-write and declined inside the same transaction.
    List<DocumentReference<Map<String, dynamic>>> competingRefs = const [];
    if (action == OfferAction.accept || action == OfferAction.acceptCounter) {
      final competingSnap = await _db
          .collection('offers')
          .where('listingId', isEqualTo: offer.listingId)
          .where('sellerId', isEqualTo: offer.sellerId)
          .where('status', whereIn: ['pending', 'countered'])
          .limit(maxCompetingOffersInTransaction + 1)
          .get();
      competingRefs = competingSnap.docs
          .where((d) => d.id != offer.id)
          .take(maxCompetingOffersInTransaction)
          .map((d) => d.reference)
          .toList();
    }

    String? refundTxnId;
    final List<String> declinedRefundTxns = [];

    await _db.runTransaction((tx) async {
      // 1. All reads BEFORE any writes (Firestore transaction invariant).
      final offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) {
        throw const OfferValidationException('Offer no longer exists');
      }
      final liveOffer = MarketOffer.fromSnapshot(offerSnap);

      final listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists) {
        throw const OfferValidationException('Listing no longer exists');
      }
      final liveListing = Listing.fromSnapshot(listingSnap);

      final competingSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in competingRefs) {
        competingSnaps.add(await tx.get(ref));
      }

      DocumentSnapshot<Map<String, dynamic>>? pubSellerSnap;
      DocumentSnapshot<Map<String, dynamic>>? pubBuyerSnap;
      if (action == OfferAction.complete && !liveListing.statsCounted) {
        pubSellerSnap = await tx
            .get(_db.collection('public_profiles').doc(liveOffer.sellerId));
        pubBuyerSnap = await tx
            .get(_db.collection('public_profiles').doc(liveOffer.buyerId));
      }

      // 2. Domain state machine validation against live DB state.
      final plan = MarketplaceLogic.validateTransition(
        offer: liveOffer,
        listing: liveListing,
        action: action,
        actorUid: actorUid,
        counterAmount: counterAmount,
        handoverPin: handoverPin,
      );

      // 3. Atomic writes.
      final offerUpdates = <String, dynamic>{
        'status': plan.nextOfferStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (action == OfferAction.counter && counterAmount != null) {
        offerUpdates['amount'] = counterAmount;
        offerUpdates['lastUpdatedBy'] = actorUid;
        offerUpdates['history'] = FieldValue.arrayUnion([
          {'by': actorUid, 'amount': counterAmount, 'at': Timestamp.now()},
        ]);
      }
      if (plan.generatesHandoverPin) {
        final code = (1000 + math.Random().nextInt(9000)).toString();
        offerUpdates['handoverCode'] = code;
      }
      tx.update(offerRef, offerUpdates);

      if (plan.nextListingStatus != null) {
        tx.update(listingRef, {
          'status': plan.nextListingStatus,
          if (plan.nextReservedFor != null) 'reservedFor': plan.nextReservedFor,
          if (plan.markStatsCounted) 'statsCounted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (plan.declinesCompetingOffers) {
        for (final compSnap in competingSnaps) {
          if (!compSnap.exists) continue;
          final cd = compSnap.data() ?? const <String, dynamic>{};
          final cs = cd['status'] as String? ?? '';
          if (cs == 'pending' || cs == 'countered') {
            tx.update(compSnap.reference, {
              'status': 'declined',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            final txn = cd['feeTransactionId'] as String? ?? '';
            if (cd['feePaid'] == true && txn.isNotEmpty) {
              declinedRefundTxns.add(txn);
            }
          }
        }
      }

      if (plan.markStatsCounted) {
        tx.set(
          _db.collection('users').doc(liveOffer.sellerId),
          {
            'soldCount': FieldValue.increment(1),
            'lastCompletedOfferId': liveOffer.id,
          },
          SetOptions(merge: true),
        );
        tx.set(
          _db.collection('users').doc(liveOffer.buyerId),
          {
            'boughtCount': FieldValue.increment(1),
            'lastCompletedOfferId': liveOffer.id,
          },
          SetOptions(merge: true),
        );
        if (pubSellerSnap != null && pubSellerSnap.exists) {
          tx.set(
            _db.collection('public_profiles').doc(liveOffer.sellerId),
            {'soldCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
        if (pubBuyerSnap != null && pubBuyerSnap.exists) {
          tx.set(
            _db.collection('public_profiles').doc(liveOffer.buyerId),
            {'boughtCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
      }

      if ((action == OfferAction.decline ||
              action == OfferAction.declineCounter ||
              action == OfferAction.withdraw) &&
          liveOffer.feePaid &&
          liveOffer.feeTransactionId.isNotEmpty) {
        refundTxnId = liveOffer.feeTransactionId;
      }
    });

    // Bounded post-commit verification & cleanup for:
    // (1) any late concurrent offers created between pre-tx read and commit, and
    // (2) overflow beyond the 450 in-transaction competing-offer cap.
    if (action == OfferAction.accept || action == OfferAction.acceptCounter) {
      await _cleanupRemainingCompetingOffers(
        listingId: offer.listingId,
        sellerId: offer.sellerId,
        acceptedOfferId: offer.id,
        refundTxnsOut: declinedRefundTxns,
      );
    }

    for (final txn in declinedRefundTxns) {
      await _markTxnRefunded(txn);
    }
    if (refundTxnId != null) {
      await _markTxnRefunded(refundTxnId!);
    }
  }

  Future<void> _cleanupRemainingCompetingOffers({
    required String listingId,
    required String sellerId,
    required String acceptedOfferId,
    required List<String> refundTxnsOut,
  }) async {
    for (int batchIndex = 0;
        batchIndex < maxOverflowCleanupBatches;
        batchIndex++) {
      final snap = await _db
          .collection('offers')
          .where('listingId', isEqualTo: listingId)
          .where('sellerId', isEqualTo: sellerId)
          .where('status', whereIn: ['pending', 'countered'])
          .limit(overflowCleanupBatchSize)
          .get();
      final staleDocs =
          snap.docs.where((d) => d.id != acceptedOfferId).toList();
      if (staleDocs.isEmpty) return;

      final batch = _db.batch();
      for (final d in staleDocs) {
        final cd = d.data();
        batch.update(d.reference, {
          'status': 'declined',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final txn = cd['feeTransactionId'] as String? ?? '';
        if (cd['feePaid'] == true && txn.isNotEmpty) {
          refundTxnsOut.add(txn);
        }
      }
      await batch.commit();
      if (staleDocs.length < overflowCleanupBatchSize) return;
    }

    throw const OfferValidationException(
      'Deal accepted and item reserved, but too many competing offers exceeded bounded cleanup budget; remaining stale offers are blocked by rules.',
    );
  }

  @override
  Future<void> markExpiredIfDue(
    List<MarketOffer> offers,
    String actorUid,
  ) async {
    for (final offer in offers) {
      if ((offer.status == 'pending' || offer.status == 'countered') &&
          offer.isExpired) {
        try {
          await _db.collection('offers').doc(offer.id).update({
            'status': 'expired',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // Firestore server `request.time` blocks premature expiry cleanly.
        }
      }
    }
  }

  @override
  Future<void> releaseReservedListingWithOffers({
    required Listing listing,
    required String sellerUid,
  }) async {
    final acceptedOffers = await _db
        .collection('offers')
        .where('listingId', isEqualTo: listing.id)
        .where('sellerId', isEqualTo: sellerUid)
        .where('status', isEqualTo: 'accepted')
        .limit(10)
        .get();

    await _db.runTransaction((tx) async {
      final listingRef = _db.collection('listings').doc(listing.id);
      final listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists) {
        throw const OfferValidationException('Listing no longer exists');
      }
      final liveData = listingSnap.data() ?? const <String, dynamic>{};
      if (liveData['sellerId'] != sellerUid) {
        throw const OfferValidationException(
          'Only the seller can release this listing',
        );
      }
      if (liveData['status'] == 'sold') {
        throw const OfferValidationException(
          'Sold listings cannot be released back to available',
        );
      }

      // Collect candidate offer refs (query + direct reservedFor link) and read
      // every document BEFORE writing (strict Firestore transaction invariant).
      final refsById = <String, DocumentReference<Map<String, dynamic>>>{
        for (final doc in acceptedOffers.docs) doc.id: doc.reference,
      };
      final reservedBuyer = (liveData['reservedFor'] as String? ?? '').trim();
      if (reservedBuyer.isNotEmpty) {
        final directId = '${listing.id}_$reservedBuyer';
        refsById.putIfAbsent(
          directId,
          () => _db.collection('offers').doc(directId),
        );
      }

      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refsById.values) {
        snaps.add(await tx.get(ref));
      }

      for (final snap in snaps) {
        if (!snap.exists) continue;
        if (snap.data()?['status'] == 'accepted') {
          tx.update(snap.reference, {
            'status': 'declined',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      tx.update(listingRef, {
        'status': 'available',
        'reservedFor': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> completeReservedListingBySeller({
    required Listing listing,
    required String sellerUid,
  }) async {
    final acceptedOffers = await _db
        .collection('offers')
        .where('listingId', isEqualTo: listing.id)
        .where('sellerId', isEqualTo: sellerUid)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();

    await _db.runTransaction((tx) async {
      final listingRef = _db.collection('listings').doc(listing.id);
      final listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists) {
        throw const OfferValidationException('Listing no longer exists');
      }
      final listingData = listingSnap.data() ?? const <String, dynamic>{};
      final liveSellerId = listingData['sellerId'] as String? ?? '';
      if (liveSellerId != sellerUid) {
        throw const OfferValidationException(
          'Only the seller can mark this item sold',
        );
      }
      final liveStatus = listingData['status'] as String? ?? 'available';
      if (liveStatus == 'sold') {
        throw const OfferValidationException('This item is already marked sold');
      }
      final liveReservedFor = listingData['reservedFor'] as String? ?? '';

      DocumentReference<Map<String, dynamic>>? offerRef;
      if (acceptedOffers.docs.isNotEmpty) {
        offerRef = acceptedOffers.docs.first.reference;
      } else if (liveReservedFor.isNotEmpty) {
        offerRef = _db.collection('offers').doc('${listing.id}_$liveReservedFor');
      }

      DocumentSnapshot<Map<String, dynamic>>? offerSnap;
      if (offerRef != null) {
        offerSnap = await tx.get(offerRef);
      }

      final hasAcceptedOffer = offerSnap != null &&
          offerSnap.exists &&
          offerSnap.data()?['status'] == 'accepted';

      if (!hasAcceptedOffer) {
        if (liveReservedFor.isNotEmpty) {
          throw const OfferValidationException(
            'Linked accepted offer is missing or already resolved',
          );
        }
        tx.update(listingRef, {
          'status': 'sold',
          'reservedFor': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final offer = MarketOffer.fromSnapshot(offerSnap);
      final alreadyCounted = listingData['statsCounted'] == true;
      final pubSellerSnap =
          await tx.get(_db.collection('public_profiles').doc(sellerUid));
      final pubBuyerSnap =
          await tx.get(_db.collection('public_profiles').doc(offer.buyerId));

      tx.update(offerRef!, {
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(listingRef, {
        'status': 'sold',
        'reservedFor': offer.buyerId,
        'statsCounted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!alreadyCounted) {
        tx.set(
          _db.collection('users').doc(sellerUid),
          {
            'soldCount': FieldValue.increment(1),
            'lastCompletedOfferId': offer.id,
          },
          SetOptions(merge: true),
        );
        tx.set(
          _db.collection('users').doc(offer.buyerId),
          {
            'boughtCount': FieldValue.increment(1),
            'lastCompletedOfferId': offer.id,
          },
          SetOptions(merge: true),
        );
        if (pubSellerSnap.exists) {
          tx.set(
            _db.collection('public_profiles').doc(sellerUid),
            {'soldCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
        if (pubBuyerSnap.exists) {
          tx.set(
            _db.collection('public_profiles').doc(offer.buyerId),
            {'boughtCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
      }
    });
  }

  Future<void> _markTxnRefunded(String txnId) async {
    try {
      final snap = await _db
          .collection('payments')
          .where('transactionId', isEqualTo: txnId)
          .limit(3)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'status': 'refunded'});
      }
    } catch (_) {}
  }
}
