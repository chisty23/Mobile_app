import 'dart:ui';

import 'package:flutter/material.dart';

import 'browse_screen.dart';
import 'sell_screen.dart';
import 'offers_screen.dart';
import 'profile_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      BrowseScreen(),
      SellScreen(),
      OffersScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3F1EC), Color(0xFFECEBE6)],
              ),
            ),
          ),
          Positioned(
            right: -100,
            top: 40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC69C55).withValues(alpha: 0.08),
              ),
            ),
          ),
          IndexedStack(index: index, children: pages),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: NavigationBar(
              height: 68,
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              backgroundColor: Colors.white.withValues(alpha: 0.88),
              indicatorColor: const Color(0xFFC69C55).withValues(alpha: 0.16),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Browse',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_business_outlined),
                  selectedIcon: Icon(Icons.add_business),
                  label: 'Sell',
                ),
                NavigationDestination(
                  icon: Icon(Icons.handshake_outlined),
                  selectedIcon: Icon(Icons.handshake),
                  label: 'Offers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
