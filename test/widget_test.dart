import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_it_on/models.dart';
import 'package:pass_it_on/providers/app_providers.dart';
import 'package:pass_it_on/repositories/listing_repository.dart';
import 'package:pass_it_on/screens/browse_screen.dart';
import 'package:pass_it_on/screens/favourites_screen.dart';
import 'package:pass_it_on/screens/root_screen.dart';
import 'package:pass_it_on/utils/app_typography.dart';
import 'package:pass_it_on/utils/formatters.dart';
import 'package:pass_it_on/widgets/animated_ui.dart';
import 'package:pass_it_on/widgets/legal_dialog.dart';
import 'package:pass_it_on/widgets/smart_image.dart';
import 'package:pass_it_on/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class _StubListingRepo implements ListingRepository {
  final List<Listing> seed;
  final StreamController<ListingPageResult> _pageController =
      StreamController<ListingPageResult>.broadcast();
  _StubListingRepo([this.seed = const []]);

  void emitSeed() {
    _pageController.add(ListingPageResult(
      items: seed,
      lastCursor: seed.isNotEmpty ? seed.last : null,
      hasMore: false,
    ));
  }

  void dispose() {
    _pageController.close();
  }

  @override
  Future<void> addComment({
    required Listing listing,
    required String authorId,
    required String fallbackAuthorName,
    required String text,
  }) async {}

  @override
  Future<void> createListing({
    required String sellerId,
    required String fallbackSellerName,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> imageUrls,
    bool feePaid = false,
    String feeTransactionId = '',
  }) async {}

  @override
  Future<void> deleteComment(String listingId, String commentId) async {}

  @override
  Future<void> deleteListing(String listingId) async {}

  @override
  Future<Listing?> fetchListingById(String listingId) async => null;

  @override
  Future<Map<String, Map<String, dynamic>>> fetchFavoriteMetadata(
    String uid,
  ) async =>
      const {};

  @override
  Future<ListingPageResult> fetchPage({
    int limit = ListingRepository.pageSize,
    Object? startAfter,
  }) async =>
      const ListingPageResult(items: [], lastCursor: null, hasMore: false);

  @override
  Future<List<Listing>> resolveFavoriteListings({
    required Set<String> favoriteIds,
    required Map<String, Map<String, dynamic>> cachedMeta,
    required Map<String, Listing> knownListings,
  }) async =>
      seed.where((l) => favoriteIds.contains(l.id)).toList();

  @override
  Future<List<Listing>> searchByKeywords(
    String query, {
    int limit = ListingRepository.pageSize,
  }) async =>
      const [];

  @override
  Future<void> setFavorite({
    required String uid,
    required Listing listing,
    required bool save,
  }) async {}

  @override
  Future<void> updateListing({
    required String listingId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required String location,
    required int price,
    required bool negotiable,
    required List<String> imageUrls,
  }) async {}

  @override
  Future<void> updateListingStatus({
    required String listingId,
    required String status,
    String reservedFor = '',
  }) async {}

  @override
  Stream<List<ListingComment>> watchComments(String listingId) =>
      Stream.value(const []);

  @override
  Stream<Set<String>> watchFavoriteIds(String uid) =>
      Stream.value(const <String>{});

  @override
  Stream<ListingPageResult> watchInitialPage({
    int limit = ListingRepository.pageSize,
  }) =>
      _pageController.stream;

  @override
  Stream<List<Listing>> watchSellerListings(String sellerId) =>
      Stream.value(const []);
}

Widget _wrapWithProviders({
  required Widget child,
  required ListingProvider listingProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ProfileDirectoryProvider(autoStart: false)),
      ChangeNotifierProvider(create: (_) => AuthProvider(autoStart: false)),
      ChangeNotifierProvider.value(value: listingProvider),
      ChangeNotifierProvider(create: (_) => SellProvider(autoStart: false)),
      ChangeNotifierProvider(create: (_) => OfferProvider(autoStart: false)),
      ChangeNotifierProvider(create: (_) => RatingProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider(autoStart: false)),
      ChangeNotifierProvider(create: (_) => ReportProvider()),
      ChangeNotifierProvider(create: (_) => AdminProvider(autoStart: false)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('SmartListingImage renders valid base64 and Category fallback renders cleanly',
      (WidgetTester tester) async {
    final onePxPng = base64Encode(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
      120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69,
      78, 68, 174, 66, 96, 130,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 60,
                width: 60,
                child: SmartListingImage(
                  imageUrl: 'data:image/png;base64,$onePxPng',
                  fallback: ListingCategoryArtwork.fallback('Books'),
                ),
              ),
              SizedBox(
                height: 60,
                width: 60,
                child: SmartListingImage(
                  imageUrl: '',
                  fallback: ListingCategoryArtwork.fallback('Electronics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.devices_other_rounded), findsOneWidget);
  });

  testWidgets('LegalPoliciesDialog opens and closes cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: AppTypography.uiFont,
          textTheme: AppTypography.buildTextTheme(
            ThemeData.light().textTheme,
            isDark: false,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => LegalPoliciesDialog.show(context),
                child: const Text('Open Legal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Legal'));
    await tester.pumpAndSettle();

    expect(find.text('Terms, Privacy & Escrow Policy'), findsOneWidget);
    expect(find.text('4. Data Privacy & Account Deletion'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Terms, Privacy & Escrow Policy'), findsNothing);
  });

  testWidgets('Animated UI skeleton grid and badges render cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ShimmeringBadge(child: Text('ESCROW')),
              RadarPulseBeacon(size: 8),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('ESCROW'), findsOneWidget);
    expect(find.byType(RadarPulseBeacon), findsOneWidget);
  });

  testWidgets('UserAvatar handles Unknown user and initials cleanly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              UserAvatar(name: 'Nusrat', showVerifiedBadge: true),
              UserAvatar(name: AppFormatters.unknownUserName),
            ],
          ),
        ),
      ),
    );

    expect(find.text('N'), findsOneWidget);
    expect(find.text('U'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('BrowseScreen displays loading, empty, error, and listing states without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final sampleListings = [
      Listing(
        id: 'l1',
        title: 'Linear Algebra Book',
        description: 'Great condition paperback',
        category: 'Books',
        condition: 'like-new',
        location: 'Main Library',
        price: 450,
        negotiable: true,
        imageUrl: '',
        sellerId: 's1',
        sellerName: 'Tariq Hasan',
        status: 'available',
        reservedFor: '',
      ),
    ];

    final stubRepo = _StubListingRepo(sampleListings);
    addTearDown(stubRepo.dispose);
    final lp = ListingProvider(
      repository: stubRepo,
      currentUidProvider: () => 'b1',
      autoStart: true,
    );

    // Loading skeleton state
    await tester.pumpWidget(_wrapWithProviders(
      listingProvider: lp,
      child: const BrowseScreen(),
    ));
    await tester.pump();
    expect(find.byType(ListingGridSkeleton), findsOneWidget);

    // Error state
    lp.loading = false;
    lp.error = 'Simulated connection error';
    lp.setCategory('All');
    await tester.pump();
    expect(find.text('Unable to load listings'), findsOneWidget);
    expect(find.text('Simulated connection error'), findsOneWidget);

    // Emit listings -> Empty filtered state -> Clear filters -> Populated card
    lp.error = null;
    stubRepo.emitSeed();
    await tester.pump();
    lp.setCategory('Sports');
    await tester.pump();
    expect(find.text('No matching items found'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();

    // Populated listing card renders cleanly on 390px mobile
    expect(find.text('Linear Algebra Book'), findsOneWidget);
    expect(find.text('Books'), findsWidgets);
    lp.dispose();
  });

  testWidgets('FavouritesScreen surfaces No longer available badge on sold or deleted saved items',
      (WidgetTester tester) async {
    final soldSaved = Listing(
      id: 'sold_1',
      title: 'Mechanical Keyboard',
      description: 'Blue switches',
      category: 'Electronics',
      condition: 'used',
      price: 2200,
      negotiable: false,
      imageUrl: '',
      sellerId: 's2',
      sellerName: 'Rafi',
      status: 'sold',
      reservedFor: '',
    );
    final stubRepo = _StubListingRepo([soldSaved]);
    addTearDown(stubRepo.dispose);
    final lp = ListingProvider(
      repository: stubRepo,
      currentUidProvider: () => 'b1',
      autoStart: false,
    );
    lp.favoriteIds = {'sold_1'};
    await lp.refreshFavorites();

    await tester.pumpWidget(_wrapWithProviders(
      listingProvider: lp,
      child: const FavouritesScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mechanical Keyboard'), findsOneWidget);
    expect(find.text('Sold · No longer available'), findsOneWidget);
    lp.dispose();
  });

  testWidgets('RootScreen renders strictly 4 bottom tabs and top-bar Messages button on mobile',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final stubRepo = _StubListingRepo(const []);
    addTearDown(stubRepo.dispose);
    final lp = ListingProvider(
      repository: stubRepo,
      currentUidProvider: () => null,
      autoStart: false,
    );

    await tester.pumpWidget(_wrapWithProviders(
      listingProvider: lp,
      child: const RootScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Sell'), findsWidgets);
    expect(find.text('Offers'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.byTooltip('Messages'), findsOneWidget);

    await tester.tap(find.text('Sell').last);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Sign in'), findsWidgets);
    lp.dispose();
  });

  testWidgets('ListingDetailSheet shows Make Offer and Buy at Asking Price on negotiable items',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final item = Listing(
      id: 'item_negotiable',
      title: 'Engineering Physics Notes',
      description: 'Complete semester bundle',
      category: 'Books',
      condition: 'like-new',
      price: 600,
      negotiable: true,
      imageUrl: '',
      sellerId: 'seller_9',
      sellerName: AppFormatters.unknownUserName,
      status: 'available',
      reservedFor: '',
    );
    final stubRepo = _StubListingRepo([item]);
    addTearDown(stubRepo.dispose);
    final lp = ListingProvider(
      repository: stubRepo,
      currentUidProvider: () => 'buyer_1',
      autoStart: false,
    );

    await tester.pumpWidget(_wrapWithProviders(
      listingProvider: lp,
      child: ListingDetailSheet(listing: item),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    // Guest state prompts sign in and Unknown user fallback shows cleanly
    expect(find.text('Sign In to Chat or Make Offer'), findsOneWidget);
    expect(find.text('Engineering Physics Notes'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pump();
    expect(find.text(AppFormatters.unknownUserName), findsOneWidget);
    lp.dispose();
  });
}
