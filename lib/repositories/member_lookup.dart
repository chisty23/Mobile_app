import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/formatters.dart';

/// Resolves a member's public display name and avatar URL safely without
/// throwing if the profile document is absent.
Future<({String name, String photoUrl})> resolveMemberProfile(
  FirebaseFirestore db,
  String uid,
  String fallbackName,
) async {
  final effectiveFallback = fallbackName.trim().isNotEmpty
      ? fallbackName.trim()
      : AppFormatters.unknownUserName;
  if (uid.trim().isEmpty) return (name: effectiveFallback, photoUrl: '');
  try {
    final pub = await db.collection('public_profiles').doc(uid).get();
    if (pub.exists && pub.data() != null) {
      final d = pub.data()!;
      final n = (d['name'] as String?)?.trim() ?? '';
      return (
        name: n.isNotEmpty ? n : effectiveFallback,
        photoUrl: (d['photoUrl'] as String?) ?? '',
      );
    }
    final userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final d = userDoc.data()!;
      final n = (d['name'] as String?)?.trim() ?? '';
      return (
        name: n.isNotEmpty ? n : effectiveFallback,
        photoUrl: (d['photoUrl'] as String?) ?? '',
      );
    }
  } catch (_) {}
  return (name: effectiveFallback, photoUrl: '');
}
