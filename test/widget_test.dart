import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pass_it_on/utils/app_typography.dart';
import 'package:pass_it_on/widgets/animated_ui.dart';
import 'package:pass_it_on/widgets/legal_dialog.dart';
import 'package:pass_it_on/widgets/smart_image.dart';
import 'package:pass_it_on/widgets/user_avatar.dart';

void main() {
  testWidgets('SmartListingImage decodes base64 Data URI cleanly',
      (WidgetTester tester) async {
    // Valid 1x1 transparent PNG bytes
    final onePxPng = base64Encode(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
      120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69,
      78, 68, 174, 66, 96, 130,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartListingImage(
            imageUrl: 'data:image/png;base64,$onePxPng',
            fallback: const Text('Fallback'),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Fallback'), findsNothing);
  });

  testWidgets('SmartListingImage falls back cleanly on invalid URLs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartListingImage(
            imageUrl: '',
            fallback: Icon(Icons.inventory_2_outlined),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
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

  testWidgets('UserAvatar renders uploaded base64 photo and fallback initials cleanly',
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
          body: Row(
            children: [
              UserAvatar(
                name: 'Tariq',
                photoUrl: 'data:image/png;base64,$onePxPng',
                showVerifiedBadge: true,
              ),
              const UserAvatar(
                name: 'Nusrat',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
