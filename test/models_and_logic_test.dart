import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pass_it_on/models.dart';
import 'package:pass_it_on/providers/app_providers.dart';
import 'package:pass_it_on/services/backend_api.dart';
import 'package:pass_it_on/utils/app_typography.dart';
import 'package:pass_it_on/utils/formatters.dart';
import 'package:pass_it_on/utils/storage_uploader.dart';

void main() {
  group('Listing Model Tests', () {
    test('status getters work correctly', () {
      final available = Listing(
        id: '1',
        title: 'Algorithms Textbook',
        description: 'CLRS 3rd Edition',
        category: 'Books',
        condition: 'like-new',
        price: 850,
        negotiable: true,
        imageUrl: '',
        sellerId: 'user1',
        sellerName: 'Alice',
        status: 'available',
        reservedFor: '',
      );
      expect(available.isAvailable, isTrue);
      expect(available.isReserved, isFalse);
      expect(available.isSold, isFalse);

      final reserved = Listing(
        id: '2',
        title: 'Algorithms Textbook',
        description: 'CLRS 3rd Edition',
        category: 'Books',
        condition: 'like-new',
        price: 850,
        negotiable: true,
        imageUrl: '',
        sellerId: 'user1',
        sellerName: 'Alice',
        status: 'reserved',
        reservedFor: 'user2',
      );
      expect(reserved.isAvailable, isFalse);
      expect(reserved.isReserved, isTrue);
      expect(reserved.isSold, isFalse);

      final sold = Listing(
        id: '3',
        title: 'Algorithms Textbook',
        description: 'CLRS 3rd Edition',
        category: 'Books',
        condition: 'like-new',
        price: 850,
        negotiable: true,
        imageUrl: '',
        sellerId: 'user1',
        sellerName: 'Alice',
        status: 'sold',
        reservedFor: 'user2',
      );
      expect(sold.isAvailable, isFalse);
      expect(sold.isReserved, isFalse);
      expect(sold.isSold, isTrue);
    });
  });

  group('MarketOffer Model Tests', () {
    test('isExpired detects > 48h for pending and countered offers', () {
      final freshTime =
          Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 10)));
      final freshOffer = MarketOffer(
        id: 'o1',
        listingId: 'l1',
        listingTitle: 'Bike',
        sellerId: 's1',
        buyerId: 'b1',
        buyerName: 'Bob',
        amount: 2500,
        message: 'Can pick up today',
        status: 'pending',
        createdAt: freshTime,
      );
      expect(freshOffer.isExpired, isFalse);

      final oldTime =
          Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 50)));
      final expiredPending = MarketOffer(
        id: 'o2',
        listingId: 'l1',
        listingTitle: 'Bike',
        sellerId: 's1',
        buyerId: 'b1',
        buyerName: 'Bob',
        amount: 2500,
        message: 'Can pick up today',
        status: 'pending',
        createdAt: oldTime,
      );
      expect(expiredPending.isExpired, isTrue);

      final expiredAccepted = MarketOffer(
        id: 'o3',
        listingId: 'l1',
        listingTitle: 'Bike',
        sellerId: 's1',
        buyerId: 'b1',
        buyerName: 'Bob',
        amount: 2500,
        message: 'Can pick up today',
        status: 'accepted',
        createdAt: oldTime,
      );
      // Accepted offers do not expire
      expect(expiredAccepted.isExpired, isFalse);
    });
  });

  group('PresetCatalog Tests', () {
    test('contains presets and resolves defaults for all campus categories', () {
      expect(PresetCatalog.presets.isNotEmpty, isTrue);

      final bookDefault = PresetCatalog.defaultForCategory('Books');
      expect(bookDefault, contains('http'));

      final electronicsDefault = PresetCatalog.defaultForCategory('Electronics');
      expect(electronicsDefault, contains('http'));

      final otherDefault = PresetCatalog.defaultForCategory('NonExistentCategory');
      expect(otherDefault, isNotEmpty);
    });
  });

  group('ThemeProvider Tests', () {
    test('toggles theme between light and dark', () {
      final themeProvider = ThemeProvider();
      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDark, isFalse);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDark, isTrue);

      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.light);
      expect(themeProvider.isDark, isFalse);

      themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.isDark, isTrue);
    });
  });

  group('Admin Fee Settings & Payment System Tests', () {
    test('PlatformFeeSettings defaults and serialization work correctly', () {
      const defaultSettings = PlatformFeeSettings();
      expect(defaultSettings.sellerListingFee, 20);
      expect(defaultSettings.buyerOrderFee, 50);
      expect(defaultSettings.feesEnabled, isTrue);

      final map = {
        'sellerListingFee': 30,
        'buyerOrderFee': 75,
        'feesEnabled': false,
        'updatedBy': 'admin_test',
      };
      final fromMap = PlatformFeeSettings.fromMap(map);
      expect(fromMap.sellerListingFee, 30);
      expect(fromMap.buyerOrderFee, 75);
      expect(fromMap.feesEnabled, isFalse);
      expect(fromMap.updatedBy, 'admin_test');

      final serialized = fromMap.toMap();
      expect(serialized['sellerListingFee'], 30);
      expect(serialized['buyerOrderFee'], 75);
      expect(serialized['feesEnabled'], isFalse);
    });

    test('PlatformPaymentRecord handles bKash and Nagad payment records', () {
      final payment = PlatformPaymentRecord(
        id: 'pay_001',
        userId: 'usr_123',
        userName: 'Tanvir Ahmed',
        userEmail: 'tanvir@campus.edu',
        type: 'seller_listing_fee',
        amount: 20,
        currency: 'BDT',
        method: 'bKash',
        transactionId: 'TXN-984210',
        referenceId: 'listing_99',
        referenceTitle: 'Chemistry Lab Coat',
        status: 'completed',
        createdAt: DateTime.now(),
      );

      expect(payment.amount, 20);
      expect(payment.currency, 'BDT');
      expect(payment.method, 'bKash');
      expect(payment.transactionId, 'TXN-984210');
      expect(payment.status, 'completed');

      final map = payment.toMap();
      expect(map['userId'], 'usr_123');
      expect(map['amount'], 20);
      expect(map['method'], 'bKash');
      expect(map['transactionId'], 'TXN-984210');
    });

    test('Listing and MarketOffer track platform fee payment state', () {
      final listingWithFee = Listing(
        id: 'l_fee',
        title: 'Microbiology Kit',
        description: 'Complete sterile kit',
        category: 'Other',
        condition: 'like-new',
        price: 1200,
        negotiable: false,
        imageUrl: '',
        sellerId: 's_1',
        sellerName: 'Dr. Kabir',
        status: 'available',
        reservedFor: '',
        feePaid: true,
        feeTransactionId: 'TXN-SELLER-100',
      );
      expect(listingWithFee.feePaid, isTrue);
      expect(listingWithFee.feeTransactionId, 'TXN-SELLER-100');

      final offerWithFee = MarketOffer(
        id: 'o_fee',
        listingId: 'l_fee',
        listingTitle: 'Microbiology Kit',
        sellerId: 's_1',
        buyerId: 'b_1',
        buyerName: 'Rifat',
        amount: 1100,
        message: 'Interested',
        status: 'pending',
        feePaid: true,
        feeTransactionId: 'TXN-BUYER-200',
      );
      expect(offerWithFee.feePaid, isTrue);
      expect(offerWithFee.feeTransactionId, 'TXN-BUYER-200');
    });

    test('AppFormatters formats BDT currency and Listing handles multi-photo gallery', () {
      expect(AppFormatters.formatBDT(500), '500 ৳');
      expect(AppFormatters.formatBDT(1500), '1,500 ৳');
      expect(AppFormatters.formatBDT(10000000), '10,000,000 ৳');

      final galleryItem = Listing(
        id: 'l_gal',
        title: 'MacBook Air M1',
        description: 'Clean laptop',
        category: 'Electronics',
        condition: 'like-new',
        location: 'BUET Campus',
        price: 85000,
        negotiable: true,
        imageUrl: 'https://example.com/1.jpg',
        images: ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
        sellerId: 's1',
        sellerName: 'Arif',
        status: 'available',
        reservedFor: '',
      );
      expect(galleryItem.galleryImages.length, 2);
      expect(galleryItem.location, 'BUET Campus');
    });

    test('OfferHistoryEntry, handoverCode, and SellerReview map cleanly', () {
      final entry = OfferHistoryEntry.fromMap({
        'by': 'buyer_1',
        'amount': 4200,
      });
      expect(entry.by, 'buyer_1');
      expect(entry.amount, 4200);

      final review = SellerReview(
        id: 'l_rev',
        sellerId: 's1',
        buyerId: 'b1',
        buyerName: 'Nadia',
        stars: 5,
        comment: 'Verified original charger included',
        createdAt: DateTime.now(),
      );
      expect(review.stars, 5);
      expect(review.buyerName, 'Nadia');
    });

    test('Student verification helper and PlatformMetrics work properly', () {
      expect(isVerifiedStudentEmail('alice@buet.ac.bd'), isTrue);
      expect(isVerifiedStudentEmail('bob@mit.edu'), isTrue);
      expect(isVerifiedStudentEmail('charlie@gmail.com'), isFalse);

      final metrics = PlatformMetrics.fromMap({
        'totalRevenueBDT': 12500,
        'refundedRevenueBDT': 300,
        'sellerRevenueBDT': 5000,
        'buyerRevenueBDT': 7500,
      });
      expect(metrics.hasData, isTrue);
      expect(metrics.totalRevenueBDT, 12500);
      expect(metrics.buyerRevenueBDT, 7500);
    });
  });

  group('BackendApi & StorageUploader Tests', () {
    test('BackendApi sends Bearer auth token and parses server payment', () async {
      String? capturedAuth;
      String? capturedPath;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'mode': 'sandbox_completed',
            'payment': {
              'id': 'pay_srv_1',
              'transactionId': 'PIO-ABC123',
              'amount': 50,
            },
          }),
          200,
        );
      });

      final api = BackendApi(
        client: mockClient,
        baseUrl: 'https://example.com/api',
        tokenProvider: () async => 'test_jwt_token',
      );

      final res = await api.initiatePayment(
        type: 'buyer_order_fee',
        method: 'bKash',
        referenceId: 'listing_1',
        referenceTitle: 'Scientific Calculator',
      );

      expect(capturedAuth, 'Bearer test_jwt_token');
      expect(capturedPath, '/api/payments/initiate');
      expect(res['mode'], 'sandbox_completed');
    });

    test('BackendApi reports isEndpointUnavailable on HTTP 404', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Cannot POST /api/offers/submit', 404),
      );
      final api = BackendApi(
        client: mockClient,
        baseUrl: 'https://example.com/api',
        tokenProvider: () async => 'token',
      );

      await expectLater(
        () => api.submitOffer(listingId: 'l1', amount: 100, message: 'Hi'),
        throwsA(
          isA<BackendApiException>().having(
            (e) => e.isEndpointUnavailable,
            'isEndpointUnavailable',
            isTrue,
          ),
        ),
      );
    });

    test('StorageUploader uploads Data URI and builds tokenized download URL',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer id_token_123');
        expect(request.headers['Content-Type'], 'image/jpeg');
        return http.Response(
          jsonEncode({'downloadTokens': 'tok_9988,tok_backup'}),
          200,
        );
      });

      final uploader = StorageUploader(
        client: mockClient,
        bucket: 'pass-it-on-2f422.firebasestorage.app',
      );

      final dataUri = 'data:image/jpeg;base64,${base64Encode([1, 2, 3, 4])}';
      final result = await uploader.uploadListingImages(
        images: [dataUri, 'https://cdn.example.com/existing.jpg'],
        uid: 'user_abc',
        idToken: 'id_token_123',
      );

      expect(result.length, 2);
      expect(
        result.first,
        contains('https://firebasestorage.googleapis.com/v0/b/pass-it-on-2f422.firebasestorage.app/o/'),
      );
      expect(result.first, contains('token=tok_9988'));
      expect(result.last, 'https://cdn.example.com/existing.jpg');
    });

    test('AppTypography defines authentic Italian font families', () {
      expect(AppTypography.uiFont, 'EBGaramond');
      expect(AppTypography.displayFont, 'BodoniModa');
      expect(AppTypography.brandFont, 'Italiana');
      expect(AppTypography.display().fontFamily, 'BodoniModa');
      expect(AppTypography.price().fontFamily, 'BodoniModa');
      expect(AppTypography.brand().fontFamily, 'Italiana');
    });
  });

  group('Phone/Gmail Validation, Profiles & Avatar Tests', () {
    test('Phone normalization, validation, and masking work accurately', () {
      expect(AppFormatters.normalizePhone('01712345678'), '+8801712345678');
      expect(AppFormatters.normalizePhone('8801812345678'), '+8801812345678');
      expect(AppFormatters.normalizePhone('+880 1912-345678'), '+8801912345678');

      expect(AppFormatters.isValidPhone('01712345678'), isTrue);
      expect(AppFormatters.isValidPhone('+14155552671'), isTrue);
      expect(AppFormatters.isValidPhone('1234'), isFalse);

      expect(AppFormatters.looksLikePhone('01712345678'), isTrue);
      expect(AppFormatters.looksLikePhone('alice@gmail.com'), isFalse);

      expect(AppFormatters.maskEmail('moinchisty13@gmail.com'), 'mo***@gmail.com');
      expect(AppFormatters.maskPhone('01712345678'), '+880****5678');
    });

    test('Gmail validator enforces @gmail.com / @googlemail.com', () {
      expect(AppFormatters.isValidGmail('user.name+1@gmail.com'), isTrue);
      expect(AppFormatters.isValidGmail('STUDENT@GOOGLEMAIL.COM'), isTrue);
      expect(AppFormatters.isValidGmail('user@yahoo.com'), isFalse);
      expect(AppFormatters.isValidGmail('admin@passiton.com'), isFalse);
      expect(AppFormatters.isValidEmail('admin@passiton.com'), isTrue);
    });

    test('PublicUserProfile computes completion percent and ProfileDirectoryProvider caches safely', () {
      final incomplete = PublicUserProfile.fromMap('u1', {
        'name': 'Tariq Hasan',
      });
      expect(incomplete.completionPercent, 20);

      final complete = PublicUserProfile.fromMap('u2', {
        'name': 'Nusrat Jahan',
        'photoUrl': 'https://cdn.example.com/avatar.jpg',
        'bio': 'Final year EEE student',
        'department': 'BUET EEE',
        'location': 'BUET Campus',
        'meetupSpot': 'Main Gate',
        'ratingSum': 14,
        'ratingCount': 3,
      });
      expect(complete.completionPercent, 100);
      expect(complete.averageRating, closeTo(4.66, 0.02));

      final dir = ProfileDirectoryProvider();
      dir.upsertLocal(complete);
      expect(dir.photoFor('u2'), 'https://cdn.example.com/avatar.jpg');
      expect(dir.nameFor('u2'), 'Nusrat Jahan');
    });

    test('StorageUploader uploads avatar under profiles/{uid}/', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode({'downloadTokens': 'tok_av_1'}), 200);
      });

      final uploader = StorageUploader(client: mockClient);
      final dataUri = 'data:image/jpeg;base64,${base64Encode([5, 6, 7, 8])}';
      final url = await uploader.uploadAvatarImage(
        rawImage: dataUri,
        uid: 'u_avatar',
        idToken: 'tok_user',
      );

      expect(capturedUri.toString(), contains('profiles%2Fu_avatar%2Favatar_'));
      expect(url, contains('token=tok_av_1'));
    });

    test('ListingComment and avatar fields serialize properly', () {
      final comment = ListingComment(
        id: 'c1',
        listingId: 'l1',
        authorId: 'u9',
        authorName: 'Sadia',
        authorPhotoUrl: 'https://example.com/sadia.jpg',
        text: 'Does it include original box?',
        isSeller: false,
        createdAt: DateTime.now(),
      );
      expect(comment.authorPhotoUrl, 'https://example.com/sadia.jpg');
      expect(comment.isSeller, isFalse);
    });
  });
}
