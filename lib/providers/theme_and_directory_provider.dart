import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../repositories/auth_repository.dart';
import '../utils/formatters.dart';

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
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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

class ProfileDirectoryProvider extends ChangeNotifier {
  final FirestoreAuthRepository? _repo;
  final Map<String, PublicUserProfile> _publicProfiles = {};
  final Set<String> _inFlight = {};
  final Set<String> _missingIds = {};
  StreamSubscription<List<PublicUserProfile>>? _sub;

  ProfileDirectoryProvider({
    FirestoreAuthRepository? repository,
    bool autoStart = true,
  }) : _repo = repository ?? _safeRepo() {
    if (autoStart) _initStream();
  }

  static FirestoreAuthRepository? _safeRepo() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirestoreAuthRepository();
    } catch (_) {
      return null;
    }
  }

  void _initStream() {
    final repo = _repo;
    if (repo == null) return;
    try {
      _sub = repo.watchPublicProfiles(limit: 250).listen((profiles) {
        for (final p in profiles) {
          _publicProfiles[p.uid] = p;
          _missingIds.remove(p.uid);
        }
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {}
  }

  PublicUserProfile? profileFor(String uid) => _publicProfiles[uid];

  bool isKnownMissing(String uid) => _missingIds.contains(uid);

  String photoFor(String uid, {String fallback = ''}) {
    final p = _publicProfiles[uid]?.photoUrl ?? '';
    return p.isNotEmpty ? p : fallback;
  }

  String nameFor(String uid, {String fallback = ''}) {
    final n = _publicProfiles[uid]?.name ?? '';
    if (n.isNotEmpty && n != AppFormatters.unknownUserName) return n;
    if (_missingIds.contains(uid)) return AppFormatters.unknownUserName;
    final cleanFallback = fallback.trim();
    return cleanFallback.isNotEmpty
        ? cleanFallback
        : AppFormatters.unknownUserName;
  }

  ({double average, int count}) ratingSummaryFor(String uid) {
    final p = _publicProfiles[uid];
    if (p == null) return (average: 0.0, count: 0);
    return (average: p.averageRating, count: p.ratingCount);
  }

  void upsertLocal(PublicUserProfile profile) {
    _publicProfiles[profile.uid] = profile;
    _missingIds.remove(profile.uid);
    notifyListeners();
  }

  Future<PublicUserProfile?> ensureLoaded(String uid) async {
    if (uid.trim().isEmpty) return null;
    final existing = _publicProfiles[uid];
    if (existing != null) return existing;
    if (_inFlight.contains(uid)) return existing;
    final repo = _repo;
    if (repo == null) return existing;
    try {
      _inFlight.add(uid);
      final pub = await repo.fetchPublicProfile(uid);
      if (pub != null) {
        _publicProfiles[uid] = pub;
        _missingIds.remove(uid);
      } else {
        _missingIds.add(uid);
      }
      notifyListeners();
      return _publicProfiles[uid];
    } catch (_) {
      return existing;
    } finally {
      _inFlight.remove(uid);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
