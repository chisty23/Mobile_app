import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Uploads local `data:image/...;base64,...` URIs to Firebase Cloud Storage over
/// authenticated REST calls so listing photos never bloat Firestore documents.
class StorageUploader {
  final http.Client _client;
  final String bucket;

  StorageUploader({
    http.Client? client,
    this.bucket = 'pass-it-on-2f422.firebasestorage.app',
  }) : _client = client ?? http.Client();

  static Uint8List? decodeDataUri(String uri) {
    if (!uri.startsWith('data:image')) return null;
    final commaIdx = uri.indexOf(',');
    if (commaIdx == -1 || commaIdx >= uri.length - 1) return null;
    try {
      return base64Decode(uri.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  static String buildDownloadUrl({
    required String bucket,
    required String objectPath,
    String? downloadToken,
  }) {
    final encoded = Uri.encodeComponent(objectPath);
    if (downloadToken != null && downloadToken.isNotEmpty) {
      return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media&token=$downloadToken';
    }
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media';
  }

  /// Uploads any data-URI images in [images] to `listings/{uid}/...` and returns
  /// the resolved list of URLs. If Firebase Storage is not yet activated in the
  /// Console, compact URIs (<= 220 KB) are preserved gracefully as fallback.
  Future<List<String>> uploadListingImages({
    required List<String> images,
    required String uid,
    required String? idToken,
  }) async {
    final resolved = <String>[];
    for (int i = 0; i < images.length; i++) {
      final raw = images[i].trim();
      if (raw.isEmpty) continue;
      final uploaded = await _uploadSingleImage(
        raw: raw,
        objectPath:
            'listings/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        idToken: idToken,
      );
      if (uploaded != null && uploaded.isNotEmpty) {
        resolved.add(uploaded);
      }
    }
    return resolved;
  }

  /// Uploads a user's profile avatar to `profiles/{uid}/avatar_<ts>.jpg` and falls
  /// back cleanly to a compact Data URI if Firebase Storage is not set up yet.
  Future<String> uploadAvatarImage({
    required String rawImage,
    required String uid,
    required String? idToken,
  }) async {
    final raw = rawImage.trim();
    if (raw.isEmpty) return '';
    final uploaded = await _uploadSingleImage(
      raw: raw,
      objectPath: 'profiles/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      idToken: idToken,
    );
    return uploaded ?? '';
  }

  Future<String?> _uploadSingleImage({
    required String raw,
    required String objectPath,
    required String? idToken,
  }) async {
    final bytes = decodeDataUri(raw);
    if (bytes == null) {
      return raw;
    }

    if (idToken == null || idToken.isEmpty || bucket.isEmpty) {
      return bytes.length <= 220 * 1024 ? raw : null;
    }

    final uploadUrl = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
      '?uploadType=media&name=${Uri.encodeComponent(objectPath)}',
    );

    try {
      final response = await _client
          .post(
            uploadUrl,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'image/jpeg',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final tokens = (jsonMap['downloadTokens'] as String?) ?? '';
        final firstToken = tokens.split(',').first.trim();
        return buildDownloadUrl(
          bucket: bucket,
          objectPath: objectPath,
          downloadToken: firstToken.isEmpty ? null : firstToken,
        );
      }
      if (bytes.length <= 220 * 1024) {
        return raw;
      }
      return null;
    } catch (_) {
      if (bytes.length <= 220 * 1024) {
        return raw;
      }
      return null;
    }
  }
}
