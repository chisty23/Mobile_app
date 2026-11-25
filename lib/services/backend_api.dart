import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isEndpointUnavailable;

  BackendApiException(
    this.message, {
    this.statusCode,
    this.isEndpointUnavailable = false,
  });

  @override
  String toString() => message;
}

/// Client for PassItOn's authenticated Cloud Functions HTTPS endpoints (`/api/*`).
class BackendApi {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://us-central1-pass-it-on-2f422.cloudfunctions.net/api',
  );

  final http.Client _client;
  final String baseUrl;
  final Future<String?> Function() _tokenProvider;

  BackendApi({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _tokenProvider = tokenProvider ?? _defaultTokenProvider;

  static Future<String?> _defaultTokenProvider() async {
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw BackendApiException('Please sign in first.', statusCode: 401);
    }

    final uri = Uri.parse('$baseUrl$path');
    try {
      final res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> decoded = {};
      if (res.body.isNotEmpty) {
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map<String, dynamic>) decoded = parsed;
        } catch (_) {}
      }

      if (res.statusCode == 404) {
        throw BackendApiException(
          'Cloud Functions API is not deployed yet. Run "firebase deploy --only functions" in Firebase CLI.',
          statusCode: 404,
          isEndpointUnavailable: true,
        );
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return decoded;
      }

      throw BackendApiException(
        (decoded['error'] as String?) ??
            'Server request failed (HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    } on TimeoutException {
      throw BackendApiException(
        'Server took too long to respond. Check your internet connection or deploy status.',
        isEndpointUnavailable: true,
      );
    } on http.ClientException catch (e) {
      throw BackendApiException(
        'Could not reach Firebase Cloud Functions (${e.message}).',
        isEndpointUnavailable: true,
      );
    }
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String type,
    required String method,
    required String referenceId,
    required String referenceTitle,
    String phone = '',
  }) {
    return postJson('/payments/initiate', {
      'type': type,
      'method': method,
      'referenceId': referenceId,
      'referenceTitle': referenceTitle,
      'phone': phone,
    });
  }

  Future<Map<String, dynamic>> publishListing({
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> images,
    String paymentId = '',
  }) {
    return postJson('/listings/publish', {
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'location': location,
      'price': price,
      'negotiable': negotiable,
      'images': images,
      'paymentId': paymentId,
    });
  }

  Future<Map<String, dynamic>> submitOffer({
    required String listingId,
    required int amount,
    required String message,
    String paymentId = '',
  }) {
    return postJson('/offers/submit', {
      'listingId': listingId,
      'amount': amount,
      'message': message,
      'paymentId': paymentId,
    });
  }

  Future<Map<String, dynamic>> transitionOffer({
    required String offerId,
    required String action,
    String handoverPin = '',
    int counterAmount = 0,
  }) {
    return postJson('/offers/transition', {
      'offerId': offerId,
      'action': action,
      'handoverPin': handoverPin,
      'counterAmount': counterAmount,
    });
  }

  Future<Map<String, dynamic>> submitRating({
    required String listingId,
    required String sellerId,
    required int stars,
    required String comment,
    String offerId = '',
  }) {
    return postJson('/ratings/submit', {
      'listingId': listingId,
      'sellerId': sellerId,
      'stars': stars,
      'comment': comment,
      'offerId': offerId,
    });
  }

  Future<Map<String, dynamic>> deleteAccount() {
    return postJson('/account/delete', {});
  }

  Future<Map<String, dynamic>> banUser({
    required String targetUid,
    required bool banned,
  }) {
    return postJson('/admin/banUser', {
      'targetUid': targetUid,
      'banned': banned,
    });
  }

  Future<Map<String, dynamic>> refundPayment(String paymentId) {
    return postJson('/admin/refund', {'paymentId': paymentId});
  }
}
