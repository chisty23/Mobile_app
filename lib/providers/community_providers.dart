import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/community_repository.dart';
import '../utils/formatters.dart';

class ReportProvider extends ChangeNotifier {
  final ReportRepository? _repo;
  final String? Function() _uidProvider;
  final String Function() _nameProvider;

  bool busy = false;
  String? error;

  ReportProvider({
    ReportRepository? repository,
    String? Function()? currentUidProvider,
    String Function()? currentNameProvider,
  })  : _repo = repository ?? _safeRepo(),
        _uidProvider = currentUidProvider ?? _defaultUid,
        _nameProvider = currentNameProvider ?? _defaultName;

  static ReportRepository? _safeRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return ReportRepository();
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

  Future<bool> submitReport({
    required String targetType,
    required String targetId,
    required String targetTitle,
    String targetUserId = '',
    required String reason,
    String details = '',
  }) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) {
      error = 'Please sign in to submit a report';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repo.submitReport(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
        targetUserId: targetUserId,
        reporterId: uid,
        reporterName: _nameProvider(),
        reason: reason,
        details: details,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not submit report');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class ChatProvider extends ChangeNotifier {
  final ChatRepository? _repo;
  final String? Function() _uidProvider;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ChatThread>>? _threadSub;
  List<ChatThread> threads = [];
  final Map<String, DateTime> _locallyReadAt = {};
  bool sending = false;
  String? error;

  ChatProvider({
    ChatRepository? repository,
    String? Function()? currentUidProvider,
    bool autoStart = true,
  })  : _repo = repository ?? _safeRepo(),
        _uidProvider = currentUidProvider ?? _defaultUid {
    if (autoStart) {
      try {
        if (Firebase.apps.isNotEmpty) {
          _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
            threads = [];
            _locallyReadAt.clear();
            error = null;
            _threadSub?.cancel();
            _startStream();
          });
        }
      } catch (_) {}
      _startStream();
    }
  }

  static ChatRepository? _safeRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return ChatRepository();
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

  void _startStream() {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty || repo == null) {
      notifyListeners();
      return;
    }
    _threadSub = repo.watchThreads(uid).listen((list) {
      threads = list;
      notifyListeners();
    }, onError: (_) {});
  }

  bool isThreadUnread(ChatThread thread) {
    final uid = _uidProvider() ?? '';
    if (uid.isEmpty || !thread.isUnreadFor(uid)) return false;
    final localRead = _locallyReadAt[thread.id];
    if (localRead != null &&
        !thread.updatedAt.isAfter(localRead.add(const Duration(seconds: 2)))) {
      return false;
    }
    return true;
  }

  int get unreadThreadsCount => threads.where(isThreadUnread).length;

  String threadIdFor(String listingId, String buyerId) =>
      '${listingId}_$buyerId';

  Stream<List<ChatMessage>> messagesStream(String threadId) {
    final repo = _repo;
    if (repo == null) return const Stream.empty();
    return repo.watchMessages(threadId);
  }

  Future<void> markThreadRead(String threadId) async {
    final uid = _uidProvider();
    final repo = _repo;
    if (uid == null || uid.isEmpty) return;
    _locallyReadAt[threadId] = DateTime.now();
    notifyListeners();
    if (repo == null) return;
    await repo.markThreadRead(threadId, uid);
  }

  Future<bool> sendMessage({
    required String threadId,
    required String listingId,
    required String listingTitle,
    required int listingPrice,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String text,
  }) async {
    final uid = _uidProvider();
    final repo = _repo;
    final clean = text.trim();
    if (uid == null || uid.isEmpty || clean.isEmpty || repo == null) {
      return false;
    }

    sending = true;
    error = null;
    notifyListeners();
    try {
      await repo.sendMessage(
        threadId: threadId,
        senderId: uid,
        listingId: listingId,
        listingTitle: listingTitle,
        listingPrice: listingPrice,
        buyerId: buyerId,
        buyerName: buyerName,
        sellerId: sellerId,
        sellerName: sellerName,
        text: clean,
      );
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not send message');
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _threadSub?.cancel();
    super.dispose();
  }
}

class AdminProvider extends ChangeNotifier {
  final AdminRepository? _repo;
  final FirestoreAuthRepository? _authRepo;

  PlatformFeeSettings feeSettings = const PlatformFeeSettings(
    sellerListingFee: 0,
    buyerOrderFee: 0,
    feesEnabled: false,
  );
  PlatformMetrics globalMetrics = const PlatformMetrics();
  List<PlatformPaymentRecord> payments = [];
  List<Listing> allListings = [];
  List<MarketOffer> allOffers = [];
  List<Map<String, dynamic>> allUsers = [];
  List<ReportRecord> reports = [];
  bool isCurrentUserAdmin = false;
  bool loading = true;
  bool busy = false;
  String? error;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<PlatformFeeSettings>? _feeSub;
  StreamSubscription<PlatformMetrics>? _metricsSub;
  StreamSubscription<UserAccountSnapshot>? _userRoleSub;
  StreamSubscription<List<PlatformPaymentRecord>>? _paySub;
  StreamSubscription<List<Listing>>? _listingsSub;
  StreamSubscription<List<MarketOffer>>? _offersSub;
  StreamSubscription<List<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<List<ReportRecord>>? _reportsSub;

  AdminProvider({
    AdminRepository? repository,
    FirestoreAuthRepository? authRepository,
    bool autoStart = true,
  })  : _repo = repository ?? _safeAdminRepo(),
        _authRepo = authRepository ?? _safeAuthRepo() {
    if (autoStart) {
      try {
        if (Firebase.apps.isNotEmpty) {
          _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
            _cancelStreams();
            _initStreams();
          });
        }
      } catch (_) {}
      _initStreams();
    } else {
      loading = false;
    }
  }

  static AdminRepository? _safeAdminRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return AdminRepository();
    } catch (_) {
      return null;
    }
  }

  static FirestoreAuthRepository? _safeAuthRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreAuthRepository();
    } catch (_) {
      return null;
    }
  }

  void _cancelStreams() {
    _feeSub?.cancel();
    _metricsSub?.cancel();
    _userRoleSub?.cancel();
    _paySub?.cancel();
    _listingsSub?.cancel();
    _offersSub?.cancel();
    _usersSub?.cancel();
    _reportsSub?.cancel();
  }

  void _initStreams() {
    final repo = _repo;
    final authRepo = _authRepo;
    if (repo == null || authRepo == null) {
      loading = false;
      notifyListeners();
      return;
    }

    _feeSub = repo.watchFeeSettings().listen((settings) {
      feeSettings = settings;
      notifyListeners();
    }, onError: (_) {});

    final user = authRepo.currentUser;
    if (user == null) {
      payments = [];
      allListings = [];
      allOffers = [];
      allUsers = [];
      reports = [];
      globalMetrics = const PlatformMetrics();
      isCurrentUserAdmin = false;
      loading = false;
      notifyListeners();
      return;
    }

    _userRoleSub = authRepo.watchUserAccount(user.uid).listen((acc) {
      isCurrentUserAdmin = acc.isAdmin;
      if (isCurrentUserAdmin) {
        _startAdminStreams();
      } else {
        _paySub?.cancel();
        _metricsSub?.cancel();
        _reportsSub?.cancel();
        _listingsSub?.cancel();
        _offersSub?.cancel();
        _usersSub?.cancel();
        loading = false;
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _startAdminStreams() {
    final repo = _repo;
    if (repo == null) return;

    _paySub?.cancel();
    _paySub = repo.watchPayments().listen((list) {
      payments = list;
      loading = false;
      notifyListeners();
    }, onError: (_) {
      loading = false;
      notifyListeners();
    });

    _metricsSub?.cancel();
    _metricsSub = repo.watchMetrics().listen((m) {
      globalMetrics = m;
      notifyListeners();
    }, onError: (_) {});

    _listingsSub?.cancel();
    _listingsSub = repo.watchAllListings().listen((list) {
      allListings = list;
      notifyListeners();
    }, onError: (_) {});

    _offersSub?.cancel();
    _offersSub = repo.watchAllOffers().listen((list) {
      allOffers = list;
      notifyListeners();
    }, onError: (_) {});

    _usersSub?.cancel();
    _usersSub = repo.watchAllUsers().listen((list) {
      allUsers = list;
      notifyListeners();
    }, onError: (_) {});

    _reportsSub?.cancel();
    _reportsSub = repo.watchAllReports().listen((list) {
      reports = list;
      notifyListeners();
    }, onError: (_) {});
  }

  int get totalRevenueBDT => globalMetrics.hasData
      ? globalMetrics.totalRevenueBDT
      : payments
          .where((p) => p.status != 'refunded')
          .fold(0, (total, p) => total + p.amount);

  int get refundedRevenueBDT => globalMetrics.hasData
      ? globalMetrics.refundedRevenueBDT
      : payments
          .where((p) => p.status == 'refunded')
          .fold(0, (total, p) => total + p.amount);

  int get sellerRevenueBDT => globalMetrics.hasData
      ? globalMetrics.sellerRevenueBDT
      : payments
          .where((p) => p.type == 'seller_listing_fee' && p.status != 'refunded')
          .fold(0, (total, p) => total + p.amount);

  int get buyerRevenueBDT => globalMetrics.hasData
      ? globalMetrics.buyerRevenueBDT
      : payments
          .where((p) => p.type == 'buyer_order_fee' && p.status != 'refunded')
          .fold(0, (total, p) => total + p.amount);

  int get totalListingsCount => allListings.length;
  int get availableListingsCount =>
      allListings.where((l) => l.isAvailable).length;
  int get reservedListingsCount =>
      allListings.where((l) => l.isReserved).length;
  int get soldListingsCount => allListings.where((l) => l.isSold).length;

  int get totalOrdersCount => allOffers.length;
  int get pendingOrdersCount =>
      allOffers.where((o) => o.status == 'pending').length;
  int get acceptedOrdersCount =>
      allOffers.where((o) => o.status == 'accepted').length;
  int get completedOrdersCount =>
      allOffers.where((o) => o.status == 'completed').length;
  int get openReportsCount => reports.where((r) => r.status == 'open').length;

  Future<bool> updateFees({
    required int sellerListingFee,
    required int buyerOrderFee,
    required bool feesEnabled,
  }) async {
    final repo = _repo;
    if (repo == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final user = _authRepo?.currentUser;
      final newSettings = PlatformFeeSettings(
        sellerListingFee: sellerListingFee,
        buyerOrderFee: buyerOrderFee,
        feesEnabled: feesEnabled,
        updatedAt: DateTime.now(),
        updatedBy: user?.displayName ?? user?.email ?? 'Admin',
      );
      await repo.saveFeeSettings(newSettings);
      feeSettings = newSettings;
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Failed to update fees');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Records a free Spark-plan simulated sandbox fee receipt without invoking
  /// Cloud Functions or external paid gateways.
  Future<PaymentInitResult?> initiateServerPayment({
    required String type,
    required String method,
    required String referenceId,
    required String referenceTitle,
    String phone = '',
  }) async {
    final repo = _repo;
    final user = _authRepo?.currentUser;
    if (repo == null || user == null) {
      error = 'Sign in required for checkout';
      notifyListeners();
      return null;
    }
    if (!feeSettings.feesEnabled) {
      error = 'Platform fees are currently disabled';
      notifyListeners();
      return null;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final requiredAmt = type == 'seller_listing_fee'
          ? feeSettings.sellerListingFee
          : feeSettings.buyerOrderFee;
      final record = await repo.recordSandboxFeePayment(
        uid: user.uid,
        userName: user.displayName ?? 'Campus Trader',
        userEmail: user.email ?? '',
        type: type,
        amount: requiredAmt,
        method: method,
        referenceId: referenceId,
        referenceTitle: referenceTitle,
      );
      return PaymentInitResult(mode: 'sandbox_completed', payment: record);
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Payment checkout failed');
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteListingAsAdmin(String listingId) async {
    try {
      await _repo?.deleteListing(listingId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateListingStatusAsAdmin(String listingId, String status) async {
    try {
      await _repo?.updateListingStatus(listingId, status);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateOfferStatusAsAdmin(
    MarketOffer offer,
    String status,
  ) async {
    try {
      await _repo?.updateOfferStatus(offer, status);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refundPaymentRecord(String paymentId) async {
    try {
      await _repo?.refundPayment(paymentId);
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not issue refund');
      return false;
    }
  }

  Future<bool> toggleUserRoleAsAdmin(String uid, bool makeAdmin) async {
    try {
      await _repo?.setUserAdminRole(uid, makeAdmin);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> banUserAsAdmin(String uid, bool banned) async {
    try {
      await _repo?.setUserBanned(uid, banned);
      return true;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Action failed');
      return false;
    }
  }

  Future<bool> resolveReport(String reportId, String status) async {
    try {
      await _repo?.resolveReport(reportId, status);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelStreams();
    super.dispose();
  }
}
