import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_it_on/domain/marketplace_logic.dart';
import 'package:pass_it_on/models.dart';
import 'package:pass_it_on/providers/app_providers.dart';
import 'package:pass_it_on/repositories/listing_repository.dart';
import 'package:pass_it_on/repositories/offer_repository.dart';
import 'package:pass_it_on/repositories/rating_repository.dart';

Listing _makeListing({
  required String id,
  String title = 'Calculus Textbook',
  String description = 'Clean campus textbook',
  String category = 'Books',
  String condition = 'like-new',
  String location = 'Main Library',
  int price = 500,
  bool negotiable = true,
  String imageUrl = '',
  List<String>? images,
  String sellerId = 'seller_1',
  String sellerName = 'Alice',
  String status = 'available',
  String reservedFor = '',
  bool statsCounted = false,
  DateTime? createdAt,
}) {
  final ts = createdAt != null ? Timestamp.fromDate(createdAt) : null;
  return Listing(
    id: id,
    title: title,
    keywords: MarketplaceLogic.buildTitleKeywords(title),
    description: description,
    category: category,
    condition: condition,
    location: location,
    price: price,
    negotiable: negotiable,
    imageUrl: imageUrl,
    images: images ?? (imageUrl.isNotEmpty ? [imageUrl] : const []),
    sellerId: sellerId,
    sellerName: sellerName,
    status: status,
    reservedFor: reservedFor,
    statsCounted: statsCounted,
    createdAt: ts,
    updatedAt: ts,
  );
}

class _FakeListingRepository implements ListingRepository {
  final List<Listing> store = [];
  final Set<String> favoriteIds = {};
  final Map<String, Map<String, dynamic>> favoriteMeta = {};
  final StreamController<ListingPageResult> _initialController =
      StreamController<ListingPageResult>.broadcast();
  final StreamController<Set<String>> _favController =
      StreamController<Set<String>>.broadcast();
  final StreamController<List<Listing>> _sellerController =
      StreamController<List<Listing>>.broadcast();

  bool failNextSetFavorite = false;
  bool failNextSearch = false;
  bool failNextCreate = false;

  void emitInitialPage({int limit = ListingRepository.pageSize}) {
    final visible = store
        .where((l) => l.status == 'available' || l.status == 'reserved')
        .take(limit)
        .toList();
    _initialController.add(ListingPageResult(
      items: visible,
      lastCursor: visible.isNotEmpty ? visible.length : null,
      hasMore: store
              .where((l) => l.status == 'available' || l.status == 'reserved')
              .length >
          limit,
    ));
  }

  void emitSellerListings(String sellerId) {
    _sellerController.add(store.where((l) => l.sellerId == sellerId).toList());
  }

  @override
  Stream<ListingPageResult> watchInitialPage({
    int limit = ListingRepository.pageSize,
  }) =>
      _initialController.stream;

  @override
  Future<ListingPageResult> fetchPage({
    int limit = ListingRepository.pageSize,
    Object? startAfter,
  }) async {
    final active = store
        .where((l) => l.status == 'available' || l.status == 'reserved')
        .toList();
    final offset = startAfter is int ? startAfter : 0;
    if (offset >= active.length) {
      return const ListingPageResult(items: [], lastCursor: null, hasMore: false);
    }
    final slice = active.skip(offset).take(limit).toList();
    final nextOffset = offset + slice.length;
    return ListingPageResult(
      items: slice,
      lastCursor: nextOffset,
      hasMore: nextOffset < active.length,
    );
  }

  @override
  Future<List<Listing>> searchByKeywords(
    String query, {
    int limit = ListingRepository.pageSize,
  }) async {
    if (failNextSearch) {
      failNextSearch = false;
      throw Exception('Simulated network timeout');
    }
    final tokens = MarketplaceLogic.tokenizeQuery(query);
    if (tokens.isEmpty) return const [];
    final primary = tokens.first;
    return store
        .where((l) =>
            (l.status == 'available' || l.status == 'reserved') &&
            l.keywords.contains(primary))
        .take(limit)
        .toList();
  }

  @override
  Stream<Set<String>> watchFavoriteIds(String uid) => _favController.stream;

  @override
  Future<Map<String, Map<String, dynamic>>> fetchFavoriteMetadata(
    String uid,
  ) async =>
      Map<String, Map<String, dynamic>>.from(favoriteMeta);

  @override
  Future<List<Listing>> resolveFavoriteListings({
    required Set<String> favoriteIds,
    required Map<String, Map<String, dynamic>> cachedMeta,
    required Map<String, Listing> knownListings,
  }) async {
    final out = <Listing>[];
    for (final id in favoriteIds) {
      final live = store.where((l) => l.id == id).firstOrNull ?? knownListings[id];
      if (live != null) {
        out.add(live);
      } else {
        final m = cachedMeta[id] ?? const <String, dynamic>{};
        out.add(Listing(
          id: id,
          title: (m['listingTitle'] as String?) ?? 'Saved Listing',
          description: 'Removed by seller',
          category: (m['listingCategory'] as String?) ?? 'Other',
          condition: 'used',
          price: (m['listingPrice'] as num?)?.toInt() ?? 0,
          negotiable: false,
          imageUrl: '',
          sellerId: (m['sellerId'] as String?) ?? '',
          sellerName: 'Unknown user',
          status: 'deleted',
          reservedFor: '',
        ));
      }
    }
    return out;
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required Listing listing,
    required bool save,
  }) async {
    if (failNextSetFavorite) {
      failNextSetFavorite = false;
      throw Exception('Simulated Firestore write failure');
    }
    if (save) {
      favoriteIds.add(listing.id);
      favoriteMeta[listing.id] = {
        'listingTitle': listing.title,
        'listingPrice': listing.price,
        'listingCategory': listing.category,
        'sellerId': listing.sellerId,
      };
    } else {
      favoriteIds.remove(listing.id);
      favoriteMeta.remove(listing.id);
    }
    _favController.add(Set<String>.from(favoriteIds));
  }

  @override
  Future<Listing?> fetchListingById(String listingId) async =>
      store.where((l) => l.id == listingId).firstOrNull;

  @override
  Stream<List<ListingComment>> watchComments(String listingId) =>
      const Stream.empty();

  @override
  Future<void> addComment({
    required Listing listing,
    required String authorId,
    required String fallbackAuthorName,
    required String text,
  }) async {}

  @override
  Future<void> deleteComment(String listingId, String commentId) async {}

  @override
  Stream<List<Listing>> watchSellerListings(String sellerId) =>
      _sellerController.stream;

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
    if (failNextCreate) {
      failNextCreate = false;
      throw Exception('Create denied');
    }
    store.add(_makeListing(
      id: 'l_${store.length + 1}',
      title: title.trim(),
      description: description.trim(),
      category: category,
      condition: condition,
      location: location,
      price: price,
      negotiable: negotiable,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      images: List<String>.from(imageUrls),
      sellerId: sellerId,
      sellerName: fallbackSellerName,
      createdAt: DateTime.now(),
    ));
    emitSellerListings(sellerId);
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
    final idx = store.indexWhere((l) => l.id == listingId);
    if (idx == -1) throw Exception('Not found');
    final cur = store[idx];
    store[idx] = _makeListing(
      id: cur.id,
      title: title.trim(),
      description: description.trim(),
      category: category,
      condition: condition,
      location: location,
      price: price,
      negotiable: negotiable,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      images: List<String>.from(imageUrls),
      sellerId: cur.sellerId,
      sellerName: cur.sellerName,
      status: cur.status,
      reservedFor: cur.reservedFor,
    );
    emitSellerListings(cur.sellerId);
  }

  @override
  Future<void> updateListingStatus({
    required String listingId,
    required String status,
    String reservedFor = '',
  }) async {
    final idx = store.indexWhere((l) => l.id == listingId);
    if (idx == -1) throw Exception('Not found');
    final cur = store[idx];
    store[idx] = _makeListing(
      id: cur.id,
      title: cur.title,
      description: cur.description,
      category: cur.category,
      condition: cur.condition,
      location: cur.location,
      price: cur.price,
      negotiable: cur.negotiable,
      imageUrl: cur.imageUrl,
      sellerId: cur.sellerId,
      sellerName: cur.sellerName,
      status: status,
      reservedFor: status == 'available' ? '' : reservedFor,
    );
    emitInitialPage();
    emitSellerListings(cur.sellerId);
  }

  @override
  Future<void> deleteListing(String listingId) async {
    final cur = store.where((l) => l.id == listingId).firstOrNull;
    store.removeWhere((l) => l.id == listingId);
    emitInitialPage();
    if (cur != null) emitSellerListings(cur.sellerId);
  }

  Future<void> dispose() async {
    await _initialController.close();
    await _favController.close();
    await _sellerController.close();
  }
}

class _FakeOfferRepository implements OfferRepository {
  final _FakeListingRepository listingsRepo;
  final Map<String, MarketOffer> offers = {};
  final Map<String, String> handoverPins = {};
  final Set<String> readNotificationIds = {};
  int _pinSeq = 1000;

  _FakeOfferRepository(this.listingsRepo);

  @override
  Stream<List<MarketOffer>> watchMadeOffers(String uid) => Stream.value(
        offers.values.where((o) => o.buyerId == uid).toList(),
      );

  @override
  Stream<List<MarketOffer>> watchReceivedOffers(String uid) => Stream.value(
        offers.values.where((o) => o.sellerId == uid).toList(),
      );

  @override
  Stream<Set<String>> watchReadNotifications(String uid) =>
      Stream.value(Set<String>.from(readNotificationIds));

  @override
  Future<void> saveReadNotifications(String uid, Set<String> ids) async {
    readNotificationIds
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<String?> fetchBuyerHandoverPin(String offerId) async =>
      handoverPins[offerId];

  @override
  Future<String?> verifyOfferEligibility({
    required Listing listing,
    required String buyerUid,
  }) async {
    final live =
        listingsRepo.store.where((l) => l.id == listing.id).firstOrNull;
    if (live == null) return 'This listing no longer exists';
    if (live.sellerId == buyerUid) {
      return 'You cannot make an offer on your own listing';
    }
    if (live.isSold) return 'This listing has already been sold';
    if (!live.isAvailable) return 'This item is currently reserved';
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
    final live =
        listingsRepo.store.where((l) => l.id == listing.id).firstOrNull;
    if (live == null) {
      throw const OfferValidationException('Listing missing');
    }
    final id = '${listing.id}_$buyerUid';
    final existing = offers[id];
    final plan = MarketplaceLogic.validateOfferSubmission(
      buyerUid: buyerUid,
      listing: live,
      amount: amount,
      existingOffer: existing,
    );
    final now = Timestamp.now();
    offers[id] = MarketOffer(
      id: id,
      listingId: live.id,
      listingTitle: live.title,
      sellerId: live.sellerId,
      sellerName: live.sellerName,
      buyerId: buyerUid,
      buyerName: buyerFallbackName,
      amount: amount,
      lastUpdatedBy: buyerUid,
      message: message,
      status: 'pending',
      createdAt: plan.isReopening ? now : (existing?.createdAt ?? now),
      updatedAt: now,
    );
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
    final liveOffer = offers[offer.id];
    final liveListing =
        listingsRepo.store.where((l) => l.id == offer.listingId).firstOrNull;
    if (liveOffer == null || liveListing == null) {
      throw const OfferValidationException('Offer or listing missing');
    }

    final plan = MarketplaceLogic.validateTransition(
      offer: liveOffer,
      listing: liveListing,
      action: action,
      actorUid: actorUid,
      counterAmount: counterAmount,
      handoverPin: handoverPin ?? handoverPins[liveOffer.id],
    );

    final pin = plan.generatesHandoverPin ? '${++_pinSeq}' : liveOffer.handoverCode;
    if (plan.generatesHandoverPin) {
      handoverPins[liveOffer.id] = pin;
    }

    offers[liveOffer.id] = MarketOffer(
      id: liveOffer.id,
      listingId: liveOffer.listingId,
      listingTitle: liveOffer.listingTitle,
      sellerId: liveOffer.sellerId,
      sellerName: liveOffer.sellerName,
      buyerId: liveOffer.buyerId,
      buyerName: liveOffer.buyerName,
      amount: action == OfferAction.counter && counterAmount != null
          ? counterAmount
          : liveOffer.amount,
      lastUpdatedBy: plan.lastUpdatedBy,
      message: liveOffer.message,
      status: plan.nextOfferStatus,
      handoverCode: pin,
      isRated: liveOffer.isRated,
      createdAt: liveOffer.createdAt,
      updatedAt: Timestamp.now(),
    );

    if (plan.nextListingStatus != null) {
      await listingsRepo.updateListingStatus(
        listingId: liveListing.id,
        status: plan.nextListingStatus!,
        reservedFor: plan.nextReservedFor ?? liveListing.reservedFor,
      );
    }

    if (plan.declinesCompetingOffers) {
      final competing = offers.values
          .where((other) =>
              other.listingId == liveListing.id &&
              other.id != liveOffer.id &&
              (other.status == 'pending' || other.status == 'countered'))
          .toList();

      // Declines up to FirestoreOfferRepository.maxCompetingOffersInTransaction in-tx,
      // then handles overflow + late arrivals in bounded chunks.
      for (final other in competing
          .take(FirestoreOfferRepository.maxCompetingOffersInTransaction)) {
        _markCompetingDeclined(other);
      }

      if (beforeOverflowCleanup != null) {
        await beforeOverflowCleanup!();
      }

      var batches = 0;
      while (true) {
        final remaining = offers.values
            .where((other) =>
                other.listingId == liveListing.id &&
                other.id != liveOffer.id &&
                (other.status == 'pending' || other.status == 'countered'))
            .take(FirestoreOfferRepository.overflowCleanupBatchSize)
            .toList();
        if (remaining.isEmpty) break;
        batches++;
        if (batches > FirestoreOfferRepository.maxOverflowCleanupBatches) {
          throw const OfferValidationException(
            'Could not finish declining all competing offers; retry reservation release or refresh offers',
          );
        }
        for (final other in remaining) {
          _markCompetingDeclined(other);
        }
      }
    }
  }

  Future<void> Function()? beforeOverflowCleanup;

  void _markCompetingDeclined(MarketOffer other) {
    offers[other.id] = MarketOffer(
      id: other.id,
      listingId: other.listingId,
      listingTitle: other.listingTitle,
      sellerId: other.sellerId,
      sellerName: other.sellerName,
      buyerId: other.buyerId,
      buyerName: other.buyerName,
      amount: other.amount,
      lastUpdatedBy: other.lastUpdatedBy,
      message: other.message,
      status: 'declined',
      createdAt: other.createdAt,
      updatedAt: Timestamp.now(),
    );
  }

  @override
  Future<void> markExpiredIfDue(List<MarketOffer> items, String actorUid) async {
    for (final o in items) {
      final cur = offers[o.id];
      if (cur != null &&
          (cur.status == 'pending' || cur.status == 'countered') &&
          cur.isExpired) {
        offers[o.id] = MarketOffer(
          id: cur.id,
          listingId: cur.listingId,
          listingTitle: cur.listingTitle,
          sellerId: cur.sellerId,
          sellerName: cur.sellerName,
          buyerId: cur.buyerId,
          buyerName: cur.buyerName,
          amount: cur.amount,
          message: cur.message,
          status: 'expired',
          createdAt: cur.createdAt,
          updatedAt: Timestamp.now(),
        );
      }
    }
  }

  @override
  Future<void> releaseReservedListingWithOffers({
    required Listing listing,
    required String sellerUid,
  }) async {
    for (final o in offers.values.toList()) {
      if (o.listingId == listing.id &&
          o.sellerId == sellerUid &&
          o.status == 'accepted') {
        offers[o.id] = MarketOffer(
          id: o.id,
          listingId: o.listingId,
          listingTitle: o.listingTitle,
          sellerId: o.sellerId,
          sellerName: o.sellerName,
          buyerId: o.buyerId,
          buyerName: o.buyerName,
          amount: o.amount,
          message: o.message,
          status: 'declined',
          createdAt: o.createdAt,
          updatedAt: Timestamp.now(),
        );
      }
    }
    await listingsRepo.updateListingStatus(
      listingId: listing.id,
      status: 'available',
      reservedFor: '',
    );
  }

  @override
  Future<void> completeReservedListingBySeller({
    required Listing listing,
    required String sellerUid,
  }) async {
    for (final o in offers.values.toList()) {
      if (o.listingId == listing.id &&
          o.sellerId == sellerUid &&
          o.status == 'accepted') {
        offers[o.id] = MarketOffer(
          id: o.id,
          listingId: o.listingId,
          listingTitle: o.listingTitle,
          sellerId: o.sellerId,
          sellerName: o.sellerName,
          buyerId: o.buyerId,
          buyerName: o.buyerName,
          amount: o.amount,
          message: o.message,
          status: 'completed',
          createdAt: o.createdAt,
          updatedAt: Timestamp.now(),
        );
      }
    }
    await listingsRepo.updateListingStatus(
      listingId: listing.id,
      status: 'sold',
      reservedFor: listing.reservedFor,
    );
  }
}

class _FakeRatingRepository implements RatingRepository {
  final _FakeListingRepository listingsRepo;
  final _FakeOfferRepository offersRepo;
  final Map<String, SellerReview> ratings = {};
  int sellerRatingSum = 0;
  int sellerRatingCount = 0;

  _FakeRatingRepository(this.listingsRepo, this.offersRepo);

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
    if (ratings.containsKey(listingId)) {
      throw const OfferValidationException('This sale has already been rated');
    }
    final liveListing =
        listingsRepo.store.where((l) => l.id == listingId).firstOrNull;
    if (liveListing == null || !liveListing.isSold) {
      throw const OfferValidationException('Only completed sales can be rated');
    }
    final oid = offerId ?? '${listingId}_$buyerId';
    final offer = offersRepo.offers[oid];
    if (offer == null ||
        offer.buyerId != buyerId ||
        offer.sellerId != sellerId ||
        offer.status != 'completed') {
      throw const OfferValidationException(
        'Only the verified buyer of a completed trade can rate this seller',
      );
    }

    ratings[listingId] = SellerReview(
      id: listingId,
      sellerId: sellerId,
      buyerId: buyerId,
      buyerName: buyerFallbackName,
      stars: stars,
      comment: comment,
      createdAt: DateTime.now(),
    );
    sellerRatingSum += stars;
    sellerRatingCount += 1;
    offersRepo.offers[oid] = MarketOffer(
      id: offer.id,
      listingId: offer.listingId,
      listingTitle: offer.listingTitle,
      sellerId: offer.sellerId,
      sellerName: offer.sellerName,
      buyerId: offer.buyerId,
      buyerName: offer.buyerName,
      amount: offer.amount,
      message: offer.message,
      status: offer.status,
      isRated: true,
      createdAt: offer.createdAt,
      updatedAt: offer.updatedAt,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchSellerPublicData(String sellerId) async => {
        'profile': {'ratingSum': sellerRatingSum, 'ratingCount': sellerRatingCount},
        'reviews': ratings.values.where((r) => r.sellerId == sellerId).toList(),
        'listings': listingsRepo.store
            .where((l) => l.sellerId == sellerId && l.isAvailable)
            .toList(),
      };
}

void main() {
  group('ListingProvider Pagination, Search, Filtering & Favourites', () {
    late _FakeListingRepository fakeRepo;
    late ListingProvider provider;

    setUp(() {
      fakeRepo = _FakeListingRepository();
      for (int i = 1; i <= 35; i++) {
        fakeRepo.store.add(_makeListing(
          id: 'item_$i',
          title: i == 34
              ? 'Rare Discrete Mathematics Workbook'
              : 'Campus Item $i',
          category: i.isEven ? 'Books' : 'Electronics',
          condition: i % 3 == 0 ? 'like-new' : 'used',
          price: i * 100,
          negotiable: i.isEven,
          createdAt: DateTime(2026, 11, 1).add(Duration(minutes: i)),
        ));
      }
      provider = ListingProvider(
        repository: fakeRepo,
        currentUidProvider: () => 'buyer_1',
      );
      fakeRepo.emitInitialPage();
    });

    tearDown(() async {
      provider.dispose();
      await fakeRepo.dispose();
    });

    test('paginates with limit 30 and startAfter without duplicates', () async {
      await Future<void>.delayed(Duration.zero);
      expect(provider.listings.length, 30);
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.listings.length, 35);
      expect(provider.listings.map((l) => l.id).toSet().length, 35);
      expect(provider.hasMore, isFalse);

      // Extra loadMore call on last page is safely ignored
      await provider.loadMore();
      expect(provider.listings.length, 35);
    });

    test('server keyword search finds items beyond initial page and surfaces errors cleanly', () async {
      await Future<void>.delayed(Duration.zero);
      // Item 34 is at index 33 (not yet loaded in initial 30)
      await provider.searchRemote('discrete');
      expect(provider.searchError, isNull);
      provider.query = 'discrete';
      expect(provider.filtered.any((l) => l.id == 'item_34'), isTrue);

      fakeRepo.failNextSearch = true;
      await provider.searchRemote('electronics');
      expect(provider.searchError, isNotNull);
    });

    test('filtering, sorting, and active filter count behave consistently', () async {
      await Future<void>.delayed(Duration.zero);
      provider.setCategory('Books');
      provider.setAdvancedFilters(
        condition: 'like-new',
        location: 'All Locations',
        minPrice: 400,
        maxPrice: 2000,
        onlyNegotiable: true,
      );
      provider.setSort('Price high');

      final res = provider.filtered;
      expect(res, isNotEmpty);
      expect(res.every((l) => l.category == 'Books'), isTrue);
      expect(res.every((l) => l.condition == 'like-new'), isTrue);
      expect(res.every((l) => l.price >= 400 && l.price <= 2000), isTrue);
      expect(res.every((l) => l.negotiable), isTrue);
      for (int i = 1; i < res.length; i++) {
        expect(res[i].price <= res[i - 1].price, isTrue);
      }
      expect(provider.activeFilterCount, greaterThanOrEqualTo(3));

      provider.resetAllFilters();
      expect(provider.activeFilterCount, 0);
    });

    test('optimistic favourite toggle persists sold/deleted items and rolls back on failure', () async {
      await Future<void>.delayed(Duration.zero);
      final target = fakeRepo.store.first;
      expect(await provider.toggleFavorite(target), isTrue);
      expect(provider.favoriteIds.contains(target.id), isTrue);

      // Mark item sold & remove from Discover store -> still preserved in favoriteListings
      await fakeRepo.updateListingStatus(
        listingId: target.id,
        status: 'sold',
        reservedFor: 'buyer_1',
      );
      await fakeRepo.deleteListing(target.id);
      await provider.refreshFavorites();
      expect(provider.favoriteListings.any((l) => l.id == target.id), isTrue);
      expect(
        provider.favoriteListings.firstWhere((l) => l.id == target.id).isDeleted,
        isTrue,
      );

      // Rollback on Firestore failure
      fakeRepo.failNextSetFavorite = true;
      expect(await provider.toggleFavorite(fakeRepo.store.first), isFalse);
      expect(provider.error, isNotNull);
      expect(provider.favoriteIds.contains(fakeRepo.store.first.id), isFalse);
    });
  });

  group('SellProvider Validation, Lifecycle & Logout Reset', () {
    late _FakeListingRepository fakeListingRepo;
    late _FakeOfferRepository fakeOfferRepo;
    String? currentUid = 'seller_1';
    late SellProvider sellProvider;

    setUp(() {
      fakeListingRepo = _FakeListingRepository();
      fakeOfferRepo = _FakeOfferRepository(fakeListingRepo);
      sellProvider = SellProvider(
        listingRepository: fakeListingRepo,
        offerRepository: fakeOfferRepo,
        currentUidProvider: () => currentUid,
        currentNameProvider: () => 'Alice',
      );
      fakeListingRepo.emitSellerListings('seller_1');
    });

    tearDown(() async {
      sellProvider.dispose();
      await fakeListingRepo.dispose();
    });

    test('rejects invalid price/title and non-HTTPS image links', () async {
      expect(
        await sellProvider.createListing(
          title: 'Ab',
          description: 'Valid description',
          category: 'Books',
          condition: 'used',
          price: 100,
          negotiable: true,
        ),
        isFalse,
      );
      expect(sellProvider.error, isNotNull);

      expect(
        await sellProvider.createListing(
          title: 'Valid Book Title',
          description: 'Valid book description',
          category: 'Books',
          condition: 'used',
          price: 300,
          negotiable: true,
          images: const ['http://insecure.example.com/a.jpg'],
        ),
        isFalse,
      );
      expect(sellProvider.error, contains('https://'));

      expect(
        await sellProvider.createListing(
          title: 'Valid Book Title',
          description: 'Valid book description',
          category: 'Books',
          condition: 'used',
          price: 300,
          negotiable: true,
        ),
        isTrue,
      );
      expect(sellProvider.myListings.length, 1);
      expect(sellProvider.myListings.first.imageUrl, isEmpty);

      // Mixed device-uploaded Data URI + external https:// URL are accepted
      const sampleDeviceUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      expect(
        await sellProvider.createListing(
          title: 'Mixed Gallery Camera',
          description: 'Clean mirrorless camera body with kit lens',
          category: 'Electronics',
          condition: 'like-new',
          price: 25000,
          negotiable: true,
          images: const [sampleDeviceUri, 'https://cdn.example.com/cam.jpg'],
        ),
        isTrue,
      );
      expect(sellProvider.myListings.last.galleryImages.length, 2);
      expect(sellProvider.myListings.last.imageUrl, sampleDeviceUri);

      // Oversized device URI exceeding Firestore safety cap is rejected
      final hugeUri = 'data:image/jpeg;base64,${'A' * 265000}';
      expect(
        await sellProvider.createListing(
          title: 'Oversized Photo Test',
          description: 'Testing document budget enforcement',
          category: 'Other',
          condition: 'used',
          price: 500,
          negotiable: false,
          images: [hugeUri],
        ),
        isFalse,
      );
      expect(sellProvider.error, isNotNull);
    });

    test('sets loading to false safely when signed out', () {
      currentUid = null;
      final loggedOut = SellProvider(
        listingRepository: fakeListingRepo,
        offerRepository: fakeOfferRepo,
        currentUidProvider: () => currentUid,
      );
      expect(loggedOut.loading, isFalse);
      expect(loggedOut.myListings, isEmpty);
      loggedOut.dispose();
    });
  });

  group('Offer State Machine, Concurrency, Expiry & Ratings', () {
    late _FakeListingRepository listingRepo;
    late _FakeOfferRepository offerRepo;
    late _FakeRatingRepository ratingRepo;
    late Listing listing;

    setUp(() {
      listingRepo = _FakeListingRepository();
      listing = _makeListing(
        id: 'list_1',
        title: 'Casio Scientific Calculator',
        price: 1000,
        sellerId: 'seller_1',
        sellerName: 'Alice',
      );
      listingRepo.store.add(listing);
      offerRepo = _FakeOfferRepository(listingRepo);
      ratingRepo = _FakeRatingRepository(listingRepo, offerRepo);
    });

    tearDown(() async {
      await listingRepo.dispose();
    });

    test('atomic offer acceptance declines competing offers and blocks concurrent accept', () async {
      final sellerOfferProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'seller_1',
        currentNameProvider: () => 'Alice',
      );

      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'buyer_1',
        buyerFallbackName: 'Bob',
        amount: 850,
        message: 'Cash today',
      );
      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'buyer_2',
        buyerFallbackName: 'Cara',
        amount: 900,
        message: 'Meet at gate',
      );

      final offer1 = offerRepo.offers['list_1_buyer_1']!;
      final offer2 = offerRepo.offers['list_1_buyer_2']!;

      expect(await sellerOfferProv.transition(offer1, 'accept'), isTrue);
      expect(offerRepo.offers['list_1_buyer_1']!.status, 'accepted');
      expect(offerRepo.offers['list_1_buyer_1']!.handoverCode, isNotEmpty);
      expect(offerRepo.offers['list_1_buyer_2']!.status, 'declined');
      expect(listingRepo.store.first.status, 'reserved');
      expect(listingRepo.store.first.reservedFor, 'buyer_1');

      // Concurrent attempt to accept declined offer2 fails cleanly
      expect(await sellerOfferProv.transition(offer2, 'accept'), isFalse);
      expect(sellerOfferProv.error, isNotNull);
      sellerOfferProv.dispose();
    });

    test('counter offer supports buyer acceptCounter or declineCounter only', () async {
      final sellerProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'seller_1',
        currentNameProvider: () => 'Alice',
      );
      final buyerProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'buyer_1',
        currentNameProvider: () => 'Bob',
      );

      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'buyer_1',
        buyerFallbackName: 'Bob',
        amount: 800,
        message: 'Hello',
      );

      // Seller counters to 920
      expect(
        await sellerProv.counterOffer(offerRepo.offers['list_1_buyer_1']!, 920),
        isTrue,
      );
      final countered = offerRepo.offers['list_1_buyer_1']!;
      expect(countered.status, 'countered');
      expect(countered.amount, 920);

      // Seller CANNOT counter their own previous counter-offer (alternating turn invariant)
      expect(await sellerProv.counterOffer(countered, 930), isFalse);
      expect(sellerProv.error, contains('Waiting for the buyer'));

      // Buyer CANNOT reset a countered offer back to pending via validateOfferSubmission
      expect(
        () => MarketplaceLogic.validateOfferSubmission(
          buyerUid: 'buyer_1',
          listing: listing,
          amount: 850,
          existingOffer: countered,
        ),
        throwsA(isA<OfferValidationException>()),
      );

      // Buyer cannot counter back; seller cannot acceptCounter
      expect(await buyerProv.counterOffer(countered, 910), isFalse);
      expect(await sellerProv.transition(countered, 'acceptCounter'), isFalse);

      // Buyer declines counter cleanly -> listing stays available
      expect(await buyerProv.transition(countered, 'declineCounter'), isTrue);
      expect(offerRepo.offers['list_1_buyer_1']!.status, 'declined');
      expect(listingRepo.store.first.status, 'available');

      sellerProv.dispose();
      buyerProv.dispose();
    });

    test('expired offers (>48h) block accept, counter, decline, withdraw, and reopening', () async {
      final expiredCreatedAt = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 49)),
      );
      final expiredOffer = MarketOffer(
        id: 'list_1_buyer_1',
        listingId: 'list_1',
        listingTitle: listing.title,
        sellerId: 'seller_1',
        sellerName: 'Alice',
        buyerId: 'buyer_1',
        buyerName: 'Bob',
        amount: 800,
        lastUpdatedBy: 'buyer_1',
        message: 'Still available?',
        status: 'pending',
        createdAt: expiredCreatedAt,
      );
      offerRepo.offers[expiredOffer.id] = expiredOffer;

      final sellerProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'seller_1',
      );
      final buyerProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'buyer_1',
      );

      expect(await sellerProv.transition(expiredOffer, 'accept'), isFalse);
      expect(sellerProv.error, contains('expired'));
      expect(await sellerProv.transition(expiredOffer, 'decline'), isFalse);
      expect(await buyerProv.transition(expiredOffer, 'withdraw'), isFalse);

      await offerRepo.markExpiredIfDue([expiredOffer], 'seller_1');
      final terminal = offerRepo.offers[expiredOffer.id]!;
      expect(terminal.status, 'expired');

      expect(
        () => MarketplaceLogic.validateOfferSubmission(
          buyerUid: 'buyer_1',
          listing: listing,
          amount: 850,
          existingOffer: terminal,
        ),
        throwsA(isA<OfferValidationException>()),
      );
      sellerProv.dispose();
      buyerProv.dispose();
    });

    test('handover completion unlocks single verified rating and rejects duplicates', () async {
      final sellerProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'seller_1',
      );
      final ratingProv = RatingProvider(
        repository: ratingRepo,
        currentUidProvider: () => 'buyer_1',
        currentNameProvider: () => 'Bob',
      );

      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'buyer_1',
        buyerFallbackName: 'Bob',
        amount: 1000,
        message: 'Asking price',
      );
      final accepted = offerRepo.offers['list_1_buyer_1']!;
      expect(await sellerProv.transition(accepted, 'accept'), isTrue);
      final pin = offerRepo.offers['list_1_buyer_1']!.handoverCode;

      // Wrong PIN rejected
      expect(
        await sellerProv.transition(
          offerRepo.offers['list_1_buyer_1']!,
          'complete',
          handoverPin: '0000',
        ),
        isFalse,
      );

      // Premature rating before completion rejected
      expect(
        await ratingProv.rateSale(
          listingId: listing.id,
          sellerId: 'seller_1',
          stars: 5,
        ),
        isFalse,
      );

      // Correct PIN completes trade and marks listing sold
      expect(
        await sellerProv.transition(
          offerRepo.offers['list_1_buyer_1']!,
          'complete',
          handoverPin: pin,
        ),
        isTrue,
      );
      expect(listingRepo.store.first.isSold, isTrue);

      // Valid rating succeeds once, duplicate fails
      expect(
        await ratingProv.rateSale(
          listingId: listing.id,
          sellerId: 'seller_1',
          stars: 5,
          comment: 'Great seller!',
        ),
        isTrue,
      );
      expect(ratingRepo.sellerRatingCount, 1);
      expect(ratingRepo.sellerRatingSum, 5);

      expect(
        await ratingProv.rateSale(
          listingId: listing.id,
          sellerId: 'seller_1',
          stars: 4,
        ),
        isFalse,
      );
      expect(ratingProv.error, contains('already been rated'));

      sellerProv.dispose();
      ratingProv.dispose();
    });

    test('releasing a reserved listing declines its accepted offer and restores availability', () async {
      final sellProv = SellProvider(
        listingRepository: listingRepo,
        offerRepository: offerRepo,
        currentUidProvider: () => 'seller_1',
      );
      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'buyer_1',
        buyerFallbackName: 'Bob',
        amount: 950,
        message: 'Ready',
      );
      await offerRepo.transitionOffer(
        offer: offerRepo.offers['list_1_buyer_1']!,
        action: OfferAction.accept,
        actorUid: 'seller_1',
      );
      expect(listingRepo.store.first.isReserved, isTrue);

      expect(
        await sellProv.releaseReservedListing(listingRepo.store.first),
        isTrue,
      );
      expect(listingRepo.store.first.isAvailable, isTrue);
      expect(offerRepo.offers['list_1_buyer_1']!.status, 'declined');
      sellProv.dispose();
    });

    test('buyer withdrawing an accepted reservation declines own offer and frees listing', () async {
      final sellerOfferProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'seller_1',
      );
      final buyerOfferProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'buyer_1',
      );

      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'buyer_1',
        buyerFallbackName: 'Bob',
        amount: 950,
        message: 'Ready',
      );
      expect(
        await sellerOfferProv.transition(
          offerRepo.offers['list_1_buyer_1']!,
          'accept',
        ),
        isTrue,
      );
      expect(listingRepo.store.first.isReserved, isTrue);

      expect(
        await buyerOfferProv.transition(
          offerRepo.offers['list_1_buyer_1']!,
          'withdraw',
        ),
        isTrue,
      );
      expect(offerRepo.offers['list_1_buyer_1']!.status, 'withdrawn');
      expect(listingRepo.store.first.isAvailable, isTrue);
      expect(listingRepo.store.first.reservedFor, '');

      sellerOfferProv.dispose();
      buyerOfferProv.dispose();
    });

    test('bounded cleanup declines >450 competing offers and late-arriving concurrent offers', () async {
      final sellerOfferProv = OfferProvider(
        repository: offerRepo,
        currentUidProvider: () => 'seller_1',
      );

      await offerRepo.submitOffer(
        listing: listing,
        buyerUid: 'winner',
        buyerFallbackName: 'Winner',
        amount: 1000,
        message: 'Asking price',
      );
      const totalCompeting = 460;
      for (int i = 0; i < totalCompeting; i++) {
        await offerRepo.submitOffer(
          listing: listing,
          buyerUid: 'comp_$i',
          buyerFallbackName: 'Buyer $i',
          amount: 800,
          message: 'Offer $i',
        );
      }

      // Inject a late-arriving offer after in-tx snapshot capture
      offerRepo.beforeOverflowCleanup = () async {
        offerRepo.offers['list_1_late_buyer'] = MarketOffer(
          id: 'list_1_late_buyer',
          listingId: listing.id,
          listingTitle: listing.title,
          sellerId: listing.sellerId,
          sellerName: listing.sellerName,
          buyerId: 'late_buyer',
          buyerName: 'Late Buyer',
          amount: 910,
          lastUpdatedBy: 'late_buyer',
          message: 'Concurrent late bid',
          status: 'pending',
          createdAt: Timestamp.now(),
        );
      };

      expect(
        await sellerOfferProv.transition(
          offerRepo.offers['list_1_winner']!,
          'accept',
        ),
        isTrue,
      );
      expect(offerRepo.offers['list_1_winner']!.status, 'accepted');
      expect(listingRepo.store.first.reservedFor, 'winner');
      for (int i = 0; i < totalCompeting; i++) {
        expect(offerRepo.offers['list_1_comp_$i']!.status, 'declined');
      }
      expect(offerRepo.offers['list_1_late_buyer']!.status, 'declined');
      sellerOfferProv.dispose();
    });
  });

  group('ChatProvider Unread Badge State Tests', () {
    test('unreadThreadsCount clears immediately when markThreadRead is called and excludes read threads', () async {
      final chat = ChatProvider(
        currentUidProvider: () => 'buyer_1',
        autoStart: false,
      );
      chat.threads = [
        ChatThread(
          id: 'l1_buyer_1',
          listingId: 'l1',
          listingTitle: 'Graphing Calculator',
          listingPrice: 2500,
          buyerId: 'buyer_1',
          buyerName: 'Bob',
          sellerId: 'seller_1',
          sellerName: 'Alice',
          lastMessage: 'Yes, still available!',
          lastMessageSenderId: 'seller_1',
          updatedAt: DateTime.now(),
        ),
        ChatThread(
          id: 'l2_buyer_1',
          listingId: 'l2',
          listingTitle: 'Physics Book',
          listingPrice: 400,
          buyerId: 'buyer_1',
          buyerName: 'Bob',
          sellerId: 'seller_2',
          sellerName: 'Cara',
          lastMessage: 'Already read',
          lastMessageSenderId: 'seller_2',
          lastReadAtBy: {'buyer_1': DateTime.now().add(const Duration(seconds: 5))},
          updatedAt: DateTime.now(),
        ),
      ];

      expect(chat.unreadThreadsCount, 1);
      await chat.markThreadRead('l1_buyer_1');
      expect(chat.unreadThreadsCount, 0);
      chat.dispose();
    });
  });
}
