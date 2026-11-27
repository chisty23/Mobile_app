import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../widgets/animated_ui.dart';
import '../widgets/user_avatar.dart';
import 'browse_screen.dart';
import 'chat_screen.dart';
import 'notifications_sheet.dart';
import 'offers_screen.dart';
import 'profile_screen.dart';
import 'sell_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
  }

  Future<void> _handleDeepLink() async {
    final listingId = Uri.base.queryParameters['listing'];
    if (listingId == null || listingId.trim().isEmpty || !mounted) return;
    final listing =
        await context.read<ListingProvider>().fetchListingById(listingId.trim());
    if (listing != null && mounted) {
      ListingDetailSheet.show(context, listing);
    }
  }

  void _openMessages(BuildContext context, bool isGuest) {
    if (isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign in to view your direct messages'),
          action: SnackBarAction(
            label: 'Sign in',
            onPressed: () => context.read<AuthProvider>().exitGuestMode(),
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('Messages', style: AppTypography.display(size: 20)),
          ),
          body: const MessagesScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final offers = context.watch<OfferProvider>();
    final chat = context.watch<ChatProvider>();
    final currentUser = auth.user;
    final isGuest = currentUser == null;
    final pendingOffersCount =
        offers.received.where((o) => o.isActiveOffer).length;
    final unreadNotifications = offers.unreadNotificationCount;
    final unreadMessages = chat.unreadThreadsCount;
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    final pages = [
      const BrowseScreen(),
      isGuest
          ? const _GuestAuthPrompt(feature: 'sell items')
          : const SellScreen(),
      isGuest
          ? const _GuestAuthPrompt(feature: 'manage offers')
          : const OffersScreen(),
      isGuest
          ? const _GuestAuthPrompt(feature: 'view your profile')
          : const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF13151A) : const Color(0xFFF6F5F1),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 64 : 58),
        child: Container(
          height: isDesktop ? 64 : 58,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF2A2F3D)
                    : const Color(0xFFE7E4DC),
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () => setState(() => index = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF252832), Color(0xFF667B72)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'PassItOn',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.brand(
                                size: isDesktop ? 21 : 19,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF252832),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 24),
                    _desktopNavTab(
                      'Explore',
                      0,
                      isDark,
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore_rounded,
                    ),
                    _desktopNavTab(
                      'Sell',
                      1,
                      isDark,
                      icon: Icons.storefront_outlined,
                      activeIcon: Icons.storefront_rounded,
                    ),
                    _desktopNavTab(
                      'Offers',
                      2,
                      isDark,
                      icon: Icons.handshake_outlined,
                      activeIcon: Icons.handshake_rounded,
                      badge: pendingOffersCount,
                    ),
                    _desktopNavTab(
                      'Profile',
                      3,
                      isDark,
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      leadingOverride: !isGuest
                          ? UserAvatar(
                              uid: currentUser.uid,
                              name: auth.currentProfileData['name'] as String? ??
                                  currentUser.displayName ??
                                  'Me',
                              radius: 10,
                              showBorder: index == 3,
                              borderColor: const Color(0xFF667B72),
                            )
                          : null,
                    ),
                  ],
                  const Spacer(),
                  if (!isGuest) ...[
                    IconButton(
                      tooltip: 'Messages',
                      onPressed: () => _openMessages(context, isGuest),
                      icon: Badge(
                        isLabelVisible: unreadMessages > 0,
                        backgroundColor: const Color(0xFFD94B64),
                        label: Text('$unreadMessages'),
                        child: const Icon(Icons.forum_outlined, size: 22),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const NotificationsSheet(),
                      ),
                      icon: Badge(
                        isLabelVisible: unreadNotifications > 0,
                        label: Text('$unreadNotifications'),
                        child: unreadNotifications > 0
                            ? const RingingBellIcon(
                                isRinging: true,
                                color: Color(0xFFC69C55),
                                size: 21,
                              )
                            : const Icon(
                                Icons.notifications_none_rounded,
                                size: 22,
                              ),
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => setState(() => index = 1),
                        icon: const Icon(Icons.add_business_rounded, size: 18),
                        label: const Text(
                          'Post Item',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: index == 1
                              ? const Color(0xFF667B72)
                              : const Color(0xFF252832),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    IconButton(
                      tooltip: 'Messages',
                      onPressed: () => _openMessages(context, isGuest),
                      icon: const Icon(Icons.forum_outlined, size: 21),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: () =>
                          context.read<AuthProvider>().exitGuestMode(),
                      icon: const Icon(Icons.login_rounded, size: 17),
                      label: const Text('Sign In'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF252832),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 16 : 12,
                          vertical: 10,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181B22) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A2F3D)
                        : const Color(0xFFE7E4DC),
                  ),
                ),
              ),
              child: NavigationBar(
                height: 66,
                elevation: 0,
                selectedIndex: index,
                onDestinationSelected: (value) =>
                    setState(() => index = value),
                backgroundColor:
                    isDark ? const Color(0xFF181B22) : Colors.white,
                indicatorColor:
                    const Color(0xFF667B72).withValues(alpha: 0.14),
                destinations: [
                  NavigationDestination(
                    icon: _navIcon(
                      Icons.explore_outlined,
                      Icons.explore_rounded,
                      index == 0,
                      isDark,
                    ),
                    label: 'Explore',
                  ),
                  NavigationDestination(
                    icon: _navIcon(
                      Icons.add_business_outlined,
                      Icons.add_business_rounded,
                      index == 1,
                      isDark,
                    ),
                    label: 'Sell',
                  ),
                  NavigationDestination(
                    icon: _navIcon(
                      Icons.handshake_outlined,
                      Icons.handshake_rounded,
                      index == 2,
                      isDark,
                      badge: pendingOffersCount,
                    ),
                    label: 'Offers',
                  ),
                  NavigationDestination(
                    icon: !isGuest
                        ? UserAvatar(
                            uid: currentUser.uid,
                            name: auth.currentProfileData['name'] as String? ??
                                currentUser.displayName ??
                                'Me',
                            radius: 12,
                            showBorder: index == 3,
                            borderColor: const Color(0xFF667B72),
                          )
                        : _navIcon(
                            Icons.person_outline_rounded,
                            Icons.person_rounded,
                            index == 3,
                            isDark,
                          ),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _desktopNavTab(
    String label,
    int tabIndex,
    bool isDark, {
    required IconData icon,
    required IconData activeIcon,
    Widget? leadingOverride,
    int badge = 0,
  }) {
    final active = index == tabIndex;
    final fgColor = active
        ? (isDark ? Colors.white : const Color(0xFF252832))
        : (isDark ? Colors.grey.shade400 : const Color(0xFF6A7080));
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: () => setState(() => index = tabIndex),
        style: TextButton.styleFrom(
          foregroundColor: fgColor,
          backgroundColor: active
              ? (isDark ? const Color(0xFF252A36) : const Color(0xFFF2F0EA))
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leadingOverride ??
                Icon(
                  active ? activeIcon : icon,
                  size: 18,
                  color: active ? const Color(0xFF667B72) : fgColor,
                ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFD94B64),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navIcon(
    IconData unselected,
    IconData selected,
    bool isSelected,
    bool isDark, {
    int badge = 0,
  }) {
    Widget iconWidget = Icon(
      isSelected ? selected : unselected,
      size: 23,
      color: isSelected
          ? (isDark ? const Color(0xFFA5B8AF) : const Color(0xFF252832))
          : null,
    );
    if (badge > 0) {
      iconWidget = Badge(label: Text('$badge'), child: iconWidget);
    }
    return iconWidget;
  }
}

class _GuestAuthPrompt extends StatelessWidget {
  final String feature;
  const _GuestAuthPrompt({required this.feature});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF667B72).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 34,
                  color: Color(0xFF667B72),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sign in to $feature',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a free account or sign in to connect with buyers and sellers on PassItOn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () =>
                    context.read<AuthProvider>().exitGuestMode(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF252832),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sign In / Create Account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
