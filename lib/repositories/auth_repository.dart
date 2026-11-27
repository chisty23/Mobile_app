import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models.dart';
import '../utils/formatters.dart';

class UserAccountSnapshot {
  final bool exists;
  final Map<String, dynamic> data;

  const UserAccountSnapshot({required this.exists, required this.data});

  bool get isBanned => data['isBanned'] == true;
  bool get isAdmin =>
      (data['role'] as String? ?? 'customer') == 'admin' ||
      (data['isAdmin'] as bool? ?? false);
}

class PhoneOtpSession {
  final ConfirmationResult? webConfirmation;
  final String? mobileVerificationId;

  const PhoneOtpSession({this.webConfirmation, this.mobileVerificationId});
}

class FirestoreAuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  FirestoreAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Stream<UserAccountSnapshot> watchUserAccount(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (snap) => UserAccountSnapshot(
            exists: snap.exists,
            data: snap.data() ?? const <String, dynamic>{},
          ),
        );
  }

  Stream<List<PublicUserProfile>> watchPublicProfiles({int limit = 250}) {
    return _db
        .collection('public_profiles')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(PublicUserProfile.fromSnapshot).toList());
  }

  Future<PublicUserProfile?> fetchPublicProfile(String uid) async {
    final pub = await _db.collection('public_profiles').doc(uid).get();
    if (pub.exists && pub.data() != null) {
      return PublicUserProfile.fromSnapshot(pub);
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> syncPublicAndPhoneDirectory({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    await _db.collection('public_profiles').doc(uid).set({
      'name': (userData['name'] as String?) ?? AppFormatters.unknownUserName,
      'photoUrl': (userData['photoUrl'] as String?) ?? '',
      'bio': (userData['bio'] as String?) ?? '',
      'department': (userData['department'] as String?) ?? '',
      'hostel': (userData['hostel'] as String?) ?? '',
      'location': (userData['location'] as String?) ?? '',
      'batchYear': (userData['batchYear'] as String?) ?? '',
      'meetupSpot': (userData['meetupSpot'] as String?) ?? '',
      'verifiedStudent': userData['verifiedStudent'] == true,
      'phoneVerified': userData['phoneVerified'] == true,
      'emailVerified': _auth.currentUser?.emailVerified == true,
      'soldCount': (userData['soldCount'] as num?)?.toInt() ?? 0,
      'boughtCount': (userData['boughtCount'] as num?)?.toInt() ?? 0,
      'ratingSum': (userData['ratingSum'] as num?)?.toInt() ?? 0,
      'ratingCount': (userData['ratingCount'] as num?)?.toInt() ?? 0,
      'isBanned': userData['isBanned'] == true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final normPhone =
        AppFormatters.normalizePhone((userData['phone'] as String?) ?? '');
    final authEmail =
        ((userData['recoveryEmail'] as String?)?.trim().isNotEmpty == true
                ? userData['recoveryEmail'] as String
                : (userData['email'] as String?) ??
                    _auth.currentUser?.email ??
                    '')
            .trim();
    if (normPhone.isNotEmpty && authEmail.isNotEmpty) {
      await _db.collection('phone_directory').doc(normPhone).set({
        'uid': uid,
        'authEmail': authEmail,
        'maskedEmail': AppFormatters.maskEmail(authEmail),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> syncSellerListingsMetadata({
    required String uid,
    required String name,
    required String photoUrl,
  }) async {
    final snap = await _db
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .limit(50)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    var dirty = false;
    for (final doc in snap.docs) {
      final d = doc.data();
      if ((d['sellerName'] ?? '') != name ||
          (d['sellerPhotoUrl'] ?? '') != photoUrl) {
        batch.update(doc.reference, {
          'sellerName': name,
          'sellerPhotoUrl': photoUrl,
        });
        dirty = true;
      }
    }
    if (dirty) await batch.commit();
  }

  Future<Map<String, dynamic>?> lookupPhoneDirectory(String normPhone) async {
    final doc = await _db.collection('phone_directory').doc(normPhone).get();
    return doc.exists ? doc.data() : null;
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
  ) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> createUserDoc(String uid, Map<String, dynamic> userData) {
    return _db.collection('users').doc(uid).set(userData);
  }

  Future<void> updateUserDoc(String uid, Map<String, dynamic> updates) {
    return _db
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  Future<void> deletePhoneIfOwned(String normPhone, String uid) async {
    final doc = await _db.collection('phone_directory').doc(normPhone).get();
    if (doc.exists && doc.data()?['uid'] == uid) {
      await doc.reference.delete();
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<PhoneOtpSession> sendPhoneOtp({
    required String normPhone,
    required bool linkToCurrentUser,
  }) async {
    if (kIsWeb) {
      final confirmation = (linkToCurrentUser && _auth.currentUser != null)
          ? await _auth.currentUser!.linkWithPhoneNumber(normPhone)
          : await _auth.signInWithPhoneNumber(normPhone);
      return PhoneOtpSession(webConfirmation: confirmation);
    }

    final completer = Completer<PhoneOtpSession>();
    await _auth.verifyPhoneNumber(
      phoneNumber: normPhone,
      verificationCompleted: (PhoneAuthCredential cred) async {
        try {
          if (linkToCurrentUser && _auth.currentUser != null) {
            await _auth.currentUser!.linkWithCredential(cred);
          } else {
            await _auth.signInWithCredential(cred);
          }
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpSession(mobileVerificationId: verId));
        }
      },
      codeAutoRetrievalTimeout: (String verId) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpSession(mobileVerificationId: verId));
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 30));
  }

  Future<UserCredential> confirmPhoneOtp({
    required PhoneOtpSession session,
    required String smsCode,
    required bool linkToCurrentUser,
  }) async {
    if (kIsWeb) {
      return session.webConfirmation!.confirm(smsCode);
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: session.mobileVerificationId!,
      smsCode: smsCode,
    );
    if (linkToCurrentUser && _auth.currentUser != null) {
      return _auth.currentUser!.linkWithCredential(credential);
    }
    return _auth.signInWithCredential(credential);
  }

  Future<void> deleteUserAccountAndData(User user, String? password) async {
    if (password != null && password.isNotEmpty && user.email != null) {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    }

    final uid = user.uid;
    final listings =
        await _db.collection('listings').where('sellerId', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final doc in listings.docs) {
      batch.delete(doc.reference);
    }
    final favs =
        await _db.collection('users').doc(uid).collection('favorites').get();
    for (final doc in favs.docs) {
      batch.delete(doc.reference);
    }
    final phones = await _db
        .collection('phone_directory')
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in phones.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('public_profiles').doc(uid));
    batch.delete(_db.collection('users').doc(uid));
    await batch.commit();
    await user.delete();
  }

  Future<void> signOut() => _auth.signOut();
}
