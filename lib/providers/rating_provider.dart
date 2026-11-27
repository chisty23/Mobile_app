import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../domain/marketplace_logic.dart';
import '../repositories/rating_repository.dart';
import '../utils/formatters.dart';

class RatingProvider extends ChangeNotifier {
  final RatingRepository? _repo;
  final String? Function() _uidProvider;
  final String Function() _nameProvider;

  bool busy = false;
  String? error;

  RatingProvider({
    RatingRepository? repository,
    String? Function()? currentUidProvider,
    String Function()? currentNameProvider,
  })  : _repo = repository ?? _safeRepo(),
        _uidProvider = currentUidProvider ?? _defaultUid,
        _nameProvider = currentNameProvider ?? _defaultName;

  static RatingRepository? _safeRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreRatingRepository();
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

  Future<bool> rateSale({
    required String listingId,
    required String sellerId,
    required int stars,
    String comment = '',
    String? offerId,
  }) async {
    final repo = _repo;
    final buyerId = _uidProvider();
    if (buyerId == null || buyerId.isEmpty || repo == null) {
      error = 'Please sign in to submit a rating';
      notifyListeners();
      return false;
    }
    if (stars < 1 || stars > 5) {
      error = 'Rating must be between 1 and 5 stars';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      await repo.submitRating(
        listingId: listingId,
        sellerId: sellerId,
        buyerId: buyerId,
        buyerFallbackName: _nameProvider(),
        stars: stars,
        comment: comment,
        offerId: offerId,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not submit rating');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchSellerPublicData(String sellerId) {
    final repo = _repo;
    if (repo == null) {
      return Future.value({
        'profile': <String, dynamic>{},
        'reviews': const [],
        'listings': const [],
      });
    }
    return repo.fetchSellerPublicData(sellerId);
  }
}
