import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import '../repositories/offer_repository.dart';
import '../utils/formatters.dart';

class OfferProvider extends ChangeNotifier {
  final OfferRepository? _repo;
  final String? Function() _uidProvider;
  final String Function() _nameProvider;

  StreamSubscription<List<MarketOffer>>? _madeSub;
  StreamSubscription<List<MarketOffer>>? _receivedSub;
  StreamSubscription<Set<String>>? _prefSub;
  StreamSubscription<User?>? _authSub;

  List<MarketOffer> made = [];
  List<MarketOffer> received = [];
  final Set<String> _readNotificationIds = {};
  final Map<String, String> _buyerPinCache = {};
  final Set<String> _expiryAttemptedIds = {};
  bool loading = false;
  bool busy = false;
  String? error;

  OfferProvider({
    OfferRepository? repository,
    String? Function()? currentUidProvider,
    String Function()? currentNameProvider,
    bool autoStart = true,
  })  : _repo = repository ?? _safeRepo(),
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
    }
  }

  static OfferRepository? _safeRepo() {
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
    made = [];
    received = [];
    _readNotificationIds.clear();
    _buyerPinCache.clear();
    _expiryAttemptedIds.clear();
    error = null;
    _madeSub?.cancel();
    _receivedSub?.cancel();
    _prefSub?.cancel();
    _startStreams();
  }

  String pinForOffer(MarketOffer offer) {
    return _buyerPinCache[offer.id] ?? offer.handoverCode;
  }

  Future<void> fetchBuyerHandoverPin(String offerId) async {
    if (_buyerPinCache.containsKey(offerId)) return;
    final code = await _repo?.fetchBuyerHandoverPin(offerId);
    if (code != null && code.isNotEmpty) {
      _buyerPinCache[offerId] = code;
      notifyListeners();
    }
  }

  void _startStreams() {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();

    _prefSub = repo.watchReadNotifications(uid).listen((saved) {
      _readNotificationIds
        ..clear()
        ..addAll(saved);
      notifyListeners();
    }, onError: (_) {});

    _madeSub = repo.watchMadeOffers(uid).listen(
      (list) {
        made = [...list]..sort(_offerSort);
        loading = false;
        for (final o in made) {
          if (o.status == 'accepted' && (o.hasPin || o.handoverCode.isEmpty)) {
            unawaited(fetchBuyerHandoverPin(o.id));
          }
        }
        _scheduleExpirySweep(made, uid);
        notifyListeners();
      },
      onError: (e) {
        loading = false;
        error =
            'Could not load offers: ${MarketplaceLogic.mapError(e)}';
        notifyListeners();
      },
    );

    _receivedSub = repo.watchReceivedOffers(uid).listen(
      (list) {
        received = [...list]..sort(_offerSort);
        loading = false;
        _scheduleExpirySweep(received, uid);
        notifyListeners();
      },
      onError: (e) {
        loading = false;
        error =
            'Could not load offers: ${MarketplaceLogic.mapError(e)}';
        notifyListeners();
      },
    );
  }

  void _scheduleExpirySweep(List<MarketOffer> offers, String uid) {
    final repo = _repo;
    if (repo == null) return;
    final due = offers
        .where((o) =>
            (o.status == 'pending' || o.status == 'countered') &&
            o.isExpired &&
            _expiryAttemptedIds.add(o.id))
        .toList();
    if (due.isNotEmpty) {
      unawaited(repo.markExpiredIfDue(due, uid));
    }
  }

  int _offerSort(MarketOffer a, MarketOffer b) {
    final am =
        a.updatedAt?.millisecondsSinceEpoch ??
        a.createdAt?.millisecondsSinceEpoch ??
        0;
    final bm =
        b.updatedAt?.millisecondsSinceEpoch ??
        b.createdAt?.millisecondsSinceEpoch ??
        0;
    return bm.compareTo(am);
  }

  List<AppNotification> get notifications {
    final list = <AppNotification>[];
    final currentUid = _uidProvider();
    if (currentUid == null || currentUid.isEmpty) return list;

    for (final offer in received) {
      if (offer.isExpired) continue;
      if (offer.status == 'pending') {
        final id = 'pending_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'New Offer Received',
          body:
              '${offer.buyerName} offered ${offer.amount} ৳ on "${offer.listingTitle}".',
          type: 'offer_received',
          listingId: offer.listingId,
          listingTitle: offer.listingTitle,
          offerId: offer.id,
          amount: offer.amount,
          timestamp: offer.createdAt?.toDate() ?? DateTime.now(),
          isRead: _readNotificationIds.contains(id),
        ));
      } else if (offer.status == 'countered') {
        final id = 'seller_counter_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'Counter Offer Active',
          body: 'Counter sent: ${offer.amount} ৳ on "${offer.listingTitle}".',
          type: 'counter_offer',
          listingId: offer.listingId,
          listingTitle: offer.listingTitle,
          offerId: offer.id,
          amount: offer.amount,
          timestamp: offer.updatedAt?.toDate() ?? DateTime.now(),
          isRead: _readNotificationIds.contains(id),
        ));
      } else if (offer.status == 'accepted') {
        final id = 'seller_accepted_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'Offer Accepted! Listing Reserved',
          body:
              'You accepted ${offer.buyerName}\'s offer of ${offer.amount} ৳ for "${offer.listingTitle}".',
          type: 'offer_accepted',
          listingId: offer.listingId,
          listingTitle: offer.listingTitle,
          offerId: offer.id,
          amount: offer.amount,
          timestamp: offer.updatedAt?.toDate() ?? DateTime.now(),
          isRead: _readNotificationIds.contains(id),
        ));
      }
    }

    for (final offer in made) {
      if (offer.status == 'countered' && !offer.isExpired) {
        final id = 'buyer_counter_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'Seller Countered Your Offer',
          body:
              'New counter price: ${offer.amount} ৳ on "${offer.listingTitle}". Tap to respond.',
          type: 'counter_offer',
          listingId: offer.listingId,
          listingTitle: offer.listingTitle,
          offerId: offer.id,
          amount: offer.amount,
          timestamp: offer.updatedAt?.toDate() ?? DateTime.now(),
          isRead: _readNotificationIds.contains(id),
        ));
      } else if (offer.status == 'accepted') {
        final id = 'buyer_accepted_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'Offer Accepted!',
          body:
              'Your offer of ${offer.amount} ৳ on "${offer.listingTitle}" was accepted.',
          type: 'offer_accepted',
          listingId: offer.listingId,
          listingTitle: offer.listingTitle,
          offerId: offer.id,
          amount: offer.amount,
          timestamp: offer.updatedAt?.toDate() ?? DateTime.now(),
          isRead: _readNotificationIds.contains(id),
        ));
      } else if (offer.status == 'declined') {
        final id = 'buyer_declined_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'Offer Declined',
          body:
              'Your offer of ${offer.amount} ৳ on "${offer.listingTitle}" was declined.',
          type: 'offer_declined',
          listingId: offer.listingId,
          listingTitle: offer.listingTitle,
          offerId: offer.id,
          amount: offer.amount,
          timestamp: offer.updatedAt?.toDate() ?? DateTime.now(),
          isRead: _readNotificationIds.contains(id),
        ));
      }
    }

    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  void markNotificationRead(String id) {
    _readNotificationIds.add(id);
    notifyListeners();
    final uid = _uidProvider();
    if (uid != null && uid.isNotEmpty) {
      unawaited(_repo?.saveReadNotifications(uid, _readNotificationIds));
    }
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      _readNotificationIds.add(n.id);
    }
    notifyListeners();
    final uid = _uidProvider();
    if (uid != null && uid.isNotEmpty) {
      unawaited(_repo?.saveReadNotifications(uid, _readNotificationIds));
    }
  }

  Future<String?> verifyOfferEligibility(Listing listing) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty) {
      return 'You must be signed in to make an offer';
    }
    if (listing.sellerId == uid) {
      return 'You cannot make an offer on your own listing';
    }
    if (repo == null) return 'Offer service unavailable';
    try {
      return await repo.verifyOfferEligibility(listing: listing, buyerUid: uid);
    } catch (e) {
      return MarketplaceLogic.mapError(
        e,
        fallback: 'Unable to verify listing availability right now',
      );
    }
  }

  Future<bool> makeOffer(
    Listing listing,
    int amount,
    String message, {
    bool feePaid = false,
    String feeTransactionId = '',
  }) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) {
      error = 'You must be signed in to make an offer';
      notifyListeners();
      return false;
    }
    if (listing.sellerId == uid) {
      error = 'You cannot make an offer on your own listing';
      notifyListeners();
      return false;
    }
    if (amount <= 0) {
      error = 'Offer must be greater than zero';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      await repo.submitOffer(
        listing: listing,
        buyerUid: uid,
        buyerFallbackName: _nameProvider(),
        amount: amount,
        message: message,
        feePaid: feePaid,
        feeTransactionId: feeTransactionId,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not send offer');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> transition(
    MarketOffer offer,
    String action, {
    String? handoverPin,
  }) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) {
      error = 'You must be signed in to manage offers';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final parsedAction = MarketplaceLogic.parseAction(action);
      await repo.transitionOffer(
        offer: offer,
        action: parsedAction,
        actorUid: uid,
        handoverPin: handoverPin,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not update offer');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> counterOffer(MarketOffer offer, int amount) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) return false;
    if (amount <= 0) {
      error = 'Counter offer must be greater than zero';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      await repo.transitionOffer(
        offer: offer,
        action: OfferAction.counter,
        actorUid: uid,
        counterAmount: amount,
      );
      return true;
    } catch (e) {
      error =
          MarketplaceLogic.mapError(e, fallback: 'Could not send counter offer');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _madeSub?.cancel();
    _receivedSub?.cancel();
    _prefSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
