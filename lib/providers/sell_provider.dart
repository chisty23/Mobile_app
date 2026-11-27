import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import '../repositories/listing_repository.dart';
import '../repositories/offer_repository.dart';
import '../utils/formatters.dart';

class SellProvider extends ChangeNotifier {
  final ListingRepository? _listingRepo;
  final OfferRepository? _offerRepo;
  final String? Function() _uidProvider;
  final String Function() _nameProvider;

  StreamSubscription<List<Listing>>? _sub;
  StreamSubscription<List<MarketOffer>>? _offerSub;
  StreamSubscription<User?>? _authSub;

  List<Listing> myListings = [];
  Map<String, int> _pendingOfferCounts = {};
  bool loading = true;
  bool busy = false;
  String? error;

  SellProvider({
    ListingRepository? listingRepository,
    OfferRepository? offerRepository,
    String? Function()? currentUidProvider,
    String Function()? currentNameProvider,
    bool autoStart = true,
  })  : _listingRepo = listingRepository ?? _safeListingRepo(),
        _offerRepo = offerRepository ?? _safeOfferRepo(),
        _uidProvider = currentUidProvider ?? _defaultUid,
        _nameProvider = currentNameProvider ?? _defaultName {
    if (autoStart) {
      try {
        if (Firebase.apps.isNotEmpty) {
          _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
            _resetAndStart();
          });
        }
      } catch (_) {}
      _resetAndStart();
    } else {
      loading = false;
    }
  }

  static ListingRepository? _safeListingRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreListingRepository();
    } catch (_) {
      return null;
    }
  }

  static OfferRepository? _safeOfferRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreOfferRepository();
    } catch (_) {
      return null;
    }
  }

  static String? _defaultUid() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String _defaultName() {
    try {
      if (Firebase.apps.isEmpty) return AppFormatters.unknownUserName;
      return FirebaseAuth.instance.currentUser?.displayName ??
          AppFormatters.unknownUserName;
    } catch (_) {
      return AppFormatters.unknownUserName;
    }
  }

  void _resetAndStart() {
    myListings = [];
    _pendingOfferCounts = {};
    error = null;
    _sub?.cancel();
    _offerSub?.cancel();

    final uid = _uidProvider();
    final listingRepo = _listingRepo;
    if (uid == null || uid.isEmpty || listingRepo == null) {
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    _sub = listingRepo.watchSellerListings(uid).listen(
      (list) {
        myListings = list;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (e) {
        loading = false;
        error = MarketplaceLogic.mapError(
          e,
          fallback: 'Could not load your listings',
        );
        notifyListeners();
      },
    );

    final offerRepo = _offerRepo;
    if (offerRepo != null) {
      _offerSub = offerRepo.watchReceivedOffers(uid).listen((offers) {
        final counts = <String, int>{};
        for (final o in offers) {
          if (o.isActiveOffer) {
            counts[o.listingId] = (counts[o.listingId] ?? 0) + 1;
          }
        }
        _pendingOfferCounts = counts;
        notifyListeners();
      }, onError: (_) {});
    }
  }

  int pendingOfferCountFor(String listingId) =>
      _pendingOfferCounts[listingId] ?? 0;

  List<String> _validateHttpsImageList(List<String> images, String imageUrl) {
    final combined = <String>[
      for (final raw in images)
        if (raw.trim().isNotEmpty) raw.trim(),
    ];
    if (combined.isEmpty && imageUrl.trim().isNotEmpty) {
      combined.add(imageUrl.trim());
    }
    for (final url in combined) {
      if (!AppFormatters.isValidHttpsImageUrl(url)) {
        throw const OfferValidationException(
          'Only valid external https:// image URLs are allowed (or leave empty for category fallback).',
        );
      }
    }
    return combined.take(3).toList();
  }

  Future<bool> createListing({
    required String title,
    required String description,
    required String category,
    required String condition,
    String location = 'Campus Dorm / Hall',
    required int price,
    required bool negotiable,
    String imageUrl = '',
    List<String> images = const [],
    bool feePaid = false,
    String feeTransactionId = '',
  }) async {
    final repo = _listingRepo;
    final uid = _uidProvider();
    if (uid == null || uid.isEmpty || repo == null) {
      error = 'You must be signed in to publish a listing';
      notifyListeners();
      return false;
    }
    if (title.trim().length < 3 ||
        description.trim().length < 5 ||
        price <= 0) {
      error = 'Enter a valid title, description, and a positive price';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final validImages = _validateHttpsImageList(images, imageUrl);
      await repo.createListing(
        sellerId: uid,
        fallbackSellerName: _nameProvider(),
        title: title,
        description: description,
        category: category,
        condition: condition,
        location: location,
        price: price,
        negotiable: negotiable,
        imageUrls: validImages,
        feePaid: feePaid,
        feeTransactionId: feeTransactionId,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not create listing');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> updateListing({
    required String listingId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    List<String> images = const [],
    String imageUrl = '',
  }) async {
    final repo = _listingRepo;
    if (repo == null) return false;
    if (title.trim().length < 3 ||
        description.trim().length < 5 ||
        price <= 0) {
      error = 'Enter a valid title, description, and positive price';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final validImages = _validateHttpsImageList(images, imageUrl);
      await repo.updateListing(
        listingId: listingId,
        title: title,
        description: description,
        category: category,
        condition: condition,
        location: location,
        price: price,
        negotiable: negotiable,
        imageUrls: validImages,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not update listing');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> reserveListing(Listing listing) {
    return updateStatus(listing, 'reserved');
  }

  Future<bool> releaseReservedListing(Listing listing) async {
    final uid = _uidProvider();
    final offerRepo = _offerRepo;
    final listingRepo = _listingRepo;
    if (uid == null || uid.isEmpty || listingRepo == null) return false;

    busy = true;
    error = null;
    notifyListeners();
    try {
      if (offerRepo != null) {
        await offerRepo.releaseReservedListingWithOffers(
          listing: listing,
          sellerUid: uid,
        );
      } else {
        await listingRepo.updateListingStatus(
          listingId: listing.id,
          status: 'available',
          reservedFor: '',
        );
      }
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(
        e,
        fallback: 'Could not release reserved listing',
      );
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> markSold(Listing listing) async {
    final uid = _uidProvider();
    final offerRepo = _offerRepo;
    final listingRepo = _listingRepo;
    if (uid == null || uid.isEmpty || listingRepo == null) return false;

    busy = true;
    error = null;
    notifyListeners();
    try {
      if (offerRepo != null) {
        await offerRepo.completeReservedListingBySeller(
          listing: listing,
          sellerUid: uid,
        );
      } else {
        await listingRepo.updateListingStatus(
          listingId: listing.id,
          status: 'sold',
          reservedFor: listing.reservedFor,
        );
      }
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not mark sold');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(
    Listing listing,
    String status, {
    String reservedFor = '',
  }) async {
    if (status == 'available' && listing.isReserved) {
      return releaseReservedListing(listing);
    }
    if (status == 'sold') {
      return markSold(listing);
    }
    final repo = _listingRepo;
    if (repo == null) return false;

    busy = true;
    error = null;
    notifyListeners();
    try {
      final buyerId = reservedFor.isNotEmpty ? reservedFor : listing.reservedFor;
      await repo.updateListingStatus(
        listingId: listing.id,
        status: status,
        reservedFor: status == 'available' ? '' : buyerId,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not update listing');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteListing(Listing listing) async {
    final repo = _listingRepo;
    if (repo == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repo.deleteListing(listing.id);
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not delete listing');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _offerSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
