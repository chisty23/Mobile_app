import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'screens/admin_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/root_screen.dart';
import 'utils/app_typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }
  runApp(const PassItOnApp());
}

class PassItOnApp extends StatelessWidget {
  const PassItOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
        ChangeNotifierProvider(create: (_) => SellProvider()),
        ChangeNotifierProvider(create: (_) => OfferProvider()),
        ChangeNotifierProvider(create: (_) => RatingProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'PassItOn',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF3F1EC),
              cardColor: Colors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF252832),
                brightness: Brightness.light,
                primary: const Color(0xFF252832),
                secondary: const Color(0xFF667B72),
                surface: Colors.white,
              ),
              fontFamily: AppTypography.uiFont,
              fontFamilyFallback: AppTypography.fallback,
              textTheme: AppTypography.buildTextTheme(
                ThemeData(brightness: Brightness.light).textTheme,
                isDark: false,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF13151A),
              cardColor: const Color(0xFF1E222B),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7E978C),
                brightness: Brightness.dark,
                primary: const Color(0xFF7E978C),
                secondary: const Color(0xFFA5B8AF),
                surface: const Color(0xFF1E222B),
              ),
              fontFamily: AppTypography.uiFont,
              fontFamilyFallback: AppTypography.fallback,
              textTheme: AppTypography.buildTextTheme(
                ThemeData(brightness: Brightness.dark).textTheme,
                isDark: true,
              ),
            ),
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFFF3F1EC),
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF252832)),
                          SizedBox(height: 16),
                          Text(
                            'Loading PassItOn...',
                            style: TextStyle(
                              color: Color(0xFF252832),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final user = snapshot.data;
                if (user == null) {
                  return authProvider.guestMode ? const RootScreen() : const AuthScreen();
                }
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data();
                    if (userData?['isBanned'] == true) {
                      return Scaffold(
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.block_rounded,
                                  size: 64,
                                  color: Color(0xFFD94B64),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Account Suspended',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This account has been suspended for violating PassItOn marketplace policies.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF777D8E)),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: () =>
                                      context.read<AuthProvider>().logout(),
                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final role = userData?['role'] as String? ?? 'customer';
                    final isAdmin =
                        role == 'admin' || (userData?['isAdmin'] as bool? ?? false);
                    if (isAdmin) {
                      return const AdminScreen();
                    }
                    return const RootScreen();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
