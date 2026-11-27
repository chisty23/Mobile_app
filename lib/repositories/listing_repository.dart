import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import 'member_lookup.dart';

class ListingPageResult {
  final List<Listing> items;
  final Object? lastCursor;
  final bool hasMore;

  const ListingPageResult({
    required this.items,
    required this.lastCursor,
    required this.hasMore,
  });
}

abstract class ListingRepository {
  static const int pageSize = 30;

  Stream<ListingPageResult> watchInitialPage({int limit = pageSize});

  Future<ListingPageResult> fetchPage({
    int limit = pageSize,
    Object? startAfter,
  });

  Future<List<Listing>> searchByKeywords(String query, {int limit = pageSize});

  Stream<Set<String>> watchFavoriteIds(String uid);

  Future<Map<String, Map<String, dynamic>>> fetchFavoriteMetadata(String uid);

  Future<List<Listing>> resolveFavoriteListings({
    required Set<String> favoriteIds,
    required Map<String, Map<String, dynamic>> cachedMeta,
    required Map<String, Listing> knownListings,
  });

  Future<void> setFavorite({
    required String uid,
    required Listing listing,
    required bool save,
  });

  Future<Listing?> fetchListingById(String listingId);

  Stream<List<ListingComment>> watchComments(String listingId);

  Future<void> addComment({
    required Listing listing,
    required String authorId,
    required String fallbackAuthorName,
    required String text,
  });

  Future<void> deleteComment(String listingId, String commentId);

  Stream<List<Listing>> watchSellerListings(String sellerId);

  Future<void> createListing({
    required String sellerId,
    required String fallbackSellerName,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> imageUrls,
    bool feePaid = false,
    String feeTransactionId = '',
  });

  Future<void> updateListing({
    required String listingId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> imageUrls,
  });

  Future<void> updateListingStatus({
    required String listingId,
    required String status,
    String reservedFor = '',
  });

  Future<void> deleteListing(String listingId);
}

class FirestoreListingRepository implements ListingRepository {
  final FirebaseFirestore _db;

  FirestoreListingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Query<Map<String, dynamic>> _browseBaseQuery() {
    return _db
        .collection('listings')
        .where('status', whereIn: ['available', 'reserved'])
        .orderBy('createdAt', descending: true);
  }

  @override
  Stream<ListingPageResult> watchInitialPage({
    int limit = ListingRepository.pageSize,
  }) {
    return _browseBaseQuery().limit(limit).snapshots().map((snap) {
      final items = snap.docs.map(Listing.fromSnapshot).toList();
      final cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
      return ListingPageResult(
        items: items,
        lastCursor: cursor,
        hasMore: snap.docs.length >= limit,
      );
    });
  }

  @override
  Future<ListingPageResult> fetchPage({
    int limit = ListingRepository.pageSize,
    Object? startAfter,
  }) async {
    var q = _browseBaseQuery();
    if (startAfter is DocumentSnapshot<Map<String, dynamic>>) {
      q = q.startAfterDocument(startAfter);
    }
    final snap = await q.limit(limit).get();
    final items = snap.docs.map(Listing.fromSnapshot).toList();
    final cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
    return ListingPageResult(
      items: items,
      lastCursor: cursor,
      hasMore: snap.docs.length >= limit,
    );
  }

  @override
  Future<List<Listing>> searchByKeywords(
    String query, {
    int limit = ListingRepository.pageSize,
  }) async {
    final tokens = MarketplaceLogic.tokenizeQuery(query);
    if (tokens.isEmpty) return const [];
    final primaryToken = tokens.first;
    final snap = await _db
        .collection('listings')
        .where('keywords', arrayContains: primaryToken)
        .limit(limit)
        .get();
    return snap.docs
        .map(Listing.fromSnapshot)
        .where((l) => l.status == 'available' || l.status == 'reserved')
        .toList();
  }

  @override
  Stream<Set<String>> watchFavoriteIds(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchFavoriteMetadata(
    String uid,
  ) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .get();
    return {
      for (final doc in snap.docs) doc.id: doc.data(),
    };
  }

  @override
  Future<List<Listing>> resolveFavoriteListings({
    required Set<String> favoriteIds,
    required Map<String, Map<String, dynamic>> cachedMeta,
    required Map<String, Listing> knownListings,
  }) async {
    if (favoriteIds.isEmpty) return const [];

    final missingIds = favoriteIds
        .where((id) => !knownListings.containsKey(id))
        .toList();

    final fetchedById = <String, Listing>{};
    if (missingIds.isNotEmpty) {
      final docs = await Future.wait(
        missingIds.map((id) async {
          try {
            return await _db.collection('listings').doc(id).get();
          } catch (_) {
            return null;
          }
        }),
      );
      for (int i = 0; i < missingIds.length; i++) {
        final id = missingIds[i];
        final doc = docs[i];
        if (doc != null && doc.exists) {
          fetchedById[id] = Listing.fromSnapshot(doc);
        } else {
          final meta = cachedMeta[id] ?? const <String, dynamic>{};
          fetchedById[id] = Listing(
            id: id,
            title: (meta['listingTitle'] as String?)?.trim().isNotEmpty == true
                ? (meta['listingTitle'] as String).trim()
                : 'Saved Listing',
            description: 'This item was removed by its seller.',
            category: (meta['listingCategory'] as String?) ?? 'Other',
            condition: (meta['listingCondition'] as String?) ?? 'used',
            location: (meta['listingLocation'] as String?) ?? 'Campus',
            price: (meta['listingPrice'] as num?)?.toInt() ?? 0,
            negotiable: false,
            imageUrl: (meta['listingImageUrl'] as String?) ?? '',
            images: const [],
            sellerId: (meta['sellerId'] as String?) ?? '',
            sellerName: (meta['sellerName'] as String?)?.trim().isNotEmpty == true
                ? (meta['sellerName'] as String).trim()
                : 'Unknown user',
            sellerPhotoUrl: (meta['sellerPhotoUrl'] as String?) ?? '',
            status: 'deleted',
            reservedFor: '',
          );
        }
      }
    }

    final resolved = <Listing>[];
    for (final id in favoriteIds) {
      final item = knownListings[id] ?? fetchedById[id];
      if (item != null) {
        resolved.add(item);
      }
    }
    return resolved;
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required Listing listing,
    required bool save,
  }) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(listing.id);
    if (!save) {
      await ref.delete();
      return;
    }
    await ref.set({
      'listingId': listing.id,
      'listingTitle': listing.title,
      'listingCategory': listing.category,
      'listingCondition': listing.condition,
      'listingPrice': listing.price,
      'listingLocation': listing.location,
      'listingImageUrl': listing.imageUrl,
      'sellerId': listing.sellerId,
      'sellerName': listing.sellerName,
      'sellerPhotoUrl': listing.sellerPhotoUrl,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Listing?> fetchListingById(String listingId) async {
    if (listingId.trim().isEmpty) return null;
    final doc = await _db.collection('listings').doc(listingId).get();
    if (!doc.exists) return null;
    return Listing.fromSnapshot(doc);
  }

  @override
  Stream<List<ListingComment>> watchComments(String listingId) {
    return _db
        .collection('listings')
        .doc(listingId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(80)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ListingComment.fromSnapshot(d, listingId: listingId))
              .toList(),
        );
  }

  @override
  Future<void> addComment({
    required Listing listing,
    required String authorId,
    required String fallbackAuthorName,
    required String text,
  }) async {
    final meta = await resolveMemberProfile(_db, authorId, fallbackAuthorName);
    await _db
        .collection('listings')
        .doc(listing.id)
        .collection('comments')
        .add({
      'listingId': listing.id,
      'authorId': authorId,
      'authorName': meta.name,
      'authorPhotoUrl': meta.photoUrl,
      'isSeller': authorId == listing.sellerId,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteComment(String listingId, String commentId) async {
    await _db
        .collection('listings')
        .doc(listingId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  @override
  Stream<List<Listing>> watchSellerListings(String sellerId) {
    return _db
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Listing.fromSnapshot).toList();
      list.sort((a, b) {
        final ac = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bc = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bc.compareTo(ac);
      });
      return list;
    });
  }

  @override
  Future<void> createListing({
    required String sellerId,
    required String fallbackSellerName,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> imageUrls,
    bool feePaid = false,
    String feeTransactionId = '',
  }) async {
    final cleanImages =
        imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).take(3).toList();
    final meta = await resolveMemberProfile(_db, sellerId, fallbackSellerName);
    final keywords = MarketplaceLogic.buildTitleKeywords(title);

    await _db.collection('listings').add({
      'title': title.trim(),
      'keywords': keywords,
      'description': description.trim(),
      'category': category,
      'condition': condition,
      'location': location.trim().isEmpty ? 'Campus Dorm / Hall' : location.trim(),
      'price': price,
      'negotiable': negotiable,
      'imageUrl': cleanImages.isNotEmpty ? cleanImages.first : '',
      'images': cleanImages,
      'sellerId': sellerId,
      'sellerName': meta.name,
      'sellerPhotoUrl': meta.photoUrl,
      'status': 'available',
      'reservedFor': '',
      'statsCounted': false,
      'feePaid': feePaid,
      'feeTransactionId': feeTransactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateListing({
    required String listingId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> imageUrls,
  }) async {
    final cleanImages =
        imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).take(3).toList();
    final keywords = MarketplaceLogic.buildTitleKeywords(title);
    await _db.collection('listings').doc(listingId).update({
      'title': title.trim(),
      'keywords': keywords,
      'description': description.trim(),
      'category': category,
      'condition': condition,
      'location': location.trim().isEmpty ? 'Campus Dorm / Hall' : location.trim(),
      'price': price,
      'negotiable': negotiable,
      'imageUrl': cleanImages.isNotEmpty ? cleanImages.first : '',
      'images': cleanImages,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateListingStatus({
    required String listingId,
    required String status,
    String reservedFor = '',
  }) async {
    await _db.collection('listings').doc(listingId).update({
      'status': status,
      'reservedFor': status == 'available' ? '' : reservedFor,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteListing(String listingId) async {
    await _db.collection('listings').doc(listingId).delete();
  }
}
