import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import '../repositories/listing_repository.dart';

class ListingProvider extends ChangeNotifier {
  final ListingRepository? _repo;
  final String? Function() _uidProvider;

  StreamSubscription<ListingPageResult>? _listingSub;
  StreamSubscription<Set<String>>? _favoriteSub;
  StreamSubscription<User?>? _authSub;
  Timer? _searchDebounce;

  List<Listing> _initialPageItems = [];
  final List<Listing> _paginatedTail = [];
  Object? _initialCursor;
  Object? _tailCursor;
  bool _hasMoreInitial = false;
  bool _hasMoreTail = false;

  List<Listing> _remoteMatches = [];
  Set<String> favoriteIds = {};
  Map<String, Map<String, dynamic>> _favoriteMeta = {};
  List<Listing> _resolvedFavorites = [];

  bool loading = true;
  bool isFetchingMore = false;
  bool searching = false;
  String? error;
  String? searchError;
  bool requiresAuthToBrowse = false;

  String query = '';
  String category = 'All';
  String condition = 'All';
  String locationFilter = 'All Locations';
  String sort = 'Newest';
  bool onlyAvailable = false;
  bool onlyFavorites = false;
  bool onlyNegotiable = false;
  int minPrice = 0;
  int maxPrice = 100000000;

  ListingProvider({
    ListingRepository? repository,
    String? Function()? currentUidProvider,
    bool autoStart = true,
  })  : _repo = repository ?? _safeRepo(),
        _uidProvider = currentUidProvider ?? _defaultUid {
    if (autoStart) {
      try {
        if (Firebase.apps.isNotEmpty) {
          _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
            resetSessionAndReload();
          });
        }
      } catch (_) {}
      _startStreams();
    } else {
      loading = false;
    }
  }

  static ListingRepository? _safeRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreListingRepository();
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

  bool get hasMore =>
      _paginatedTail.isEmpty ? _hasMoreInitial : _hasMoreTail;

  List<Listing> get listings {
    final seen = <String>{};
    final merged = <Listing>[];
    for (final item in _initialPageItems) {
      if (seen.add(item.id)) merged.add(item);
    }
    for (final item in _paginatedTail) {
      if (seen.add(item.id)) merged.add(item);
    }
    return merged;
  }

  int get activeFilterCount {
    int count = 0;
    if (condition != 'All') count++;
    if (locationFilter != 'All Locations') count++;
    if (onlyNegotiable) count++;
    if (minPrice > 0) count++;
    if (maxPrice < 100000000) count++;
    return count;
  }

  void resetSessionAndReload() {
    favoriteIds = {};
    _favoriteMeta = {};
    _resolvedFavorites = [];
    _initialPageItems = [];
    _paginatedTail.clear();
    _initialCursor = null;
    _tailCursor = null;
    _hasMoreInitial = false;
    _hasMoreTail = false;
    _remoteMatches = [];
    loading = true;
    requiresAuthToBrowse = false;
    error = null;
    searchError = null;
    _startStreams();
  }

  void _startStreams() {
    final repo = _repo;
    if (repo == null) {
      loading = false;
      notifyListeners();
      return;
    }

    _listingSub?.cancel();
    _listingSub =
        repo.watchInitialPage(limit: ListingRepository.pageSize).listen(
      (page) {
        _initialPageItems = page.items;
        _initialCursor = page.lastCursor;
        _hasMoreInitial = page.hasMore;
        loading = false;
        isFetchingMore = false;
        requiresAuthToBrowse = false;
        error = null;
        notifyListeners();
        unawaited(_refreshResolvedFavorites());
      },
      onError: (e) {
        loading = false;
        isFetchingMore = false;
        if (e is FirebaseException && e.code == 'permission-denied') {
          requiresAuthToBrowse = true;
          error = 'Sign in to browse live campus listings';
        } else {
          error = MarketplaceLogic.mapError(
            e,
            fallback: 'Could not load listings',
          );
        }
        notifyListeners();
      },
    );

    final uid = _uidProvider();
    _favoriteSub?.cancel();
    if (uid != null && uid.isNotEmpty) {
      _favoriteSub = repo.watchFavoriteIds(uid).listen((ids) async {
        favoriteIds = ids;
        try {
          _favoriteMeta = await repo.fetchFavoriteMetadata(uid);
        } catch (_) {}
        await _refreshResolvedFavorites();
        notifyListeners();
      }, onError: (_) {});
    } else {
      favoriteIds = {};
      _favoriteMeta = {};
      _resolvedFavorites = [];
    }
  }

  Future<void> refreshFavorites() => _refreshResolvedFavorites();

  Future<void> _refreshResolvedFavorites() async {
    final repo = _repo;
    if (repo == null || favoriteIds.isEmpty) {
      _resolvedFavorites = [];
      return;
    }
    final knownById = <String, Listing>{
      for (final l in listings) l.id: l,
      for (final l in _remoteMatches) l.id: l,
    };
    try {
      _resolvedFavorites = await repo.resolveFavoriteListings(
        favoriteIds: favoriteIds,
        cachedMeta: _favoriteMeta,
        knownListings: knownById,
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Cursor-based pagination loading the next page of 30 items via `startAfterDocument()`.
  Future<void> loadMore() async {
    final repo = _repo;
    if (repo == null || isFetchingMore || !hasMore) return;
    final cursor = _tailCursor ?? _initialCursor;
    if (cursor == null) {
      _hasMoreInitial = false;
      _hasMoreTail = false;
      notifyListeners();
      return;
    }

    isFetchingMore = true;
    error = null;
    notifyListeners();
    try {
      final nextPage = await repo.fetchPage(
        limit: ListingRepository.pageSize,
        startAfter: cursor,
      );
      final existingIds = {
        for (final i in _initialPageItems) i.id,
        for (final i in _paginatedTail) i.id,
      };
      for (final item in nextPage.items) {
        if (existingIds.add(item.id)) {
          _paginatedTail.add(item);
        }
      }
      _tailCursor = nextPage.lastCursor ?? cursor;
      _hasMoreTail = nextPage.hasMore;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not load more items');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<Listing?> fetchListingById(String listingId) async {
    for (final l in listings) {
      if (l.id == listingId) return l;
    }
    try {
      return await _repo?.fetchListingById(listingId);
    } catch (_) {
      return null;
    }
  }

  Future<void> searchRemote(String term) async {
    final repo = _repo;
    final tokens = MarketplaceLogic.tokenizeQuery(term);
    if (tokens.isEmpty) {
      _remoteMatches = [];
      searchError = null;
      searching = false;
      notifyListeners();
      return;
    }
    if (repo == null) return;
    searching = true;
    searchError = null;
    notifyListeners();
    try {
      _remoteMatches = await repo.searchByKeywords(
        term,
        limit: ListingRepository.pageSize,
      );
    } catch (e) {
      searchError = MarketplaceLogic.mapError(
        e,
        fallback: 'Search temporarily limited to loaded items',
      );
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _paginatedTail.clear();
    _tailCursor = null;
    _hasMoreTail = false;
    _remoteMatches = [];
    loading = true;
    error = null;
    searchError = null;
    notifyListeners();
    _startStreams();
  }

  List<Listing> get filtered {
    final mergedById = <String, Listing>{
      for (final item in listings) item.id: item,
      for (final item in _remoteMatches) item.id: item,
    };
    return MarketplaceLogic.filterAndSortListings(
      listings: mergedById.values,
      query: query,
      category: category,
      condition: condition,
      locationFilter: locationFilter,
      sort: sort,
      onlyAvailable: onlyAvailable,
      onlyFavorites: onlyFavorites,
      onlyNegotiable: onlyNegotiable,
      minPrice: minPrice,
      maxPrice: maxPrice,
      favoriteIds: favoriteIds,
    );
  }

  /// Includes available, reserved, sold, and deleted saved items so saved
  /// references remain visible as "No longer available".
  List<Listing> get favoriteListings {
    if (_resolvedFavorites.isNotEmpty) return _resolvedFavorites;
    return listings.where((l) => favoriteIds.contains(l.id)).toList();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
    _searchDebounce?.cancel();
    if (value.trim().isNotEmpty) {
      _searchDebounce = Timer(
        const Duration(milliseconds: 280),
        () => searchRemote(value),
      );
    } else {
      _remoteMatches = [];
      searchError = null;
      notifyListeners();
    }
  }

  void setCategory(String value) {
    category = value;
    notifyListeners();
  }

  void setCondition(String value) {
    condition = value;
    notifyListeners();
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
  }

  void toggleOnlyAvailable() {
    onlyAvailable = !onlyAvailable;
    notifyListeners();
  }

  void toggleOnlyFavorites() {
    onlyFavorites = !onlyFavorites;
    notifyListeners();
  }

  void setAdvancedFilters({
    required String condition,
    required String location,
    required int minPrice,
    required int maxPrice,
    required bool onlyNegotiable,
  }) {
    this.condition = condition;
    locationFilter = location;
    this.minPrice = minPrice;
    this.maxPrice = maxPrice;
    this.onlyNegotiable = onlyNegotiable;
    notifyListeners();
  }

  void resetAllFilters() {
    query = '';
    _remoteMatches = [];
    searchError = null;
    category = 'All';
    condition = 'All';
    locationFilter = 'All Locations';
    minPrice = 0;
    maxPrice = 100000000;
    onlyAvailable = false;
    onlyFavorites = false;
    onlyNegotiable = false;
    notifyListeners();
  }

  /// Optimistically toggles a favourite and rolls back cleanly on Firestore failure.
  Future<bool> toggleFavorite(Listing listing) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) return false;

    final wasSaved = favoriteIds.contains(listing.id);
    final prevResolved = List<Listing>.from(_resolvedFavorites);
    error = null;

    if (wasSaved) {
      favoriteIds = {...favoriteIds}..remove(listing.id);
      _resolvedFavorites =
          _resolvedFavorites.where((l) => l.id != listing.id).toList();
    } else {
      favoriteIds = {...favoriteIds, listing.id};
      if (!_resolvedFavorites.any((l) => l.id == listing.id)) {
        _resolvedFavorites = [..._resolvedFavorites, listing];
      }
    }
    notifyListeners();

    try {
      await repo.setFavorite(uid: uid, listing: listing, save: !wasSaved);
      return true;
    } catch (e) {
      // Revert optimistic mutation to prevent inconsistent UI after DB failure.
      if (wasSaved) {
        favoriteIds = {...favoriteIds, listing.id};
      } else {
        favoriteIds = {...favoriteIds}..remove(listing.id);
      }
      _resolvedFavorites = prevResolved;
      error = MarketplaceLogic.mapError(
        e,
        fallback: 'Could not update saved favourite',
      );
      notifyListeners();
      return false;
    }
  }

  Stream<List<ListingComment>> commentsStream(String listingId) {
    final repo = _repo;
    if (repo == null) return const Stream.empty();
    return repo.watchComments(listingId);
  }

  Future<bool> addComment({
    required Listing listing,
    required String text,
    String fallbackAuthorName = '',
  }) async {
    final uid = _uidProvider();
    final repo = _repo;
    final clean = text.trim();
    if (uid == null || uid.isEmpty || clean.isEmpty || repo == null) {
      return false;
    }
    error = null;
    try {
      await repo.addComment(
        listing: listing,
        authorId: uid,
        fallbackAuthorName: fallbackAuthorName,
        text: clean,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not post comment');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment(String listingId, String commentId) async {
    final repo = _repo;
    if (repo == null) return false;
    try {
      await repo.deleteComment(listingId, commentId);
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not delete comment');
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _listingSub?.cancel();
    _favoriteSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
