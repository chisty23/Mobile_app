import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

/// Supported lifecycle actions on an offer.
enum OfferAction {
  counter,
  accept,
  acceptCounter,
  decline,
  declineCounter,
  withdraw,
  complete,
  expire,
}

class OfferValidationException implements Exception {
  final String message;
  const OfferValidationException(this.message);

  @override
  String toString() => message;
}

/// Validated offer creation/update decision before writing to Firestore.
class OfferSubmissionPlan {
  final bool isReopening;
  final bool alreadyPaidActive;
  final String? warningMessage;

  const OfferSubmissionPlan({
    required this.isReopening,
    required this.alreadyPaidActive,
    this.warningMessage,
  });
}

/// Validated offer transition result describing both offer and listing updates.
class OfferTransitionPlan {
  final String nextOfferStatus;
  final String? nextListingStatus;
  final String? nextReservedFor;
  final bool markStatsCounted;
  final bool declinesCompetingOffers;
  final bool generatesHandoverPin;
  final String lastUpdatedBy;

  const OfferTransitionPlan({
    required this.nextOfferStatus,
    this.nextListingStatus,
    this.nextReservedFor,
    this.markStatsCounted = false,
    this.declinesCompetingOffers = false,
    this.generatesHandoverPin = false,
    required this.lastUpdatedBy,
  });
}

/// Pure, Firebase-free domain logic for keyword search, filtering, sorting,
/// error mapping, and Offer State Machine validation.
class MarketplaceLogic {
  MarketplaceLogic._();

  static const Duration offerExpiryWindow = Duration(hours: 48);

  /// Extracts unique lowercase search tokens from a listing [title] for
  /// Firestore `array-contains` searches.
  static List<String> buildTitleKeywords(String title) {
    final lower = title.trim().toLowerCase();
    if (lower.isEmpty) return const [];

    final normalized = lower.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    final tokens = <String>{};
    for (final raw in normalized.split(RegExp(r'\s+'))) {
      final word = raw.trim();
      if (word.isEmpty) continue;
      final collapsed = word.replaceAll('-', '');
      if (collapsed.isNotEmpty) tokens.add(collapsed);
      for (final sub in word.split('-')) {
        final clean = sub.trim();
        if (clean.isNotEmpty) tokens.add(clean);
      }
    }
    return tokens.toList(growable: false);
  }

  /// Extracts search tokens from user query text.
  static List<String> tokenizeQuery(String query) {
    return buildTitleKeywords(query);
  }

  /// Filters and sorts a pool of listings cleanly without touching Firebase.
  static List<Listing> filterAndSortListings({
    required Iterable<Listing> listings,
    String query = '',
    String category = 'All',
    String condition = 'All',
    String locationFilter = 'All Locations',
    String sort = 'Newest',
    bool onlyAvailable = false,
    bool onlyFavorites = false,
    bool onlyNegotiable = false,
    int minPrice = 0,
    int maxPrice = 100000000,
    Set<String> favoriteIds = const {},
  }) {
    final q = query.trim().toLowerCase();
    final qTokens = tokenizeQuery(q);

    final result = listings.where((listing) {
      if (listing.isDeleted || listing.status == 'suspended') return false;
      final matchesQuery = q.isEmpty ||
          listing.title.toLowerCase().contains(q) ||
          listing.description.toLowerCase().contains(q) ||
          listing.location.toLowerCase().contains(q) ||
          listing.category.toLowerCase().contains(q) ||
          (qTokens.isNotEmpty &&
              qTokens.every(
                (t) =>
                    listing.keywords.contains(t) ||
                    listing.title.toLowerCase().contains(t),
              ));

      final matchesCategory = category == 'All' || listing.category == category;
      final matchesCondition =
          condition == 'All' || listing.condition == condition;
      final matchesLocation =
          locationFilter == 'All Locations' || listing.location == locationFilter;
      final matchesPrice =
          listing.price >= minPrice && listing.price <= maxPrice;
      final matchesAvailable = !onlyAvailable || listing.isAvailable;
      final matchesFavorites =
          !onlyFavorites || favoriteIds.contains(listing.id);
      final matchesNegotiable = !onlyNegotiable || listing.negotiable;

      return matchesQuery &&
          matchesCategory &&
          matchesCondition &&
          matchesLocation &&
          matchesPrice &&
          matchesAvailable &&
          matchesFavorites &&
          matchesNegotiable;
    }).toList();

    if (sort == 'Price low') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'Price high') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else {
      result.sort((a, b) {
        final ac = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bc = b.createdAt?.millisecondsSinceEpoch ?? 0;
        final cmp = bc.compareTo(ac);
        return cmp != 0 ? cmp : b.id.compareTo(a.id);
      });
    }
    return result;
  }

  /// Checks whether [createdAt] has exceeded the 48-hour expiry window relative
  /// to [referenceNow].
  static bool isOfferTimestampExpired(
    DateTime? createdAt, {
    DateTime? referenceNow,
  }) {
    if (createdAt == null) return false;
    final now = referenceNow ?? DateTime.now();
    return now.difference(createdAt) >= offerExpiryWindow;
  }

  /// Validates buyer offer submission or active-offer update before committing.
  static OfferSubmissionPlan validateOfferSubmission({
    required String buyerUid,
    required Listing listing,
    required int amount,
    MarketOffer? existingOffer,
  }) {
    if (buyerUid.trim().isEmpty) {
      throw const OfferValidationException('You must be signed in to make an offer');
    }
    if (listing.isDeleted) {
      throw const OfferValidationException('This listing no longer exists');
    }
    if (listing.sellerId == buyerUid) {
      throw const OfferValidationException(
        'You cannot make an offer on your own listing',
      );
    }
    if (listing.isSold) {
      throw const OfferValidationException('This listing has already been sold');
    }
    if (!listing.isAvailable) {
      throw const OfferValidationException(
        'This listing is currently reserved by another buyer',
      );
    }
    if (amount <= 0) {
      throw const OfferValidationException(
        'Offer amount must be greater than zero',
      );
    }

    if (existingOffer != null) {
      if (existingOffer.status == 'accepted' ||
          existingOffer.status == 'completed') {
        throw const OfferValidationException(
          'You already have an active accepted deal on this listing',
        );
      }
      if (existingOffer.status == 'expired' || existingOffer.isExpired) {
        throw const OfferValidationException(
          'This offer expired after 48 hours and cannot be reactivated',
        );
      }
    }

    final isReopening = existingOffer == null ||
        existingOffer.status == 'declined' ||
        existingOffer.status == 'withdrawn';

    final alreadyPaidActive = existingOffer != null &&
        existingOffer.feePaid &&
        (existingOffer.status == 'pending' ||
            existingOffer.status == 'countered') &&
        !existingOffer.isExpired;

    final exceedsAsk = amount > listing.price;
    return OfferSubmissionPlan(
      isReopening: isReopening,
      alreadyPaidActive: alreadyPaidActive,
      warningMessage: exceedsAsk
          ? 'Your offer ($amount ৳) exceeds the asking price (${listing.price} ৳).'
          : null,
    );
  }

  /// Validates every offer state transition, actor identity, ownership,
  /// expiry window, and listing state atomically.
  static OfferTransitionPlan validateTransition({
    required MarketOffer offer,
    required Listing listing,
    required OfferAction action,
    required String actorUid,
    int? counterAmount,
    String? handoverPin,
    DateTime? referenceNow,
  }) {
    if (actorUid.trim().isEmpty) {
      throw const OfferValidationException('Please sign in first');
    }
    final isSeller = offer.sellerId == actorUid;
    final isBuyer = offer.buyerId == actorUid;
    if (!isSeller && !isBuyer) {
      throw const OfferValidationException(
        'You are not authorized to act on this offer',
      );
    }
    if (listing.isDeleted) {
      throw const OfferValidationException('This listing no longer exists');
    }
    if (listing.sellerId != offer.sellerId) {
      throw const OfferValidationException(
        'Listing ownership verification failed',
      );
    }

    final expired = offer.isExpiredAt(referenceNow);

    switch (action) {
      case OfferAction.expire:
        if (offer.status != 'pending' && offer.status != 'countered') {
          throw const OfferValidationException(
            'Only pending or countered offers can expire',
          );
        }
        if (!expired) {
          throw const OfferValidationException(
            'Offer has not exceeded the 48-hour expiry window yet',
          );
        }
        return OfferTransitionPlan(
          nextOfferStatus: 'expired',
          lastUpdatedBy: actorUid,
        );

      case OfferAction.counter:
        if (!isSeller) {
          throw const OfferValidationException(
            'Only the seller can send a counter-offer',
          );
        }
        if (offer.status != 'pending' && offer.status != 'countered') {
          throw const OfferValidationException(
            'Only active pending or countered offers can be countered',
          );
        }
        if (expired) {
          throw const OfferValidationException(
            'This offer has expired after 48 hours',
          );
        }
        if (!listing.isAvailable) {
          throw const OfferValidationException(
            'This listing is no longer available for negotiation',
          );
        }
        if (counterAmount == null || counterAmount <= 0) {
          throw const OfferValidationException(
            'Counter amount must be greater than zero',
          );
        }
        return OfferTransitionPlan(
          nextOfferStatus: 'countered',
          lastUpdatedBy: actorUid,
        );

      case OfferAction.accept:
        if (!isSeller) {
          throw const OfferValidationException(
            'Only the seller can accept a buyer offer',
          );
        }
        if (offer.status == 'accepted') {
          throw const OfferValidationException(
            'Accepted offers cannot be accepted again',
          );
        }
        if (offer.status != 'pending') {
          throw const OfferValidationException(
            'Only pending buyer offers can be accepted by the seller',
          );
        }
        if (expired) {
          throw const OfferValidationException(
            'This offer has expired and cannot be accepted',
          );
        }
        if (!listing.isAvailable) {
          throw const OfferValidationException(
            'This listing has already been reserved or sold',
          );
        }
        return OfferTransitionPlan(
          nextOfferStatus: 'accepted',
          nextListingStatus: 'reserved',
          nextReservedFor: offer.buyerId,
          declinesCompetingOffers: true,
          generatesHandoverPin: true,
          lastUpdatedBy: actorUid,
        );

      case OfferAction.acceptCounter:
        if (!isBuyer) {
          throw const OfferValidationException(
            'Only the buyer can accept a counter-offer',
          );
        }
        if (offer.status == 'accepted') {
          throw const OfferValidationException(
            'Accepted offers cannot be accepted again',
          );
        }
        if (offer.status != 'countered' ||
            offer.lastUpdatedBy != offer.sellerId) {
          throw const OfferValidationException(
            'No pending seller counter-offer is available to accept',
          );
        }
        if (expired) {
          throw const OfferValidationException(
            'This counter-offer has expired and cannot be accepted',
          );
        }
        if (!listing.isAvailable) {
          throw const OfferValidationException(
            'This listing has already been reserved or sold',
          );
        }
        return OfferTransitionPlan(
          nextOfferStatus: 'accepted',
          nextListingStatus: 'reserved',
          nextReservedFor: offer.buyerId,
          declinesCompetingOffers: true,
          generatesHandoverPin: true,
          lastUpdatedBy: actorUid,
        );

      case OfferAction.decline:
        if (!isSeller) {
          throw const OfferValidationException(
            'Only the seller can decline a buyer offer',
          );
        }
        if (offer.status != 'pending' &&
            offer.status != 'countered' &&
            offer.status != 'accepted') {
          throw const OfferValidationException(
            'This offer is already closed',
          );
        }
        final releaseListing =
            offer.status == 'accepted' && listing.isReserved;
        return OfferTransitionPlan(
          nextOfferStatus: 'declined',
          nextListingStatus: releaseListing ? 'available' : null,
          nextReservedFor: releaseListing ? '' : null,
          lastUpdatedBy: actorUid,
        );

      case OfferAction.declineCounter:
        if (!isBuyer) {
          throw const OfferValidationException(
            'Only the buyer can decline a seller counter-offer',
          );
        }
        if (offer.status != 'countered') {
          throw const OfferValidationException(
            'Only a counter-offer can be declined by the buyer',
          );
        }
        return OfferTransitionPlan(
          nextOfferStatus: 'declined',
          lastUpdatedBy: actorUid,
        );

      case OfferAction.withdraw:
        if (!isBuyer) {
          throw const OfferValidationException(
            'Only the buyer can withdraw their offer',
          );
        }
        if (offer.status == 'pending' || offer.status == 'countered') {
          return OfferTransitionPlan(
            nextOfferStatus: 'withdrawn',
            lastUpdatedBy: actorUid,
          );
        }
        if (offer.status == 'accepted') {
          final releaseListing = listing.isReserved;
          return OfferTransitionPlan(
            nextOfferStatus: 'withdrawn',
            nextListingStatus: releaseListing ? 'available' : null,
            nextReservedFor: releaseListing ? '' : null,
            lastUpdatedBy: actorUid,
          );
        }
        throw const OfferValidationException(
          'This offer can no longer be withdrawn',
        );

      case OfferAction.complete:
        if (!isSeller) {
          throw const OfferValidationException(
            'Only the seller can finalize the handover',
          );
        }
        if (offer.status != 'accepted') {
          throw const OfferValidationException(
            'Only accepted deals can be finalized as sold',
          );
        }
        final expected = offer.handoverCode.trim();
        final provided = (handoverPin ?? '').trim();
        if (expected.isNotEmpty && provided != expected) {
          throw const OfferValidationException(
            'Invalid 4-digit handover PIN from buyer',
          );
        }
        return OfferTransitionPlan(
          nextOfferStatus: 'completed',
          nextListingStatus: 'sold',
          nextReservedFor: offer.buyerId,
          markStatsCounted: !listing.statsCounted,
          lastUpdatedBy: actorUid,
        );
    }
  }

  /// Parses an action string (legacy UI calls or typed triggers) to [OfferAction].
  static OfferAction parseAction(String action) {
    switch (action) {
      case 'counter':
        return OfferAction.counter;
      case 'accept':
        return OfferAction.accept;
      case 'acceptCounter':
        return OfferAction.acceptCounter;
      case 'decline':
        return OfferAction.decline;
      case 'declineCounter':
        return OfferAction.declineCounter;
      case 'withdraw':
        return OfferAction.withdraw;
      case 'complete':
        return OfferAction.complete;
      case 'expire':
        return OfferAction.expire;
      default:
        throw OfferValidationException('Unsupported offer action: $action');
    }
  }

  /// Maps Firebase / network exceptions into clear user-facing feedback.
  static String mapError(Object error, {String fallback = 'Operation failed'}) {
    if (error is OfferValidationException) return error.message;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Check account status or sign in again.';
        case 'unauthenticated':
          return 'Session expired. Please sign in again.';
        case 'unavailable':
        case 'network-request-failed':
        case 'deadline-exceeded':
          return 'Poor or offline internet connection. Changes will sync when back online or retry in a moment.';
        case 'aborted':
          return 'Another update completed just before yours. Please refresh and try again.';
        case 'not-found':
          return 'This record no longer exists.';
        default:
          return error.message ?? '$fallback (${error.code})';
      }
    }
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isNotEmpty ? text : fallback;
  }
}
