import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../domain/marketplace_logic.dart';
import '../models.dart';
import '../repositories/auth_repository.dart';
import '../utils/formatters.dart';
import 'theme_and_directory_provider.dart';

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

class AuthProvider extends ChangeNotifier {
  final FirestoreAuthRepository? _repo;
  bool busy = false;
  bool initializing = false;
  String? error;
  bool guestMode = false;
  User? _currentUser;
  UserAccountSnapshot? _currentAccount;
  PhoneOtpSession? _otpSession;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserAccountSnapshot>? _accountSub;

  AuthProvider({
    FirestoreAuthRepository? repository,
    bool autoStart = true,
  }) : _repo = repository ?? _safeRepo() {
    if (autoStart) _bindStreams();
  }

  static FirestoreAuthRepository? _safeRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreAuthRepository();
    } catch (_) {
      return null;
    }
  }

  void _bindStreams() {
    final repo = _repo;
    if (repo == null) return;
    initializing = true;
    _currentUser = repo.currentUser;
    if (_currentUser != null) {
      _subscribeAccount(_currentUser!);
    }
    _authSub = repo.authStateChanges().listen((user) {
      initializing = false;
      _currentUser = user;
      _accountSub?.cancel();
      if (user == null) {
        _currentAccount = null;
        notifyListeners();
        return;
      }
      _subscribeAccount(user);
      unawaited(_backfillSignedInUser(user));
      notifyListeners();
    });
  }

  void _subscribeAccount(User user) {
    final repo = _repo;
    if (repo == null) return;
    _accountSub?.cancel();
    _accountSub = repo.watchUserAccount(user.uid).listen((snapshot) {
      _currentAccount = snapshot;
      initializing = false;
      notifyListeners();
    }, onError: (_) {
      initializing = false;
      notifyListeners();
    });
  }

  User? get user => _currentUser ?? _repo?.currentUser;
  String? get uid => user?.uid;
  String get displayName =>
      (_currentAccount?.data['name'] as String?) ??
      user?.displayName ??
      AppFormatters.unknownUserName;
  bool get isSignedIn => user != null;
  UserAccountSnapshot? get currentAccount => _currentAccount;
  bool get isCurrentUserBanned => _currentAccount?.isBanned ?? false;
  bool get isCurrentUserAdmin => _currentAccount?.isAdmin ?? false;
  Map<String, dynamic> get currentProfileData =>
      _currentAccount?.data ?? const <String, dynamic>{};

  Future<void> _backfillSignedInUser(User user) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final data = await repo.fetchUserDoc(user.uid);
      if (data == null || data['isBanned'] == true) return;
      await repo.syncPublicAndPhoneDirectory(uid: user.uid, userData: data);
      await repo.syncSellerListingsMetadata(
        uid: user.uid,
        name: (data['name'] as String?) ??
            user.displayName ??
            AppFormatters.unknownUserName,
        photoUrl: (data['photoUrl'] as String?) ?? '',
      );
    } catch (_) {}
  }

  void enterGuestMode() {
    guestMode = true;
    error = null;
    notifyListeners();
  }

  void exitGuestMode() {
    guestMode = false;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    final repo = _repo;
    if (repo == null) {
      error = 'Authentication service unavailable';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      var authEmail = identifier.trim();
      if (AppFormatters.looksLikePhone(authEmail)) {
        final normPhone = AppFormatters.normalizePhone(authEmail);
        final phoneData = await repo.lookupPhoneDirectory(normPhone);
        if (phoneData == null) {
          error =
              'No account found for phone $normPhone. Sign in with Gmail or create a new account.';
          return false;
        }
        final resolvedEmail =
            (phoneData['authEmail'] as String?)?.trim() ?? '';
        if (resolvedEmail.isEmpty) {
          error =
              'This phone account uses SMS OTP verification. Tap "SMS OTP Code" to sign in.';
          return false;
        }
        authEmail = resolvedEmail;
      }

      final cred = await repo.signInWithEmailAndPassword(authEmail, password);
      final uid = cred.user?.uid;
      if (uid != null) {
        final data = await repo.fetchUserDoc(uid);
        if (data?['isBanned'] == true) {
          await repo.signOut();
          error = 'This account has been suspended by marketplace moderation.';
          return false;
        }
        if (data != null) {
          unawaited(repo.syncPublicAndPhoneDirectory(uid: uid, userData: data));
        }
      }
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Login failed';
      return false;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not sign in');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<PasswordResetOutcome> sendPasswordResetByIdentifier(
    String identifier,
  ) async {
    final repo = _repo;
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) {
      error = 'Enter your Account Gmail or registered Phone Number';
      notifyListeners();
      return PasswordResetOutcome(ok: false, message: error!);
    }
    if (repo == null) {
      return const PasswordResetOutcome(
        ok: false,
        message: 'Authentication service unavailable',
      );
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
        final phoneData = await repo.lookupPhoneDirectory(normPhone);
        if (phoneData == null) {
          error =
              'No account is linked to $normPhone. Enter your Account Gmail or verify via SMS OTP.';
          return PasswordResetOutcome(ok: false, message: error!);
        }
        final resolved = (phoneData['authEmail'] as String?)?.trim() ?? '';
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

      await repo.sendPasswordResetEmail(targetEmail);
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
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Lookup failed');
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

  Future<bool> sendPhoneOtp(
    String rawPhone, {
    bool linkToCurrentUser = false,
  }) async {
    final repo = _repo;
    final normPhone = AppFormatters.normalizePhone(rawPhone);
    if (!AppFormatters.isValidPhone(normPhone)) {
      error = 'Enter a valid phone number (e.g. 017XXXXXXXX or +8801XXXXXXXXX)';
      notifyListeners();
      return false;
    }
    if (repo == null) return false;
    busy = true;
    error = null;
    _otpSession = null;
    notifyListeners();
    try {
      _otpSession = await repo.sendPhoneOtp(
        normPhone: normPhone,
        linkToCurrentUser: linkToCurrentUser,
      );
      return true;
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

  Future<bool> verifyPhoneOtp({
    required String smsCode,
    required String rawPhone,
    String name = '',
    String department = '',
    String hostel = '',
    String bio = '',
    String recoveryGmail = '',
    bool linkToCurrentUser = false,
  }) async {
    final repo = _repo;
    final code = smsCode.trim();
    if (code.length < 4) {
      error = 'Enter the 6-digit SMS code sent to your phone';
      notifyListeners();
      return false;
    }
    if (repo == null || _otpSession == null) {
      error = 'Send the SMS verification code first';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final cred = await repo.confirmPhoneOtp(
        session: _otpSession!,
        smsCode: code,
        linkToCurrentUser: linkToCurrentUser,
      );
      final current = cred.user ?? repo.currentUser;
      if (current == null) {
        error = 'Could not verify phone number';
        return false;
      }

      final normPhone = AppFormatters.normalizePhone(rawPhone);
      final existingData = await repo.fetchUserDoc(current.uid);
      if (existingData?['isBanned'] == true) {
        await repo.signOut();
        error = 'This account has been suspended by marketplace moderation.';
        return false;
      }

      final cleanGmail = recoveryGmail.trim();
      final existingMap = existingData ?? const <String, dynamic>{};
      final resolvedName = name.trim().isNotEmpty
          ? name.trim()
          : (existingMap['name'] as String?) ??
              current.displayName ??
              'PassItOn Member';
      if (name.trim().isNotEmpty) {
        await current.updateDisplayName(resolvedName);
      }

      final payload = <String, dynamic>{
        'name': resolvedName,
        'email': cleanGmail.isNotEmpty
            ? cleanGmail
            : (existingMap['email'] as String?) ?? current.email ?? '',
        if (cleanGmail.isNotEmpty) 'recoveryEmail': cleanGmail,
        'phone': normPhone,
        'phoneVerified': true,
        'department': department.trim().isNotEmpty
            ? department.trim()
            : (existingMap['department'] as String?) ?? '',
        'hostel': hostel.trim().isNotEmpty
            ? hostel.trim()
            : (existingMap['hostel'] as String?) ?? '',
        'bio': bio.trim().isNotEmpty
            ? bio.trim()
            : (existingMap['bio'] as String?) ?? '',
        if (existingData == null) ...{
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
      await repo.updateUserDoc(current.uid, payload);
      await repo.syncPublicAndPhoneDirectory(
        uid: current.uid,
        userData: {...existingMap, ...payload},
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
      return 'SMS OTP is not enabled on the Spark plan console yet. Register/recover using Phone + Account Gmail.';
    }
    return e.message ?? 'Phone verification failed (${e.code})';
  }

  Future<bool> sendEmailVerification() async {
    final current = user;
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
    final current = user;
    final repo = _repo;
    if (current == null || repo == null) return false;
    try {
      await current.reload();
      final verified = repo.currentUser?.emailVerified ?? false;
      await repo.syncPublicAndPhoneDirectory(
        uid: current.uid,
        userData: {...currentProfileData, 'emailVerified': verified},
      );
      notifyListeners();
      return verified;
    } catch (_) {
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String department = '',
    String hostel = '',
    String phone = '',
    String bio = '',
    String location = '',
    String batchYear = '',
    String meetupSpot = '',
    String photoRaw = '',
    String accountMode = 'gmail',
  }) async {
    final repo = _repo;
    if (repo == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final cleanEmail = email.trim().toLowerCase();
      final normPhone = AppFormatters.normalizePhone(phone);
      final cleanPhotoUrl = photoRaw.trim();

      final photoErr = AppFormatters.validateOptionalHttpsImageUrl(cleanPhotoUrl);
      if (photoErr != null) {
        error = photoErr;
        return false;
      }

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
              'Enter your Account Gmail (@gmail.com) so password recovery links can reach you.';
          return false;
        }
      }

      if (normPhone.isNotEmpty) {
        final existingPhone = await repo.lookupPhoneDirectory(normPhone);
        if (existingPhone != null) {
          error = 'This phone number is already linked to another account.';
          return false;
        }
      }

      final credential =
          await repo.createUserWithEmailAndPassword(cleanEmail, password);
      final createdUser = credential.user!;
      await createdUser.updateDisplayName(name.trim());
      if (cleanPhotoUrl.isNotEmpty && cleanPhotoUrl.length < 1800) {
        await createdUser.updatePhotoURL(cleanPhotoUrl);
      }

      final effectiveLocation = location.trim().isNotEmpty
          ? location.trim()
          : hostel.trim();

      final userData = <String, dynamic>{
        'name': name.trim(),
        'email': cleanEmail,
        'recoveryEmail': cleanEmail,
        'department': department.trim(),
        'hostel': hostel.trim(),
        'phone': normPhone,
        'phoneVerified': false,
        'bio': bio.trim(),
        'location': effectiveLocation,
        'batchYear': batchYear.trim(),
        'meetupSpot': meetupSpot.trim(),
        'photoUrl': cleanPhotoUrl,
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

      await repo.createUserDoc(createdUser.uid, userData);
      await repo.syncPublicAndPhoneDirectory(
        uid: createdUser.uid,
        userData: userData,
      );

      try {
        await createdUser.sendEmailVerification();
      } catch (_) {}
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Registration failed';
      return false;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not create account');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Updates the signed-in user's profile info and external HTTPS avatar URL.
  Future<bool> updateProfile({
    required String name,
    String bio = '',
    String department = '',
    String hostel = '',
    String phone = '',
    String location = '',
    String batchYear = '',
    String meetupSpot = '',
    String photoRaw = '',
    bool removePhoto = false,
    bool updatePhotoField = false,
    String previousPhone = '',
    String recoveryGmail = '',
    ProfileDirectoryProvider? directory,
  }) async {
    final current = user;
    final repo = _repo;
    if (current == null || repo == null) {
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

    final cleanPhotoInput = photoRaw.trim();
    if (!removePhoto && cleanPhotoInput.isNotEmpty) {
      final photoErr =
          AppFormatters.validateOptionalHttpsImageUrl(cleanPhotoInput);
      if (photoErr != null) {
        error = photoErr;
        notifyListeners();
        return false;
      }
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      final oldNorm = AppFormatters.normalizePhone(previousPhone);
      if (normPhone.isNotEmpty && normPhone != oldNorm) {
        final clash = await repo.lookupPhoneDirectory(normPhone);
        if (clash != null && clash['uid'] != current.uid) {
          error = 'This phone number is already registered by another member.';
          return false;
        }
      }

      final existing =
          await repo.fetchUserDoc(current.uid) ?? const <String, dynamic>{};

      String nextPhoto = (existing['photoUrl'] as String?) ?? '';
      if (removePhoto) {
        nextPhoto = '';
      } else if (cleanPhotoInput.isNotEmpty) {
        nextPhoto = cleanPhotoInput;
      } else if (updatePhotoField) {
        nextPhoto = '';
      }

      await current.updateDisplayName(name.trim());
      if (removePhoto || nextPhoto.isEmpty) {
        await current.updatePhotoURL(null);
      } else if (nextPhoto.length < 1800) {
        await current.updatePhotoURL(nextPhoto);
      }

      final phoneChanged = normPhone != oldNorm;
      final effectiveRecovery = cleanRecovery.isNotEmpty
          ? cleanRecovery
          : (existing['recoveryEmail'] as String?) ?? (current.email ?? '');

      final updateMap = <String, dynamic>{
        'name': name.trim(),
        'bio': bio.trim(),
        'department': department.trim(),
        'hostel': hostel.trim(),
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

      await repo.updateUserDoc(current.uid, updateMap);

      if (oldNorm.isNotEmpty && oldNorm != normPhone) {
        try {
          await repo.deletePhoneIfOwned(oldNorm, current.uid);
        } catch (_) {}
      }

      final mergedData = {...existing, ...updateMap};
      await repo.syncPublicAndPhoneDirectory(
        uid: current.uid,
        userData: mergedData,
      );
      await repo.syncSellerListingsMetadata(
        uid: current.uid,
        name: name.trim(),
        photoUrl: nextPhoto,
      );

      directory?.upsertLocal(
        PublicUserProfile.fromMap(current.uid, mergedData),
      );
      return true;
    } catch (e) {
      error =
          MarketplaceLogic.mapError(e, fallback: 'Could not save profile updates');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccountGmail({
    required String newGmail,
    String currentPassword = '',
  }) async {
    final current = user;
    final repo = _repo;
    if (current == null || repo == null) return false;
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
      await repo.updateUserDoc(current.uid, {
        'recoveryEmail': clean,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final data = await repo.fetchUserDoc(current.uid);
      if (data != null) {
        await repo.syncPublicAndPhoneDirectory(
          uid: current.uid,
          userData: data,
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

  Future<bool> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    final repo = _repo;
    if (repo == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final cred =
          await repo.signInWithEmailAndPassword(email.trim(), password);
      final uid = cred.user?.uid;
      if (uid == null) {
        error = 'Authentication failed';
        return false;
      }
      final data = await repo.fetchUserDoc(uid);
      final verifiedAdmin =
          data?['role'] == 'admin' || (data?['isAdmin'] == true);
      if (!verifiedAdmin) {
        await repo.signOut();
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

  Future<bool> deleteAccount({String? password}) async {
    final current = user;
    final repo = _repo;
    if (current == null || repo == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repo.deleteUserAccountAndData(current, password);
      guestMode = false;
      return true;
    } on FirebaseAuthException catch (e) {
      error = e.message ?? 'Re-authentication failed';
      return false;
    } catch (e) {
      error = MarketplaceLogic.mapError(e, fallback: 'Could not delete account');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    guestMode = false;
    await _repo?.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _accountSub?.cancel();
    super.dispose();
  }
}
