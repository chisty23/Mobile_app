import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../models.dart';
import '../services/backend_api.dart';
import '../utils/formatters.dart';
import '../utils/storage_uploader.dart';

const List<String> _studentEmailSuffixes = [
  '.edu',
  '.edu.bd',
  '.ac.bd',
  '.ac.uk',
];

bool isVerifiedStudentEmail(String email) {
  final lower = email.trim().toLowerCase();
  return _studentEmailSuffixes.any(lower.endsWith);
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  StreamSubscription<User?>? _authSub;

  ThemeProvider() {
    _initPersistence();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void _initPersistence() {
    try {
      if (Firebase.apps.isEmpty) return;
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user == null) return;
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final savedDark = snap.data()?['darkMode'];
          if (savedDark is bool) {
            final target = savedDark ? ThemeMode.dark : ThemeMode.light;
            if (target != _themeMode) {
              _themeMode = target;
              notifyListeners();
            }
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _savePreference(bool dark) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'darkMode': dark,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _savePreference(isDark);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _savePreference(isDark);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class PasswordResetOutcome {
  final bool ok;
  final String message;
  final String deliveryTarget;
  final bool viaPhone;

  const PasswordResetOutcome({
    required this.ok,
    required this.message,
    this.deliveryTarget = '',
    this.viaPhone = false,
  });
}

class ProfileDirectoryProvider extends ChangeNotifier {
  final Map<String, PublicUserProfile> _publicProfiles = {};
  final Map<String, PublicUserProfile> _userFallbacks = {};
  final Set<String> _inFlight = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<User?>? _authSub;

  ProfileDirectoryProvider() {
    _initStream();
  }

  void _initStream() {
    try {
      if (Firebase.apps.isEmpty) return;
      _sub = FirebaseFirestore.instance
          .collection('public_profiles')
          .limit(250)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          _publicProfiles[doc.id] = PublicUserProfile.fromSnapshot(doc);
        }
        notifyListeners();
      }, onError: (_) {});

      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        _usersSub?.cancel();
        if (user == null) {
          _userFallbacks.clear();
          notifyListeners();
          return;
        }
        _subscribeUsersFallback();
      });
      if (FirebaseAuth.instance.currentUser != null) {
        _subscribeUsersFallback();
      }
    } catch (_) {}
  }

  void _subscribeUsersFallback() {
    _usersSub?.cancel();
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .limit(250)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        _userFallbacks[doc.id] = PublicUserProfile.fromSnapshot(doc);
      }
      notifyListeners();
    }, onError: (_) {});
  }

  PublicUserProfile? profileFor(String uid) {
    final pub = _publicProfiles[uid];
    final fb = _userFallbacks[uid];
    if (pub == null) return fb;
    if (fb == null) return pub;
    if (pub.photoUrl.isEmpty && fb.photoUrl.isNotEmpty) {
      return PublicUserProfile(
        uid: uid,
        name: pub.name.isNotEmpty ? pub.name : fb.name,
        photoUrl: fb.photoUrl,
        bio: pub.bio.isNotEmpty ? pub.bio : fb.bio,
        department: pub.department.isNotEmpty ? pub.department : fb.department,
        location: pub.location.isNotEmpty ? pub.location : fb.location,
        batchYear: pub.batchYear.isNotEmpty ? pub.batchYear : fb.batchYear,
        meetupSpot: pub.meetupSpot.isNotEmpty ? pub.meetupSpot : fb.meetupSpot,
        verifiedStudent: pub.verifiedStudent || fb.verifiedStudent,
        phoneVerified: pub.phoneVerified || fb.phoneVerified,
        emailVerified: pub.emailVerified || fb.emailVerified,
        soldCount: pub.soldCount > 0 ? pub.soldCount : fb.soldCount,
        boughtCount: pub.boughtCount > 0 ? pub.boughtCount : fb.boughtCount,
        ratingSum: pub.ratingSum > 0 ? pub.ratingSum : fb.ratingSum,
        ratingCount: pub.ratingCount > 0 ? pub.ratingCount : fb.ratingCount,
        isBanned: pub.isBanned || fb.isBanned,
        updatedAt: pub.updatedAt ?? fb.updatedAt,
      );
    }
    return pub;
  }

  String photoFor(String uid, {String fallback = ''}) {
    final p = profileFor(uid)?.photoUrl ?? '';
    return p.isNotEmpty ? p : fallback;
  }

  String nameFor(String uid, {String fallback = ''}) {
    final n = profileFor(uid)?.name ?? '';
    return n.isNotEmpty ? n : fallback;
  }

  void upsertLocal(PublicUserProfile profile) {
    _publicProfiles[profile.uid] = profile;
    _userFallbacks[profile.uid] = profile;
    notifyListeners();
  }

  Future<PublicUserProfile?> ensureLoaded(String uid) async {
    if (uid.trim().isEmpty) return null;
    final existing = profileFor(uid);
    if (existing != null && existing.photoUrl.isNotEmpty) return existing;
    if (_inFlight.contains(uid)) return existing;
    try {
      if (Firebase.apps.isEmpty) return existing;
      _inFlight.add(uid);
      final db = FirebaseFirestore.instance;
      final pub = await db.collection('public_profiles').doc(uid).get();
      if (pub.exists && pub.data() != null) {
        _publicProfiles[uid] = PublicUserProfile.fromSnapshot(pub);
      }
      if ((_publicProfiles[uid]?.photoUrl ?? '').isEmpty) {
        final legacy = await db.collection('users').doc(uid).get();
        if (legacy.exists && legacy.data() != null) {
          _userFallbacks[uid] = PublicUserProfile.fromMap(uid, legacy.data());
        }
      }
      notifyListeners();
      return profileFor(uid);
    } catch (_) {
    } finally {
      _inFlight.remove(uid);
    }
    return existing;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _usersSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _api = BackendApi();
  bool busy = false;
  String? error;
  bool guestMode = false;
  ConfirmationResult? _webConfirmation;
  String? _mobileVerificationId;
  StreamSubscription<User?>? _syncSub;

  AuthProvider() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _syncSub = _auth.authStateChanges().listen((user) {
          if (user != null) {
            unawaited(_backfillSignedInUser(user));
          }
        });
        final cur = _auth.currentUser;
        if (cur != null) {
          unawaited(_backfillSignedInUser(cur));
        }
      }
    } catch (_) {}
  }

  Future<void> _backfillSignedInUser(User user) async {
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null || data['isBanned'] == true) return;
      await _syncPublicAndPhoneDirectory(uid: user.uid, userData: data);
      await _syncSellerListingsMetadata(
        uid: user.uid,
        name: (data['name'] as String?) ?? user.displayName ?? 'PassItOn Member',
        photoUrl: (data['photoUrl'] as String?) ?? '',
      );
    } catch (_) {}
  }

  Future<void> _syncSellerListingsMetadata({
    required String uid,
    required String name,
    required String photoUrl,
  }) async {
    try {
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
    } catch (_) {}
  }

  User? get user => _auth.currentUser;

  void enterGuestMode() {
    guestMode = true;
    error = null;
    notifyListeners();
  }

  void exitGuestMode() {
    guestMode = false;
    notifyListeners();
  }

  Future<void> _syncPublicAndPhoneDirectory({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await _db.collection('public_profiles').doc(uid).set({
        'name': (userData['name'] as String?) ?? 'PassItOn Member',
        'photoUrl': (userData['photoUrl'] as String?) ?? '',
        'bio': (userData['bio'] as String?) ?? '',
        'department': (userData['department'] as String?) ?? '',
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

      final normPhone = AppFormatters.normalizePhone(
        (userData['phone'] as String?) ?? '',
      );
      final authEmail = ((userData['recoveryEmail'] as String?)?.trim().isNotEmpty == true
              ? userData['recoveryEmail'] as String
              : (userData['email'] as String?) ?? _auth.currentUser?.email ?? '')
          .trim();
      if (normPhone.isNotEmpty && authEmail.isNotEmpty) {
        await _db.collection('phone_directory').doc(normPhone).set({
          'uid': uid,
          'authEmail': authEmail,
          'maskedEmail': AppFormatters.maskEmail(authEmail),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<bool> login(String identifier, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      var authEmail = identifier.trim();
      if (AppFormatters.looksLikePhone(authEmail)) {
        final normPhone = AppFormatters.normalizePhone(authEmail);
        final phoneDoc =
            await _db.collection('phone_directory').doc(normPhone).get();
        if (!phoneDoc.exists) {
          error =
              'No account found for phone $normPhone. Sign in with Gmail or create a new account.';
          return false;
        }
        final resolvedEmail =
            (phoneDoc.data()?['authEmail'] as String?)?.trim() ?? '';
        if (resolvedEmail.isEmpty) {
          error =
              'This phone account uses SMS OTP verification. Tap "Verify via SMS OTP" to sign in.';
          return false;
        }
        authEmail = resolvedEmail;
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid != null) {
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data();
        if (data?['isBanned'] == true) {
          await _auth.signOut();
          error = 'This account has been suspended by marketplace moderation.';
          return false;
        }
        if (data != null) {
          unawaited(_syncPublicAndPhoneDirectory(uid: uid, userData: data));
        }
      }
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Login failed';
      return false;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not sign in';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<PasswordResetOutcome> sendPasswordResetByIdentifier(
    String identifier,
  ) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      error = 'Enter your Account Gmail or registered Phone Number';
      notifyListeners();
      return PasswordResetOutcome(ok: false, message: error!);
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      var targetEmail = trimmed;
      var viaPhone = false;

      if (AppFormatters.looksLikePhone(trimmed)) {
        viaPhone = true;
        final normPhone = AppFormatters.normalizePhone(trimmed);
        final phoneDoc =
            await _db.collection('phone_directory').doc(normPhone).get();
        if (!phoneDoc.exists) {
          error =
              'No account is linked to $normPhone. Enter your Account Gmail or verify via SMS OTP.';
          return PasswordResetOutcome(ok: false, message: error!);
        }
        final resolved =
            (phoneDoc.data()?['authEmail'] as String?)?.trim() ?? '';
        if (resolved.isEmpty || resolved.endsWith('@phone.passiton.app')) {
          error =
              'This phone number does not have an Account Gmail linked. Use SMS OTP Sign-In instead.';
          return PasswordResetOutcome(ok: false, message: error!);
        }
        targetEmail = resolved;
      } else if (!AppFormatters.isValidEmail(targetEmail)) {
        error = 'Enter a valid Gmail address or phone number';
        return PasswordResetOutcome(ok: false, message: error!);
      }

      await _auth.sendPasswordResetEmail(email: targetEmail);
      final targetDisplay =
          viaPhone ? AppFormatters.maskEmail(targetEmail) : targetEmail;
      return PasswordResetOutcome(
        ok: true,
        viaPhone: viaPhone,
        deliveryTarget: targetDisplay,
        message: viaPhone
            ? 'Verified phone! Password reset link sent to linked Gmail ($targetDisplay).'
            : 'Password reset verification link sent to $targetDisplay.',
      );
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Could not send reset email';
      return PasswordResetOutcome(ok: false, message: error!);
    } on FirebaseException catch (e) {
      error = e.message ?? 'Lookup failed';
      return PasswordResetOutcome(ok: false, message: error!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    final outcome = await sendPasswordResetByIdentifier(email);
    return outcome.ok;
  }

  /// Sends a Firebase SMS OTP verification code for Phone signup, login, or recovery.
  Future<bool> sendPhoneOtp(
    String rawPhone, {
    bool linkToCurrentUser = false,
  }) async {
    final normPhone = AppFormatters.normalizePhone(rawPhone);
    if (!AppFormatters.isValidPhone(normPhone)) {
      error = 'Enter a valid phone number (e.g. 017XXXXXXXX or +8801XXXXXXXXX)';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    _webConfirmation = null;
    _mobileVerificationId = null;
    notifyListeners();
    try {
      if (kIsWeb) {
        if (linkToCurrentUser && _auth.currentUser != null) {
          _webConfirmation =
              await _auth.currentUser!.linkWithPhoneNumber(normPhone);
        } else {
          _webConfirmation = await _auth.signInWithPhoneNumber(normPhone);
        }
        return true;
      }

      final completer = Completer<bool>();
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
          error = _mapPhoneAuthError(e);
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (String verId, int? resendToken) {
          _mobileVerificationId = verId;
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String verId) {
          _mobileVerificationId = verId;
        },
      );
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          error ??= 'Timed out waiting for SMS OTP code';
          return false;
        },
      );
    } on FirebaseAuthException catch (e) {
      error = _mapPhoneAuthError(e);
      return false;
    } catch (e) {
      error = 'SMS verification unavailable right now: $e';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Verifies an SMS OTP code to finish Phone login/recovery or link phone to current profile.
  Future<bool> verifyPhoneOtp({
    required String smsCode,
    required String rawPhone,
    String name = '',
    String department = '',
    String bio = '',
    String recoveryGmail = '',
    bool linkToCurrentUser = false,
  }) async {
    final code = smsCode.trim();
    if (code.length < 4) {
      error = 'Enter the 6-digit SMS code sent to your phone';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      UserCredential? cred;
      if (kIsWeb) {
        if (_webConfirmation == null) {
          error = 'Send the SMS verification code first';
          return false;
        }
        cred = await _webConfirmation!.confirm(code);
      } else {
        if (_mobileVerificationId == null) {
          error = 'Send the SMS verification code first';
          return false;
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: _mobileVerificationId!,
          smsCode: code,
        );
        if (linkToCurrentUser && _auth.currentUser != null) {
          cred = await _auth.currentUser!.linkWithCredential(credential);
        } else {
          cred = await _auth.signInWithCredential(credential);
        }
      }

      final user = cred.user ?? _auth.currentUser;
      if (user == null) {
        error = 'Could not verify phone number';
        return false;
      }

      final normPhone = AppFormatters.normalizePhone(rawPhone);
      final userRef = _db.collection('users').doc(user.uid);
      final existingSnap = await userRef.get();
      if (existingSnap.data()?['isBanned'] == true) {
        await _auth.signOut();
        error = 'This account has been suspended by marketplace moderation.';
        return false;
      }

      final cleanGmail = recoveryGmail.trim();
      final existingData = existingSnap.data() ?? <String, dynamic>{};
      final resolvedName = name.trim().isNotEmpty
          ? name.trim()
          : (existingData['name'] as String?) ??
              user.displayName ??
              'PassItOn Member';
      if (name.trim().isNotEmpty) {
        await user.updateDisplayName(resolvedName);
      }

      final payload = <String, dynamic>{
        'name': resolvedName,
        'email': cleanGmail.isNotEmpty
            ? cleanGmail
            : (existingData['email'] as String?) ?? user.email ?? '',
        if (cleanGmail.isNotEmpty) 'recoveryEmail': cleanGmail,
        'phone': normPhone,
        'phoneVerified': true,
        'department': department.trim().isNotEmpty
            ? department.trim()
            : (existingData['department'] as String?) ?? '',
        'bio': bio.trim().isNotEmpty
            ? bio.trim()
            : (existingData['bio'] as String?) ?? '',
        if (!existingSnap.exists) ...{
          'role': 'customer',
          'isAdmin': false,
          'isBanned': false,
          'verifiedStudent': isVerifiedStudentEmail(cleanGmail),
          'soldCount': 0,
          'boughtCount': 0,
          'ratingSum': 0,
          'ratingCount': 0,
          'photoUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await userRef.set(payload, SetOptions(merge: true));
      await _syncPublicAndPhoneDirectory(
        uid: user.uid,
        userData: {...existingData, ...payload},
      );
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = _mapPhoneAuthError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _mapPhoneAuthError(FirebaseAuthException e) {
    if (e.code == 'operation-not-allowed' || e.code == 'billing-not-enabled') {
      return 'SMS OTP is not enabled in Firebase Console yet. Register/recover using Phone + Account Gmail or enable Phone provider in Firebase Console.';
    }
    return e.message ?? 'Phone verification failed (${e.code})';
  }

  Future<bool> sendEmailVerification() async {
    final current = _auth.currentUser;
    if (current == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await current.sendEmailVerification();
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Could not send verification link';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> refreshUser() async {
    final current = _auth.currentUser;
    if (current == null) return false;
    try {
      await current.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;
      await _db.collection('public_profiles').doc(current.uid).set({
        'emailVerified': verified,
      }, SetOptions(merge: true));
      notifyListeners();
      return verified;
    } catch (_) {
      return false;
    }
  }

  Future<String> _uploadAvatarIfNeeded(String uid, String rawPhoto) async {
    final trimmed = rawPhoto.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('data:image')) return trimmed;
    final token = await _auth.currentUser?.getIdToken();
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket ??
        'pass-it-on-2f422.firebasestorage.app';
    return StorageUploader(bucket: bucket).uploadAvatarImage(
      rawImage: trimmed,
      uid: uid,
      idToken: token,
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String department = '',
    String phone = '',
    String bio = '',
    String location = '',
    String batchYear = '',
    String meetupSpot = '',
    String photoRaw = '',
    String accountMode = 'gmail',
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final cleanEmail = email.trim().toLowerCase();
      final normPhone = AppFormatters.normalizePhone(phone);

      if (accountMode == 'gmail') {
        if (!AppFormatters.isValidGmail(cleanEmail)) {
          error = 'Please use a valid @gmail.com address to create an account';
          return false;
        }
        if (phone.trim().isNotEmpty && !AppFormatters.isValidPhone(phone)) {
          error = 'Enter a valid phone number (e.g. 017XXXXXXXX)';
          return false;
        }
      } else {
        if (!AppFormatters.isValidPhone(phone)) {
          error = 'Please enter a valid phone number (e.g. 017XXXXXXXX)';
          return false;
        }
        if (!AppFormatters.isValidGmail(cleanEmail)) {
          error =
              'Enter your Account Gmail (@gmail.com) so password recovery links can reach you, or switch to SMS OTP';
          return false;
        }
      }

      if (normPhone.isNotEmpty) {
        final existingPhone =
            await _db.collection('phone_directory').doc(normPhone).get();
        if (existingPhone.exists) {
          error = 'This phone number is already linked to another account.';
          return false;
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(name.trim());

      final resolvedPhoto = photoRaw.trim().isNotEmpty
          ? await _uploadAvatarIfNeeded(user.uid, photoRaw)
          : '';
      if (resolvedPhoto.startsWith('http') && resolvedPhoto.length < 1800) {
        await user.updatePhotoURL(resolvedPhoto);
      }

      final userData = <String, dynamic>{
        'name': name.trim(),
        'email': cleanEmail,
        'recoveryEmail': cleanEmail,
        'department': department.trim(),
        'phone': normPhone,
        'phoneVerified': false,
        'bio': bio.trim(),
        'location': location.trim(),
        'batchYear': batchYear.trim(),
        'meetupSpot': meetupSpot.trim(),
        'photoUrl': resolvedPhoto,
        'role': 'customer',
        'isAdmin': false,
        'isBanned': false,
        'verifiedStudent': isVerifiedStudentEmail(cleanEmail),
        'soldCount': 0,
        'boughtCount': 0,
        'ratingSum': 0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('users').doc(user.uid).set(userData);
      await _syncPublicAndPhoneDirectory(uid: user.uid, userData: userData);

      try {
        await user.sendEmailVerification();
      } catch (_) {}
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Registration failed';
      return false;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not save user profile';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Updates the signed-in user's profile picture and rich marketplace bio details.
  Future<bool> updateProfile({
    required String name,
    String bio = '',
    String department = '',
    String phone = '',
    String location = '',
    String batchYear = '',
    String meetupSpot = '',
    String photoRaw = '',
    bool removePhoto = false,
    String previousPhone = '',
    String recoveryGmail = '',
    ProfileDirectoryProvider? directory,
  }) async {
    final current = _auth.currentUser;
    if (current == null) {
      error = 'You must be signed in to update your profile';
      notifyListeners();
      return false;
    }
    if (name.trim().length < 2) {
      error = 'Full name must be at least 2 characters';
      notifyListeners();
      return false;
    }

    final normPhone =
        phone.trim().isEmpty ? '' : AppFormatters.normalizePhone(phone);
    if (phone.trim().isNotEmpty && !AppFormatters.isValidPhone(phone)) {
      error = 'Enter a valid phone number (e.g. 017XXXXXXXX)';
      notifyListeners();
      return false;
    }

    final cleanRecovery = recoveryGmail.trim().toLowerCase();
    if (cleanRecovery.isNotEmpty && !AppFormatters.isValidGmail(cleanRecovery)) {
      error = 'Recovery / Account Gmail must be a valid @gmail.com address';
      notifyListeners();
      return false;
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final oldNorm = AppFormatters.normalizePhone(previousPhone);
      if (normPhone.isNotEmpty && normPhone != oldNorm) {
        final clash =
            await _db.collection('phone_directory').doc(normPhone).get();
        if (clash.exists && clash.data()?['uid'] != current.uid) {
          error = 'This phone number is already registered by another member.';
          return false;
        }
      }

      final userRef = _db.collection('users').doc(current.uid);
      final existingSnap = await userRef.get();
      final existing = existingSnap.data() ?? <String, dynamic>{};

      String nextPhoto = (existing['photoUrl'] as String?) ?? '';
      if (removePhoto) {
        nextPhoto = '';
      } else if (photoRaw.trim().isNotEmpty) {
        nextPhoto = await _uploadAvatarIfNeeded(current.uid, photoRaw);
      }

      await current.updateDisplayName(name.trim());
      if (removePhoto) {
        await current.updatePhotoURL(null);
      } else if (nextPhoto.startsWith('http') && nextPhoto.length < 1800) {
        await current.updatePhotoURL(nextPhoto);
      }

      final phoneChanged = normPhone != oldNorm;
      final effectiveRecovery = cleanRecovery.isNotEmpty
          ? cleanRecovery
          : (existing['recoveryEmail'] as String?) ??
              (current.email ?? '');

      final updateMap = <String, dynamic>{
        'name': name.trim(),
        'bio': bio.trim(),
        'department': department.trim(),
        'phone': normPhone,
        'phoneVerified':
            phoneChanged ? false : (existing['phoneVerified'] == true),
        'location': location.trim(),
        'batchYear': batchYear.trim(),
        'meetupSpot': meetupSpot.trim(),
        'photoUrl': nextPhoto,
        if (effectiveRecovery.isNotEmpty) 'recoveryEmail': effectiveRecovery,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await userRef.set(updateMap, SetOptions(merge: true));

      if (oldNorm.isNotEmpty && oldNorm != normPhone) {
        try {
          final oldDoc =
              await _db.collection('phone_directory').doc(oldNorm).get();
          if (oldDoc.exists && oldDoc.data()?['uid'] == current.uid) {
            await oldDoc.reference.delete();
          }
        } catch (_) {}
      }

      final mergedData = {...existing, ...updateMap};
      await _syncPublicAndPhoneDirectory(
        uid: current.uid,
        userData: mergedData,
      );
      await _syncSellerListingsMetadata(
        uid: current.uid,
        name: name.trim(),
        photoUrl: nextPhoto,
      );

      directory?.upsertLocal(
        PublicUserProfile.fromMap(current.uid, mergedData),
      );
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not save profile updates';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Sends a verification link to update Firebase Auth's sign-in / Account Gmail.
  Future<bool> updateAccountGmail({
    required String newGmail,
    String currentPassword = '',
  }) async {
    final current = _auth.currentUser;
    if (current == null) return false;
    final clean = newGmail.trim().toLowerCase();
    if (!AppFormatters.isValidGmail(clean)) {
      error = 'Please enter a valid @gmail.com address';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (currentPassword.isNotEmpty && current.email != null) {
        final cred = EmailAuthProvider.credential(
          email: current.email!,
          password: currentPassword,
        );
        await current.reauthenticateWithCredential(cred);
      }
      await current.verifyBeforeUpdateEmail(clean);
      await _db.collection('users').doc(current.uid).set({
        'recoveryEmail': clean,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final snap = await _db.collection('users').doc(current.uid).get();
      if (snap.data() != null) {
        await _syncPublicAndPhoneDirectory(
          uid: current.uid,
          userData: snap.data()!,
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.code == 'requires-recent-login'
          ? 'Enter your current password to confirm updating your Account Gmail.'
          : (e.message ?? 'Could not update Gmail');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Verifies an existing admin account strictly against its Firestore `role: 'admin'` claim.
  Future<bool> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        error = 'Authentication failed';
        return false;
      }
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      final verifiedAdmin = data?['role'] == 'admin' || (data?['isAdmin'] == true);
      if (!verifiedAdmin) {
        await _auth.signOut();
        error = 'This account does not have Administrator privileges in Firestore.';
        return false;
      }
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Admin sign-in failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Deletes the user's account and listings via Cloud Functions after optional re-auth.
  Future<bool> deleteAccount({String? password}) async {
    final current = _auth.currentUser;
    if (current == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (password != null && password.isNotEmpty && current.email != null) {
        final cred = EmailAuthProvider.credential(
          email: current.email!,
          password: password,
        );
        await current.reauthenticateWithCredential(cred);
      }
      await _api.deleteAccount();
      guestMode = false;
      await _auth.signOut();
      return true;
    } on BackendApiException catch (e) {
      if (e.isEndpointUnavailable) {
        final uid = current.uid;
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
        await current.delete();
        guestMode = false;
        return true;
      }
      error = e.message;
      return false;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Re-authentication failed';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    guestMode = false;
    await _auth.signOut();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}

Future<({String name, String photoUrl})> _fetchMemberSnapshot(
  FirebaseFirestore db,
  String uid,
  String fallbackName,
) async {
  if (uid.trim().isEmpty) return (name: fallbackName, photoUrl: '');
  try {
    final pub = await db.collection('public_profiles').doc(uid).get();
    if (pub.exists && pub.data() != null) {
      final d = pub.data()!;
      return (
        name: (d['name'] as String?)?.trim().isNotEmpty == true
            ? (d['name'] as String).trim()
            : fallbackName,
        photoUrl: (d['photoUrl'] as String?) ?? '',
      );
    }
    final userDoc = await db.collection('users').doc(uid).get();
    final d = userDoc.data() ?? const <String, dynamic>{};
    return (
      name: (d['name'] as String?)?.trim().isNotEmpty == true
          ? (d['name'] as String).trim()
          : fallbackName,
      photoUrl: (d['photoUrl'] as String?) ?? '',
    );
  } catch (_) {
    return (name: fallbackName, photoUrl: '');
  }
}

class ListingProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listingSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favoriteSub;
  Timer? _searchDebounce;
  List<Listing> listings = [];
  List<Listing> _remoteMatches = [];
  Set<String> favoriteIds = {};
  bool loading = true;
  bool isFetchingMore = false;
  bool hasMore = true;
  int _currentLimit = 60;
  String? error;
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
  StreamSubscription<User?>? _authSub;

  int get currentLimit => _currentLimit;

  int get activeFilterCount {
    int count = 0;
    if (condition != 'All') count++;
    if (locationFilter != 'All Locations') count++;
    if (onlyNegotiable) count++;
    if (minPrice > 0) count++;
    if (maxPrice < 100000000) count++;
    return count;
  }

  ListingProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      favoriteIds = {};
      listings = [];
      _remoteMatches = [];
      loading = true;
      requiresAuthToBrowse = false;
      _currentLimit = 60;
      _startStreams();
    });
    _startStreams();
  }

  void _startStreams() {
    _listingSub?.cancel();
    _listingSub = _db
        .collection('listings')
        .where('status', whereIn: ['available', 'reserved'])
        .limit(_currentLimit)
        .snapshots()
        .listen(
          (snapshot) {
            listings = snapshot.docs.map(Listing.fromSnapshot).toList();
            hasMore = snapshot.docs.length >= _currentLimit;
            loading = false;
            isFetchingMore = false;
            requiresAuthToBrowse = false;
            error = null;
            notifyListeners();
          },
          onError: (e) {
            loading = false;
            isFetchingMore = false;
            if (e is FirebaseException && e.code == 'permission-denied') {
              requiresAuthToBrowse = true;
              error = 'Sign in to browse live campus listings';
            } else {
              error = 'Could not load listings';
            }
            notifyListeners();
          },
        );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    _favoriteSub?.cancel();
    if (uid != null) {
      _favoriteSub = _db
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .snapshots()
          .listen((snapshot) {
            favoriteIds = snapshot.docs.map((d) => d.id).toSet();
            notifyListeners();
          }, onError: (_) {});
    }
  }

  Future<Listing?> fetchListingById(String listingId) async {
    if (listingId.trim().isEmpty) return null;
    for (final l in listings) {
      if (l.id == listingId) return l;
    }
    try {
      final doc = await _db.collection('listings').doc(listingId).get();
      if (!doc.exists) return null;
      return Listing.fromSnapshot(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> searchRemote(String term) async {
    final cleanToken = term
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .firstOrNull;
    if (cleanToken == null) {
      _remoteMatches = [];
      notifyListeners();
      return;
    }
    try {
      final snap = await _db
          .collection('listings')
          .where('status', whereIn: ['available', 'reserved'])
          .where('keywords', arrayContains: cleanToken)
          .limit(30)
          .get();
      _remoteMatches = snap.docs.map(Listing.fromSnapshot).toList();
      notifyListeners();
    } catch (_) {}
  }

  void loadMore() {
    if (isFetchingMore || !hasMore) return;
    isFetchingMore = true;
    _currentLimit += 60;
    notifyListeners();
    _startStreams();
  }

  Future<void> refresh() async {
    _currentLimit = 60;
    _remoteMatches = [];
    loading = true;
    notifyListeners();
    _startStreams();
  }

  List<Listing> get filtered {
    final mergedById = <String, Listing>{
      for (final item in listings) item.id: item,
      for (final item in _remoteMatches) item.id: item,
    };
    final pool = mergedById.values.toList();

    final q = query.trim().toLowerCase();
    var result = pool.where((listing) {
      final matchesQuery =
          q.isEmpty ||
          listing.title.toLowerCase().contains(q) ||
          listing.description.toLowerCase().contains(q) ||
          listing.location.toLowerCase().contains(q);
      final matchesCategory = category == 'All' || listing.category == category;
      final matchesCondition =
          condition == 'All' || listing.condition == condition;
      final matchesLocation =
          locationFilter == 'All Locations' || listing.location == locationFilter;
      final matchesPrice =
          listing.price >= minPrice && listing.price <= maxPrice;
      final matchesAvailable = !onlyAvailable || listing.isAvailable;
      final matchesFavorites = !onlyFavorites || favoriteIds.contains(listing.id);
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
        return bc.compareTo(ac);
      });
    }
    return result;
  }

  List<Listing> get favoriteListings {
    return listings.where((l) => favoriteIds.contains(l.id)).toList();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
    _searchDebounce?.cancel();
    if (value.trim().length >= 3) {
      _searchDebounce = Timer(
        const Duration(milliseconds: 350),
        () => searchRemote(value),
      );
    } else {
      _remoteMatches = [];
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

  Future<bool> toggleFavorite(Listing listing) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(listing.id);
    if (favoriteIds.contains(listing.id)) {
      favoriteIds.remove(listing.id);
      notifyListeners();
      await ref.delete();
    } else {
      favoriteIds.add(listing.id);
      notifyListeners();
      await ref.set({
        'listingTitle': listing.title,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
    return true;
  }

  Stream<List<ListingComment>> commentsStream(String listingId) {
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

  Future<bool> addComment({
    required Listing listing,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final clean = text.trim();
    if (user == null || clean.isEmpty) return false;
    try {
      final meta = await _fetchMemberSnapshot(
        _db,
        user.uid,
        user.displayName ?? 'Campus Member',
      );
      await _db
          .collection('listings')
          .doc(listing.id)
          .collection('comments')
          .add({
        'listingId': listing.id,
        'authorId': user.uid,
        'authorName': meta.name,
        'authorPhotoUrl': meta.photoUrl,
        'isSeller': user.uid == listing.sellerId,
        'text': clean,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not post comment';
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteComment(String listingId, String commentId) async {
    await _db
        .collection('listings')
        .doc(listingId)
        .collection('comments')
        .doc(commentId)
        .delete();
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

class SellProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _api = BackendApi();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Listing> myListings = [];
  bool loading = true;
  bool busy = false;
  String? error;
  StreamSubscription<User?>? _authSub;

  SellProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      myListings = [];
      loading = true;
      _sub?.cancel();
      _startStream();
    });
    _startStream();
  }

  void _startStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sub = _db
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            myListings = snapshot.docs.map(Listing.fromSnapshot).toList();
            loading = false;
            notifyListeners();
          },
          onError: (_) {
            loading = false;
            error = 'Could not load your listings';
            notifyListeners();
          },
        );
  }

  Future<List<String>> _prepareListingImages({
    required List<String> images,
    required String imageUrl,
    required String category,
  }) async {
    final rawList = images.where((e) => e.trim().isNotEmpty).toList();
    if (rawList.isEmpty && imageUrl.trim().isNotEmpty) {
      rawList.add(imageUrl.trim());
    }
    if (rawList.isEmpty) {
      return [PresetCatalog.defaultForCategory(category)];
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return rawList;

    final token = await user.getIdToken();
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket ??
        'pass-it-on-2f422.firebasestorage.app';
    final uploader = StorageUploader(bucket: bucket);
    final uploaded = await uploader.uploadListingImages(
      images: rawList,
      uid: user.uid,
      idToken: token,
    );
    return uploaded.isNotEmpty
        ? uploaded
        : [PresetCatalog.defaultForCategory(category)];
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
    String paymentId = '',
  }) async {
    if (title.trim().isEmpty || description.trim().isEmpty || price <= 0) {
      error = 'Enter a title, description, and a positive price';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final resolvedImages = await _prepareListingImages(
        images: images,
        imageUrl: imageUrl,
        category: category,
      );

      try {
        await _api.publishListing(
          title: title.trim(),
          description: description.trim(),
          category: category,
          condition: condition,
          location: location,
          price: price,
          negotiable: negotiable,
          images: resolvedImages,
          paymentId: paymentId,
        );
        return true;
      } on BackendApiException catch (e) {
        if (!e.isEndpointUnavailable) {
          error = e.message;
          return false;
        }
        // Spark-plan fallback when Cloud Functions are not deployed yet.
        final user = FirebaseAuth.instance.currentUser!;
        final meta = await _fetchMemberSnapshot(
          _db,
          user.uid,
          user.displayName ?? 'Unknown user',
        );
        final keywords = title
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();

        await _db.collection('listings').add({
          'title': title.trim(),
          'keywords': keywords,
          'description': description.trim(),
          'category': category,
          'condition': condition,
          'location':
              location.trim().isEmpty ? 'Campus Dorm / Hall' : location.trim(),
          'price': price,
          'negotiable': negotiable,
          'imageUrl': resolvedImages.first,
          'images': resolvedImages,
          'sellerId': user.uid,
          'sellerName': meta.name,
          'sellerPhotoUrl': meta.photoUrl,
          'status': 'available',
          'reservedFor': '',
          'statsCounted': false,
          'feePaid': feePaid,
          'feeTransactionId': feeTransactionId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not create listing';
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
    if (title.trim().isEmpty || description.trim().isEmpty || price <= 0) {
      error = 'Enter a valid title, description, and positive price';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final resolvedImages = await _prepareListingImages(
        images: images,
        imageUrl: imageUrl,
        category: category,
      );
      final keywords = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();

      await _db.collection('listings').doc(listingId).update({
        'title': title.trim(),
        'keywords': keywords,
        'description': description.trim(),
        'category': category,
        'condition': condition,
        'location':
            location.trim().isEmpty ? 'Campus Dorm / Hall' : location.trim(),
        'price': price,
        'negotiable': negotiable,
        'imageUrl': resolvedImages.first,
        'images': resolvedImages,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not update listing';
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
    busy = true;
    error = null;
    notifyListeners();
    try {
      final buyerId = reservedFor.isNotEmpty ? reservedFor : listing.reservedFor;
      await _db.collection('listings').doc(listing.id).update({
        'status': status,
        'reservedFor': status == 'available' ? '' : buyerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not update listing';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteListing(Listing listing) async {
    await _db.collection('listings').doc(listing.id).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class OfferProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _api = BackendApi();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _madeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _receivedSub;
  List<MarketOffer> made = [];
  List<MarketOffer> received = [];
  final Set<String> _readNotificationIds = {};
  final Map<String, String> _buyerPinCache = {};
  bool busy = false;
  String? error;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _prefSub;

  OfferProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      made = [];
      received = [];
      _readNotificationIds.clear();
      _buyerPinCache.clear();
      _madeSub?.cancel();
      _receivedSub?.cancel();
      _prefSub?.cancel();
      _startStreams();
    });
    _startStreams();
  }

  String pinForOffer(MarketOffer offer) {
    return _buyerPinCache[offer.id] ?? offer.handoverCode;
  }

  Future<void> fetchBuyerHandoverPin(String offerId) async {
    if (_buyerPinCache.containsKey(offerId)) return;
    try {
      final snap = await _db
          .collection('offers')
          .doc(offerId)
          .collection('private')
          .doc('pin')
          .get();
      final code = snap.data()?['code'] as String?;
      if (code != null && code.isNotEmpty) {
        _buyerPinCache[offerId] = code;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _startStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _prefSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      final saved = snap.data()?['readNotifications'];
      if (saved is List) {
        _readNotificationIds
          ..clear()
          ..addAll(saved.map((e) => e.toString()));
        notifyListeners();
      }
    }, onError: (_) {});

    _madeSub = _db
        .collection('offers')
        .where('buyerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (s) {
            made = s.docs.map(MarketOffer.fromSnapshot).toList()
              ..sort(_offerSort);
            for (final o in made) {
              if (o.status == 'accepted' && (o.hasPin || o.handoverCode.isEmpty)) {
                fetchBuyerHandoverPin(o.id);
              }
            }
            notifyListeners();
          },
          onError: (e) {
            error = _streamError(e);
            notifyListeners();
          },
        );
    _receivedSub = _db
        .collection('offers')
        .where('sellerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (s) {
            received = s.docs.map(MarketOffer.fromSnapshot).toList()
              ..sort(_offerSort);
            notifyListeners();
          },
          onError: (e) {
            error = _streamError(e);
            notifyListeners();
          },
        );
  }

  String _streamError(Object error) {
    if (error is FirebaseException) {
      return 'Could not load offers: ${_firebaseErrorMessage(error)}';
    }
    return 'Could not load offers';
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return list;

    for (final offer in received) {
      if (offer.status == 'pending') {
        final id = 'pending_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'New Offer Received',
          body: '${offer.buyerName} offered ${offer.amount} ৳ on "${offer.listingTitle}".',
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
          body: 'You accepted ${offer.buyerName}\'s offer of ${offer.amount} ৳ for "${offer.listingTitle}".',
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
      if (offer.status == 'countered') {
        final id = 'buyer_counter_${offer.id}';
        list.add(AppNotification(
          id: id,
          title: 'Seller Countered Your Offer',
          body: 'New counter price: ${offer.amount} ৳ on "${offer.listingTitle}". Tap to accept or negotiate.',
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
          title: 'Offer Accepted! 🎉',
          body: 'Great news! Your offer of ${offer.amount} ৳ on "${offer.listingTitle}" was accepted.',
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
          body: 'Your offer of ${offer.amount} ৳ on "${offer.listingTitle}" was declined.',
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

  Future<void> _persistReadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'readNotifications': _readNotificationIds.toList(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void markNotificationRead(String id) {
    _readNotificationIds.add(id);
    notifyListeners();
    _persistReadNotifications();
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      _readNotificationIds.add(n.id);
    }
    notifyListeners();
    _persistReadNotifications();
  }

  Future<String?> verifyOfferEligibility(Listing listing) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'You must be signed in to make an offer';
    if (listing.sellerId == user.uid) {
      return 'You cannot make an offer on your own listing';
    }
    try {
      final listingSnap = await _db.collection('listings').doc(listing.id).get();
      if (!listingSnap.exists) return 'This listing no longer exists';
      final live = listingSnap.data()!;
      if (live['status'] == 'sold') return 'This listing has already been sold';
      if (live['status'] != 'available') return 'This item is currently reserved';
      final offerSnap = await _db.collection('offers').doc('${listing.id}_${user.uid}').get();
      final existing = offerSnap.data();
      if (existing != null) {
        final s = existing['status'];
        if (s == 'accepted' || s == 'completed') {
          return 'You already have an active accepted deal on this listing.';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> makeOffer(
    Listing listing,
    int amount,
    String message, {
    bool feePaid = false,
    String feeTransactionId = '',
    String paymentId = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      error = 'You must be signed in to make an offer';
      notifyListeners();
      return false;
    }
    if (listing.sellerId == user.uid) {
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
      try {
        await _api.submitOffer(
          listingId: listing.id,
          amount: amount,
          message: message.trim(),
          paymentId: paymentId,
        );
        return true;
      } on BackendApiException catch (e) {
        if (!e.isEndpointUnavailable) {
          error = e.message;
          return false;
        }
        // Spark-plan fallback when Cloud Functions are not deployed yet.
        final uid = user.uid;
        final buyerMeta = await _fetchMemberSnapshot(
          _db,
          uid,
          user.displayName ?? 'Buyer',
        );
        final sellerMeta = await _fetchMemberSnapshot(
          _db,
          listing.sellerId,
          listing.sellerName,
        );
        final offerRef = _db.collection('offers').doc('${listing.id}_$uid');
        final existing = (await offerRef.get()).data();
        final historyEntry = {
          'by': uid,
          'amount': amount,
          'at': Timestamp.now(),
        };
        final isReopening = existing == null ||
            existing['status'] == 'declined' ||
            existing['status'] == 'withdrawn';
        await offerRef.set({
          'listingId': listing.id,
          'listingTitle': listing.title,
          'sellerId': listing.sellerId,
          'sellerName': sellerMeta.name,
          'sellerPhotoUrl': sellerMeta.photoUrl.isNotEmpty
              ? sellerMeta.photoUrl
              : listing.sellerPhotoUrl,
          'buyerId': uid,
          'buyerName': buyerMeta.name,
          'buyerPhotoUrl': buyerMeta.photoUrl,
          'amount': amount,
          'lastUpdatedBy': uid,
          'history': existing == null
              ? [historyEntry]
              : FieldValue.arrayUnion([historyEntry]),
          'message': message.trim(),
          'status': 'pending',
          'isRated': false,
          'feePaid': feePaid ||
              (existing?['feePaid'] == true && existing?['status'] == 'pending'),
          'feeTransactionId': feeTransactionId.isNotEmpty
              ? feeTransactionId
              : (existing?['feeTransactionId'] ?? ''),
          'createdAt': isReopening
              ? FieldValue.serverTimestamp()
              : (existing['createdAt'] ?? FieldValue.serverTimestamp()),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      }
    } on FirebaseException catch (e) {
      error = _firebaseErrorMessage(e);
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
    if (offer.isExpired &&
        (action == 'accept' ||
            action == 'counter' ||
            action == 'acceptCounter')) {
      error = 'This offer has expired';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      try {
        await _api.transitionOffer(
          offerId: offer.id,
          action: action,
          handoverPin: handoverPin ?? '',
        );
        return true;
      } on BackendApiException catch (e) {
        if (!e.isEndpointUnavailable) {
          error = e.message;
          return false;
        }
        // Spark-plan fallback transaction when Cloud Functions aren't deployed yet.
        String? acceptedListingId;
        String? acceptedOfferSellerId;
        String? refundTxnId;

        await _db.runTransaction((transaction) async {
          final offerRef = _db.collection('offers').doc(offer.id);
          final offerSnap = await transaction.get(offerRef);
          if (!offerSnap.exists) throw Exception('Offer no longer exists');
          final current = offerSnap.data()!;
          final listingRef = _db.collection('listings').doc(current['listingId']);
          final listingSnap = await transaction.get(listingRef);
          if (!listingSnap.exists) throw Exception('Listing no longer exists');
          final liveListing = listingSnap.data()!;

          if (action == 'accept' || action == 'acceptCounter') {
            if (liveListing['status'] != 'available') {
              throw Exception('This listing has already been reserved or sold');
            }
            final code = (1000 + math.Random().nextInt(9000)).toString();
            transaction.update(offerRef, {
              'status': 'accepted',
              'handoverCode': code,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.update(listingRef, {
              'status': 'reserved',
              'reservedFor': current['buyerId'],
              'updatedAt': FieldValue.serverTimestamp(),
            });
            acceptedListingId = current['listingId'] as String?;
            acceptedOfferSellerId = current['sellerId'] as String?;
          } else if (action == 'complete') {
            if (current['status'] != 'accepted') {
              throw Exception('Only accepted deals can be finalized');
            }
            final expected = (current['handoverCode'] as String?) ?? '';
            if (expected.isNotEmpty &&
                (handoverPin ?? '').trim() != expected) {
              throw Exception('Invalid 4-digit handover PIN from buyer');
            }
            final alreadyCounted = liveListing['statsCounted'] == true;
            transaction.update(offerRef, {
              'status': 'completed',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.update(listingRef, {
              'status': 'sold',
              'statsCounted': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (!alreadyCounted) {
              transaction.set(
                _db.collection('users').doc(current['sellerId']),
                {'soldCount': FieldValue.increment(1)},
                SetOptions(merge: true),
              );
              transaction.set(
                _db.collection('users').doc(current['buyerId']),
                {'boughtCount': FieldValue.increment(1)},
                SetOptions(merge: true),
              );
            }
          } else if (action == 'decline' || action == 'withdraw') {
            final status = action == 'withdraw' ? 'withdrawn' : 'declined';
            transaction.update(offerRef, {
              'status': status,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (current['status'] == 'accepted' &&
                liveListing['status'] == 'reserved') {
              transaction.update(listingRef, {
                'status': 'available',
                'reservedFor': '',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
            final txn = current['feeTransactionId'] as String? ?? '';
            if (current['feePaid'] == true && txn.isNotEmpty) {
              refundTxnId = txn;
            }
          }
        });

        if (acceptedListingId != null && acceptedOfferSellerId != null) {
          try {
            final others = await _db
                .collection('offers')
                .where('listingId', isEqualTo: acceptedListingId)
                .where('sellerId', isEqualTo: acceptedOfferSellerId)
                .where('status', whereIn: ['pending', 'countered'])
                .get();
            for (final doc in others.docs) {
              if (doc.id != offer.id) {
                await doc.reference.update({
                  'status': 'declined',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                final d = doc.data();
                final otherTxn = d['feeTransactionId'] as String? ?? '';
                if (d['feePaid'] == true && otherTxn.isNotEmpty) {
                  await _refundTxn(otherTxn);
                }
              }
            }
          } catch (_) {}
        }

        if (refundTxnId != null) {
          await _refundTxn(refundTxnId!);
        }
        return true;
      }
    } on FirebaseException catch (e) {
      error = _firebaseErrorMessage(e);
      return false;
    } on Exception catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _refundTxn(String txnId) async {
    try {
      final snap = await _db
          .collection('payments')
          .where('transactionId', isEqualTo: txnId)
          .limit(3)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'status': 'refunded'});
      }
    } catch (_) {}
  }

  Future<bool> counterOffer(MarketOffer offer, int amount) async {
    if (amount <= 0) {
      error = 'Counter offer must be greater than zero';
      notifyListeners();
      return false;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      try {
        await _api.transitionOffer(
          offerId: offer.id,
          action: 'counter',
          counterAmount: amount,
        );
        return true;
      } on BackendApiException catch (e) {
        if (!e.isEndpointUnavailable) {
          error = e.message;
          return false;
        }
        await _db.collection('offers').doc(offer.id).update({
          'amount': amount,
          'status': 'countered',
          'lastUpdatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'history': FieldValue.arrayUnion([
            {'by': uid, 'amount': amount, 'at': Timestamp.now()},
          ]),
        });
        return true;
      }
    } on FirebaseException catch (e) {
      error = _firebaseErrorMessage(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _firebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Ensure Firestore rules & Cloud Functions are deployed.';
      case 'unauthenticated':
        return 'You must be signed in to perform this action.';
      default:
        return e.message ?? 'Firebase error (${e.code})';
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

class RatingProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _api = BackendApi();
  bool busy = false;
  String? error;

  Future<bool> rateSale({
    required String listingId,
    required String sellerId,
    required int stars,
    String comment = '',
    String? offerId,
  }) async {
    if (stars < 1 || stars > 5) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _api.submitRating(
        listingId: listingId,
        sellerId: sellerId,
        stars: stars,
        comment: comment.trim(),
        offerId: offerId ?? '',
      );
      return true;
    } on BackendApiException catch (e) {
      if (e.isEndpointUnavailable) {
        try {
          final user = FirebaseAuth.instance.currentUser!;
          final buyerId = user.uid;
          final buyerMeta = await _fetchMemberSnapshot(
            _db,
            buyerId,
            user.displayName ?? 'Verified Buyer',
          );
          await _db.runTransaction((transaction) async {
            final ratingRef = _db.collection('ratings').doc(listingId);
            final ratingSnap = await transaction.get(ratingRef);
            if (ratingSnap.exists) {
              throw Exception('This sale has already been rated');
            }
            final sellerRef = _db.collection('users').doc(sellerId);
            final sellerSnap = await transaction.get(sellerRef);
            final seller = sellerSnap.data() ?? {};
            transaction.set(ratingRef, {
              'sellerId': sellerId,
              'buyerId': buyerId,
              'buyerName': buyerMeta.name,
              'buyerPhotoUrl': buyerMeta.photoUrl,
              'stars': stars,
              'comment': comment.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
            transaction.set(sellerRef, {
              'ratingSum': ((seller['ratingSum'] as num?)?.toInt() ?? 0) + stars,
              'ratingCount': ((seller['ratingCount'] as num?)?.toInt() ?? 0) + 1,
            }, SetOptions(merge: true));
            if (offerId != null && offerId.isNotEmpty) {
              transaction.update(_db.collection('offers').doc(offerId), {
                'isRated': true,
              });
            }
          });
          return true;
        } on Exception catch (inner) {
          error = inner.toString().replaceFirst('Exception: ', '');
          return false;
        }
      }
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchSellerPublicData(String sellerId) async {
    Map<String, dynamic> profileData = {};
    try {
      final pubSnap = await _db.collection('public_profiles').doc(sellerId).get();
      if (pubSnap.exists && pubSnap.data() != null) {
        profileData = pubSnap.data()!;
      } else {
        // Fallback only works when permitted (e.g. own profile / legacy dev rule)
        final legacySnap = await _db.collection('users').doc(sellerId).get();
        profileData = legacySnap.data() ?? <String, dynamic>{};
      }
    } catch (_) {}

    final reviewsSnap = await _db
        .collection('ratings')
        .where('sellerId', isEqualTo: sellerId)
        .limit(20)
        .get();
    final listingsSnap = await _db
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'available')
        .limit(12)
        .get();

    final reviews = reviewsSnap.docs.map(SellerReview.fromSnapshot).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return {
      'profile': profileData,
      'reviews': reviews,
      'listings': listingsSnap.docs.map(Listing.fromSnapshot).toList(),
    };
  }
}

class ReportProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  bool busy = false;
  String? error;

  Future<bool> submitReport({
    required String targetType,
    required String targetId,
    required String targetTitle,
    String targetUserId = '',
    required String reason,
    String details = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      error = 'Please sign in to submit a report';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _db.collection('reports').add({
        'targetType': targetType,
        'targetId': targetId,
        'targetTitle': targetTitle,
        'targetUserId': targetUserId,
        'reporterId': user.uid,
        'reporterName': user.displayName ?? 'Member',
        'reason': reason,
        'details': details.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not submit report';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class ChatProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _threadSub;
  List<ChatThread> threads = [];
  bool sending = false;
  String? error;

  ChatProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      threads = [];
      _threadSub?.cancel();
      _startStream();
    });
    _startStream();
  }

  void _startStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      notifyListeners();
      return;
    }
    _threadSub = _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snap) {
      threads = snap.docs.map(ChatThread.fromSnapshot).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    }, onError: (_) {});
  }

  String threadIdFor(String listingId, String buyerId) => '${listingId}_$buyerId';

  Stream<List<ChatMessage>> messagesStream(String threadId) {
    return _db
        .collection('chats')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(ChatMessage.fromSnapshot).toList());
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
    final user = FirebaseAuth.instance.currentUser;
    final clean = text.trim();
    if (user == null || clean.isEmpty) return false;
    sending = true;
    error = null;
    notifyListeners();
    try {
      final buyerMeta = await _fetchMemberSnapshot(_db, buyerId, buyerName);
      final sellerMeta = await _fetchMemberSnapshot(_db, sellerId, sellerName);
      final senderMeta = user.uid == buyerId ? buyerMeta : sellerMeta;

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
        'lastMessage': clean,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await threadRef.collection('messages').add({
        'senderId': user.uid,
        'senderName': senderMeta.name,
        'senderPhotoUrl': senderMeta.photoUrl,
        'text': clean,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      error = e.message ?? 'Could not send message (${e.code})';
      return false;
    } catch (e) {
      error = e.toString();
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
  final _db = FirebaseFirestore.instance;
  final _api = BackendApi();
  PlatformFeeSettings feeSettings = const PlatformFeeSettings();
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _feeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metricsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userRoleSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listingsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSub;

  AdminProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _cancelStreams();
      _initStreams();
    });
    _initStreams();
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
    final user = FirebaseAuth.instance.currentUser;
    _feeSub = _db
        .collection('platform_settings')
        .doc('fees')
        .snapshots()
        .listen((snap) {
      if (snap.exists && snap.data() != null) {
        feeSettings = PlatformFeeSettings.fromMap(snap.data());
      } else {
        feeSettings = const PlatformFeeSettings(
          sellerListingFee: 20,
          buyerOrderFee: 50,
          feesEnabled: true,
        );
      }
      notifyListeners();
    }, onError: (_) {});

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

    _userRoleSub = _db.collection('users').doc(user.uid).snapshots().listen((snap) {
      final data = snap.data();
      isCurrentUserAdmin =
          data?['role'] == 'admin' || (data?['isAdmin'] as bool? ?? false);
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
    _paySub?.cancel();
    _paySub = _db
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      payments = snap.docs.map(PlatformPaymentRecord.fromSnapshot).toList();
      loading = false;
      notifyListeners();
    }, onError: (_) {
      loading = false;
      notifyListeners();
    });

    _metricsSub?.cancel();
    _metricsSub = _db
        .collection('platform_metrics')
        .doc('global')
        .snapshots()
        .listen((snap) {
      globalMetrics = PlatformMetrics.fromMap(snap.data());
      notifyListeners();
    }, onError: (_) {});

    _listingsSub?.cancel();
    _listingsSub = _db.collection('listings').limit(100).snapshots().listen((snap) {
      allListings = snap.docs.map(Listing.fromSnapshot).toList();
      notifyListeners();
    }, onError: (_) {});

    _offersSub?.cancel();
    _offersSub = _db.collection('offers').limit(100).snapshots().listen((snap) {
      allOffers = snap.docs.map(MarketOffer.fromSnapshot).toList();
      notifyListeners();
    }, onError: (_) {});

    _usersSub?.cancel();
    _usersSub = _db.collection('users').limit(100).snapshots().listen((snap) {
      allUsers = snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
      notifyListeners();
    }, onError: (_) {});

    _reportsSub?.cancel();
    _reportsSub = _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      reports = snap.docs.map(ReportRecord.fromSnapshot).toList();
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
    busy = true;
    error = null;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      final newSettings = PlatformFeeSettings(
        sellerListingFee: sellerListingFee,
        buyerOrderFee: buyerOrderFee,
        feesEnabled: feesEnabled,
        updatedAt: DateTime.now(),
        updatedBy: user?.displayName ?? user?.email ?? 'Admin',
      );
      await _db
          .collection('platform_settings')
          .doc('fees')
          .set(newSettings.toMap(), SetOptions(merge: true));
      feeSettings = newSettings;
      return true;
    } on Exception catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Calls Cloud Functions `/payments/initiate` so payments can never be forged client-side.
  Future<PaymentInitResult?> initiateServerPayment({
    required String type,
    required String method,
    required String referenceId,
    required String referenceTitle,
    String phone = '',
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.initiatePayment(
        type: type,
        method: method,
        referenceId: referenceId,
        referenceTitle: referenceTitle,
        phone: phone,
      );
      final mode = (res['mode'] as String?) ?? 'sandbox_completed';
      if (mode == 'redirect') {
        return PaymentInitResult(
          mode: 'redirect',
          gatewayUrl: res['gatewayUrl'] as String?,
          transactionId: res['transactionId'] as String?,
        );
      }
      final payJson = (res['payment'] as Map<String, dynamic>?) ?? {};
      final record = PlatformPaymentRecord(
        id: (payJson['id'] as String?) ?? '',
        userId: (payJson['userId'] as String?) ?? '',
        userName: (payJson['userName'] as String?) ?? 'Campus Trader',
        userEmail: (payJson['userEmail'] as String?) ?? '',
        type: type,
        amount: (payJson['amount'] as num?)?.toInt() ?? 0,
        currency: 'BDT',
        method: method,
        transactionId: (payJson['transactionId'] as String?) ?? '',
        referenceId: referenceId,
        referenceTitle: referenceTitle,
        status: 'completed',
        createdAt: DateTime.now(),
      );
      return PaymentInitResult(mode: mode, payment: record);
    } on BackendApiException catch (e) {
      if (e.isEndpointUnavailable) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          final uid = user?.uid ?? 'anonymous_user';
          final name = user?.displayName ?? 'Campus Trader';
          final email = user?.email ?? '';
          final requiredAmt = !feeSettings.feesEnabled
              ? 0
              : (type == 'seller_listing_fee'
                  ? feeSettings.sellerListingFee
                  : feeSettings.buyerOrderFee);
          final txnId =
              'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
          final docRef = await _db.collection('payments').add({
            'userId': uid,
            'userName': name,
            'userEmail': email,
            'type': type,
            'amount': requiredAmt,
            'currency': 'BDT',
            'method': method,
            'transactionId': txnId,
            'referenceId': referenceId,
            'referenceTitle': referenceTitle,
            'status': 'completed',
            'gatewayMode': 'spark_sandbox',
            'createdAt': FieldValue.serverTimestamp(),
          });
          final record = PlatformPaymentRecord(
            id: docRef.id,
            userId: uid,
            userName: name,
            userEmail: email,
            type: type,
            amount: requiredAmt,
            currency: 'BDT',
            method: method,
            transactionId: txnId,
            referenceId: referenceId,
            referenceTitle: referenceTitle,
            status: 'completed',
            createdAt: DateTime.now(),
          );
          return PaymentInitResult(mode: 'sandbox_completed', payment: record);
        } on Exception catch (inner) {
          error = inner.toString().replaceFirst('Exception: ', '');
          return null;
        }
      }
      error = e.message;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteListingAsAdmin(String listingId) async {
    try {
      await _db.collection('listings').doc(listingId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateListingStatusAsAdmin(String listingId, String status) async {
    try {
      await _db.collection('listings').doc(listingId).update({
        'status': status,
        if (status == 'available') 'reservedFor': '',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateOfferStatusAsAdmin(MarketOffer offer, String status) async {
    try {
      await _db.runTransaction((tx) async {
        final offerRef = _db.collection('offers').doc(offer.id);
        final listingRef = _db.collection('listings').doc(offer.listingId);
        tx.update(offerRef, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (status == 'completed') {
          tx.update(listingRef, {'status': 'sold'});
          tx.set(_db.collection('users').doc(offer.sellerId), {
            'soldCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
          tx.set(_db.collection('users').doc(offer.buyerId), {
            'boughtCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        } else if (status == 'declined') {
          tx.update(listingRef, {'status': 'available', 'reservedFor': ''});
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refundPaymentRecord(String paymentId) async {
    try {
      await _api.refundPayment(paymentId);
      return true;
    } on BackendApiException catch (e) {
      if (e.isEndpointUnavailable) {
        try {
          await _db.collection('payments').doc(paymentId).update({
            'status': 'refunded',
          });
          return true;
        } catch (_) {}
      }
      error = e.message;
      return false;
    }
  }

  Future<bool> toggleUserRoleAsAdmin(String uid, bool makeAdmin) async {
    try {
      await _db.collection('users').doc(uid).set({
        'role': makeAdmin ? 'admin' : 'customer',
        'isAdmin': makeAdmin,
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> banUserAsAdmin(String uid, bool banned) async {
    try {
      await _api.banUser(targetUid: uid, banned: banned);
      return true;
    } on BackendApiException catch (e) {
      if (e.isEndpointUnavailable) {
        // Firestore flag fallback disables writes immediately under firestore.rules.
        await _db.collection('users').doc(uid).set({
          'isBanned': banned,
        }, SetOptions(merge: true));
        return true;
      }
      error = e.message;
      return false;
    }
  }

  Future<bool> resolveReport(String reportId, String status) async {
    try {
      await _db.collection('reports').doc(reportId).update({
        'status': status,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
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
