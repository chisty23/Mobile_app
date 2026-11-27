import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';

abstract class RatingRepository {
  Future<void> submitRating({
    required String listingId,
    required String sellerId,
    required String buyerId,
    required String buyerFallbackName,
    required int stars,
    required String comment,
    String? offerId,
  });

  Future<Map<String, dynamic>> fetchSellerPublicData(String sellerId);
}

class FirestoreRatingRepository implements RatingRepository {
  final FirebaseFirestore _db;

  FirestoreRatingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> submitRating({
    required String listingId,
    required String sellerId,
    required String buyerId,
    required String buyerFallbackName,
    required int stars,
    required String comment,
    String? offerId,
  }) async {
    if (stars < 1 || stars > 5) {
      throw const OfferValidationException('Rating must be between 1 and 5 stars');
    }

    String buyerName = buyerFallbackName.trim().isNotEmpty
        ? buyerFallbackName.trim()
        : 'Unknown user';
    String buyerPhotoUrl = '';
    try {
      final buyerPub =
          await _db.collection('public_profiles').doc(buyerId).get();
      final d = buyerPub.data();
      if (d != null) {
        final n = (d['name'] as String?)?.trim() ?? '';
        if (n.isNotEmpty) buyerName = n;
        buyerPhotoUrl = (d['photoUrl'] as String?) ?? '';
      }
    } catch (_) {}

    final effectiveOfferId =
        (offerId != null && offerId.isNotEmpty) ? offerId : '${listingId}_$buyerId';

    await _db.runTransaction((tx) async {
      final ratingRef = _db.collection('ratings').doc(listingId);
      final listingRef = _db.collection('listings').doc(listingId);
      final offerRef = _db.collection('offers').doc(effectiveOfferId);
      final sellerRef = _db.collection('users').doc(sellerId);
      final pubSellerRef = _db.collection('public_profiles').doc(sellerId);

      // All reads before writes.
      final ratingSnap = await tx.get(ratingRef);
      if (ratingSnap.exists) {
        throw const OfferValidationException(
          'This sale has already been rated',
        );
      }

      final listingSnap = await tx.get(listingRef);
      if (!listingSnap.exists || listingSnap.data()?['status'] != 'sold') {
        throw const OfferValidationException(
          'Only completed sales can be rated',
        );
      }
      final liveSellerId = listingSnap.data()?['sellerId'] as String? ?? '';
      if (liveSellerId != sellerId) {
        throw const OfferValidationException(
          'Seller verification mismatch for this listing',
        );
      }

      final offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) {
        throw const OfferValidationException(
          'A completed offer is required before rating',
        );
      }
      final offerData = offerSnap.data()!;
      if (offerData['buyerId'] != buyerId ||
          offerData['listingId'] != listingId ||
          offerData['sellerId'] != sellerId ||
          offerData['status'] != 'completed') {
        throw const OfferValidationException(
          'Only the verified buyer of a completed trade can rate this seller',
        );
      }

      final pubSellerSnap = await tx.get(pubSellerRef);

      tx.set(ratingRef, {
        'listingId': listingId,
        'sellerId': sellerId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerPhotoUrl': buyerPhotoUrl,
        'stars': stars,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        sellerRef,
        {
          'ratingSum': FieldValue.increment(stars),
          'ratingCount': FieldValue.increment(1),
          'lastRatingId': listingId,
        },
        SetOptions(merge: true),
      );
      if (pubSellerSnap.exists) {
        tx.set(
          pubSellerRef,
          {
            'ratingSum': FieldValue.increment(stars),
            'ratingCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      }
      tx.update(offerRef, {'isRated': true});
    });
  }

  @override
  Future<Map<String, dynamic>> fetchSellerPublicData(String sellerId) async {
    Map<String, dynamic> profileData = {};
    try {
      final pubSnap =
          await _db.collection('public_profiles').doc(sellerId).get();
      if (pubSnap.exists && pubSnap.data() != null) {
        profileData = pubSnap.data()!;
      } else {
        // Fallback succeeds only if owner/admin or legacy rule permits it.
        final legacySnap = await _db.collection('users').doc(sellerId).get();
        if (legacySnap.exists && legacySnap.data() != null) {
          profileData = legacySnap.data()!;
        }
      }
    } catch (_) {}

    final reviewsSnap = await _db
        .collection('ratings')
        .where('sellerId', isEqualTo: sellerId)
        .limit(20)
        .get();
    final listingsSnap = await _db
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'available')
        .limit(12)
        .get();

    final reviews = reviewsSnap.docs.map(SellerReview.fromSnapshot).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return {
      'profile': profileData,
      'reviews': reviews,
      'listings': listingsSnap.docs.map(Listing.fromSnapshot).toList(),
    };
  }
}
