import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'member_lookup.dart';

class ChatRepository {
  final FirebaseFirestore _db;

  ChatRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Stream<List<ChatThread>> watchThreads(String uid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ChatThread.fromSnapshot).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return _db
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromSnapshot).toList());
  }

  Future<void> markThreadRead(String threadId, String uid) async {
    if (uid.isEmpty || threadId.isEmpty) return;
    try {
      final ref = _db.collection('chats').doc(threadId);
      final snap = await ref.get();
      if (!snap.exists) return;
      await ref.update({
        'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String listingId,
    required String listingTitle,
    required int listingPrice,
    required String buyerId,
    required String buyerName,
    required String sellerId,
    required String sellerName,
    required String text,
  }) async {
    final buyerMeta = await resolveMemberProfile(_db, buyerId, buyerName);
    final sellerMeta = await resolveMemberProfile(_db, sellerId, sellerName);
    final senderMeta = senderId == buyerId ? buyerMeta : sellerMeta;

    final threadRef = _db.collection('chats').doc(threadId);
    await threadRef.set({
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingPrice': listingPrice,
      'buyerId': buyerId,
      'buyerName': buyerMeta.name,
      'buyerPhotoUrl': buyerMeta.photoUrl,
      'sellerId': sellerId,
      'sellerName': sellerMeta.name,
      'sellerPhotoUrl': sellerMeta.photoUrl,
      'participants': [buyerId, sellerId],
      'lastMessage': text.trim(),
      'lastMessageSenderId': senderId,
      'lastReadAtBy': {senderId: FieldValue.serverTimestamp()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await threadRef.collection('messages').add({
      'senderId': senderId,
      'senderName': senderMeta.name,
      'senderPhotoUrl': senderMeta.photoUrl,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class ReportRepository {
  final FirebaseFirestore _db;

  ReportRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String targetTitle,
    required String targetUserId,
    required String reporterId,
    required String reporterName,
    required String reason,
    required String details,
  }) async {
    await _db.collection('reports').add({
      'targetType': targetType,
      'targetId': targetId,
      'targetTitle': targetTitle,
      'targetUserId': targetUserId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reason': reason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminRepository {
  final FirebaseFirestore _db;

  AdminRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Stream<PlatformFeeSettings> watchFeeSettings() {
    return _db
        .collection('platform_settings')
        .doc('fees')
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        return PlatformFeeSettings.fromMap(snap.data());
      }
      // Safely keep optional fee checkout disabled unless explicitly enabled
      // under Admin governance without paid gateways.
      return const PlatformFeeSettings(
        sellerListingFee: 0,
        buyerOrderFee: 0,
        feesEnabled: false,
      );
    });
  }

  Stream<List<PlatformPaymentRecord>> watchPayments() {
    return _db
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(PlatformPaymentRecord.fromSnapshot).toList());
  }

  Stream<PlatformMetrics> watchMetrics() {
    return _db
        .collection('platform_metrics')
        .doc('global')
        .snapshots()
        .map((s) => PlatformMetrics.fromMap(s.data()));
  }

  Stream<List<Listing>> watchAllListings() {
    return _db
        .collection('listings')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(Listing.fromSnapshot).toList());
  }

  Stream<List<MarketOffer>> watchAllOffers() {
    return _db
        .collection('offers')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(MarketOffer.fromSnapshot).toList());
  }

  Stream<List<Map<String, dynamic>>> watchAllUsers() {
    return _db.collection('users').limit(100).snapshots().map(
          (s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList(),
        );
  }

  Stream<List<ReportRecord>> watchAllReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(ReportRecord.fromSnapshot).toList());
  }

  Future<void> saveFeeSettings(PlatformFeeSettings settings) {
    return _db
        .collection('platform_settings')
        .doc('fees')
        .set(settings.toMap(), SetOptions(merge: true));
  }

  Future<PlatformPaymentRecord> recordSandboxFeePayment({
    required String uid,
    required String userName,
    required String userEmail,
    required String type,
    required int amount,
    required String method,
    required String referenceId,
    required String referenceTitle,
  }) async {
    final txnId =
        'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final docRef = await _db.collection('payments').add({
      'userId': uid,
      'userName': userName,
      'userEmail': userEmail,
      'type': type,
      'amount': amount,
      'currency': 'BDT',
      'method': method,
      'transactionId': txnId,
      'referenceId': referenceId,
      'referenceTitle': referenceTitle,
      'status': 'completed',
      'gatewayMode': 'spark_sandbox',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return PlatformPaymentRecord(
      id: docRef.id,
      userId: uid,
      userName: userName,
      userEmail: userEmail,
      type: type,
      amount: amount,
      currency: 'BDT',
      method: method,
      transactionId: txnId,
      referenceId: referenceId,
      referenceTitle: referenceTitle,
      status: 'completed',
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteListing(String listingId) {
    return _db.collection('listings').doc(listingId).delete();
  }

  Future<void> updateListingStatus(String listingId, String status) {
    return _db.collection('listings').doc(listingId).update({
      'status': status,
      if (status == 'available') 'reservedFor': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateOfferStatus(MarketOffer offer, String status) async {
    await _db.runTransaction((tx) async {
      final offerRef = _db.collection('offers').doc(offer.id);
      final listingRef = _db.collection('listings').doc(offer.listingId);
      final listingSnap = await tx.get(listingRef);
      final alreadyCounted = listingSnap.data()?['statsCounted'] == true;
      DocumentSnapshot<Map<String, dynamic>>? sellerSnap;
      DocumentSnapshot<Map<String, dynamic>>? buyerSnap;
      if (status == 'completed' && !alreadyCounted) {
        sellerSnap = await tx.get(_db.collection('users').doc(offer.sellerId));
        buyerSnap = await tx.get(_db.collection('users').doc(offer.buyerId));
      }

      tx.update(offerRef, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (status == 'completed') {
        tx.update(listingRef, {
          'status': 'sold',
          'statsCounted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!alreadyCounted && sellerSnap != null && buyerSnap != null) {
          tx.set(
            _db.collection('users').doc(offer.sellerId),
            {
              'soldCount':
                  ((sellerSnap.data()?['soldCount'] as num?)?.toInt() ?? 0) + 1,
              'lastCompletedOfferId': offer.id,
            },
            SetOptions(merge: true),
          );
          tx.set(
            _db.collection('users').doc(offer.buyerId),
            {
              'boughtCount':
                  ((buyerSnap.data()?['boughtCount'] as num?)?.toInt() ?? 0) +
                      1,
              'lastCompletedOfferId': offer.id,
            },
            SetOptions(merge: true),
          );
        }
      } else if (status == 'declined') {
        tx.update(listingRef, {
          'status': 'available',
          'reservedFor': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> refundPayment(String paymentId) {
    return _db.collection('payments').doc(paymentId).update({
      'status': 'refunded',
    });
  }

  Future<void> setUserAdminRole(String uid, bool makeAdmin) {
    return _db.collection('users').doc(uid).set({
      'role': makeAdmin ? 'admin' : 'customer',
      'isAdmin': makeAdmin,
    }, SetOptions(merge: true));
  }

  Future<void> setUserBanned(String uid, bool banned) {
    return _db.collection('users').doc(uid).set({
      'isBanned': banned,
    }, SetOptions(merge: true));
  }

  Future<void> resolveReport(String reportId, String status) {
    return _db.collection('reports').doc(reportId).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}
