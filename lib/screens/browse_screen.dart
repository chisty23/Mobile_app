import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../widgets/animated_ui.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/payment_checkout_sheet.dart';
import '../widgets/report_sheet.dart';
import '../widgets/seller_profile_sheet.dart';
import '../widgets/smart_image.dart';
import 'chat_screen.dart';
import 'notifications_sheet.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final listing = context.watch<ListingProvider>();
    final offers = context.watch<OfferProvider>();
    final chat = context.watch<ChatProvider>();
    final unreadNotifications = offers.unreadNotificationCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: RefreshIndicator(
            onRefresh: listing.refresh,
            color: const Color(0xFF252832),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF252832), Color(0xFF667B72)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const ContinuousSpinIcon(
                                  icon: Icons.explore_rounded,
                                  color: Colors.white,
                                  size: 22,
                                  duration: Duration(seconds: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Discover',
                                      style: AppTypography.display(
                                        size: 30,
                                        letterSpacing: -0.7,
                                        color: isDark ? Colors.white : const Color(0xFF252832),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.verified_outlined,
                                          size: 13,
                                          color: Color(0xFF24A889),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Verified second-hand items near you',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : const Color(0xFF6A7080),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isDesktop) ...[
                          if (currentUser == null)
                            FilledButton(
                              onPressed: () => context.read<AuthProvider>().exitGuestMode(),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF252832),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700)),
                            )
                          else ...[
                            _headerActionButton(
                              context: context,
                              isDark: isDark,
                              badgeCount: chat.threads.length,
                              badgeColor: const Color(0xFF667B72),
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const ChatsDrawerSheet(),
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 21,
                                color: isDark ? Colors.white70 : const Color(0xFF252832),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _headerActionButton(
                              context: context,
                              isDark: isDark,
                              badgeCount: unreadNotifications,
                              badgeColor: const Color(0xFFD94B64),
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const NotificationsSheet(),
                              ),
                              child: unreadNotifications > 0
                                  ? const RingingBellIcon(
                                      isRinging: true,
                                      color: Color(0xFFC69C55),
                                      size: 22,
                                    )
                                  : Icon(
                                      Icons.notifications_none_rounded,
                                      size: 23,
                                      color: isDark ? Colors.white70 : const Color(0xFF252832),
                                    ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      onChanged: listing.setQuery,
                      decoration: InputDecoration(
                        hintText: 'Search books, electronics, bikes, campus zone...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Filter results',
                          onPressed: () => BrowseFilterSheet.show(context),
                          icon: Badge(
                            isLabelVisible: listing.activeFilterCount > 0,
                            label: Text('${listing.activeFilterCount}'),
                            child: const Icon(Icons.tune_rounded),
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E222B)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE6E4DC),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE6E4DC),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final item in const [
                            'All',
                            'Books',
                            'Electronics',
                            'Fashion',
                            'Sports',
                            'Furniture',
                            'Other',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: Icon(
                                  _categoryChipIcon(item),
                                  size: 16,
                                  color: listing.category == item
                                      ? Colors.white
                                      : (isDark ? Colors.grey.shade400 : const Color(0xFF626779)),
                                ),
                                label: Text(item),
                                selected: listing.category == item,
                                selectedColor: const Color(0xFF252832),
                                backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                                labelStyle: TextStyle(
                                  color: listing.category == item
                                      ? Colors.white
                                      : (isDark ? Colors.grey.shade300 : const Color(0xFF3E4352)),
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) => listing.setCategory(item),
                                side: BorderSide(
                                  color: listing.category == item
                                      ? const Color(0xFF252832)
                                      : (isDark ? const Color(0xFF2E3442) : const Color(0xFFE2E4EB)),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          avatar: listing.onlyAvailable
                              ? null
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: Color(0xFF24A889),
                                ),
                          label: const Text('Available Only'),
                          selected: listing.onlyAvailable,
                          selectedColor: const Color(0xFF24A889).withValues(alpha: 0.18),
                          checkmarkColor: const Color(0xFF24A889),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: listing.onlyAvailable
                                ? const Color(0xFF24A889)
                                : (isDark ? Colors.grey.shade400 : const Color(0xFF626779)),
                          ),
                          onSelected: (_) => listing.toggleOnlyAvailable(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        FilterChip(
                          avatar: listing.onlyFavorites
                              ? null
                              : const Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 15,
                                  color: Color(0xFFC69C55),
                                ),
                          label: const Text('Saved Only'),
                          selected: listing.onlyFavorites,
                          selectedColor: const Color(0xFFC69C55).withValues(alpha: 0.18),
                          checkmarkColor: const Color(0xFFC69C55),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: listing.onlyFavorites
                                ? const Color(0xFFC69C55)
                                : (isDark ? Colors.grey.shade400 : const Color(0xFF626779)),
                          ),
                          onSelected: (_) => listing.toggleOnlyFavorites(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        if (listing.activeFilterCount > 0)
                          ActionChip(
                            avatar: const Icon(Icons.close_rounded, size: 14),
                            label: Text(
                              '${listing.activeFilterCount} filter(s)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: listing.resetAllFilters,
                          ),
                        PopupMenuButton<String>(
                          initialValue: listing.sort,
                          onSelected: listing.setSort,
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'Newest',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 17),
                                  SizedBox(width: 8),
                                  Text('Newest first'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'Price low',
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_upward_rounded, size: 17),
                                  SizedBox(width: 8),
                                  Text('Price: low to high'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'Price high',
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_downward_rounded, size: 17),
                                  SizedBox(width: 8),
                                  Text('Price: high to low'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E222B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE2E4EB),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_vert_rounded, size: 17, color: Color(0xFF667B72)),
                                const SizedBox(width: 6),
                                Text(
                                  listing.sort,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (listing.loading)
                  const ListingGridSkeleton(count: 8)
                else if (listing.requiresAuthToBrowse)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF667B72)),
                            const SizedBox(height: 12),
                            const Text(
                              'Sign in to view live listings',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Sign in with your account to view real-time campus inventory.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF777D8E)),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.read<AuthProvider>().exitGuestMode(),
                              child: const Text('Sign In'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (listing.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(
                      context,
                      Icons.wifi_off_rounded,
                      'Unable to load listings',
                      listing.error!,
                    ),
                  )
                else if (listing.filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(
                      context,
                      Icons.shopping_bag_outlined,
                      'No matching items found',
                      'Try clearing filters or searching for another item or area.',
                      actionLabel: listing.activeFilterCount > 0 || listing.query.isNotEmpty || listing.category != 'All'
                          ? 'Clear filters'
                          : null,
                      onAction: listing.resetAllFilters,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _ListingCard(listing: listing.filtered[i]),
                        childCount: listing.filtered.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 235,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.70,
                      ),
                    ),
                  ),
                if (!listing.loading && listing.hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 110),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: listing.isFetchingMore ? null : listing.loadMore,
                          icon: listing.isFetchingMore
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            listing.isFetchingMore ? 'Loading more...' : 'Load more items',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerActionButton({
    required BuildContext context,
    required bool isDark,
    required int badgeCount,
    required Color badgeColor,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE6E4DC),
              ),
            ),
            child: Center(child: child),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _categoryChipIcon(String category) {
    switch (category) {
      case 'All':
        return Icons.grid_view_rounded;
      case 'Books':
        return Icons.menu_book_rounded;
      case 'Electronics':
        return Icons.devices_other_rounded;
      case 'Fashion':
        return Icons.checkroom_rounded;
      case 'Sports':
        return Icons.sports_basketball_rounded;
      case 'Furniture':
        return Icons.chair_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _emptyState(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF9A9FAF)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777D8E)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatefulWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final provider = context.watch<ListingProvider>();
    final isFavorite = provider.favoriteIds.contains(listing.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoCount = listing.galleryImages.length;
    final condColor = listing.condition == 'new' || listing.condition == 'like-new'
        ? const Color(0xFF24A889)
        : const Color(0xFF667B72);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => ListingDetailSheet.show(context, listing),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: _hovered
              ? Matrix4.translationValues(0, -3, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF667B72).withValues(alpha: 0.65)
                  : (isDark ? const Color(0xFF2E3442) : const Color(0xFFE8E6DE)),
              width: _hovered ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Color.fromRGBO(0, 0, 0, _hovered ? 0.35 : 0.16)
                    : Color.fromRGBO(37, 40, 50, _hovered ? 0.10 : 0.04),
                blurRadius: _hovered ? 18 : 10,
                offset: Offset(0, _hovered ? 8 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: _categoryGradient(listing.category),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: SmartListingImage(
                          imageUrl: listing.imageUrl,
                          fit: BoxFit.cover,
                          fallback: _categoryIcon(listing.category),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 11,
                      right: 11,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E222B).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Color(0x18000000), blurRadius: 6),
                          ],
                        ),
                        child: Center(
                          child: SpringHeartIcon(
                            isFavorite: isFavorite,
                            onTap: () async {
                              final ok = await provider.toggleFavorite(listing);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Sign in to save favourite items'),
                                    action: SnackBarAction(
                                      label: 'Sign in',
                                      onPressed: () => context.read<AuthProvider>().exitGuestMode(),
                                    ),
                                  ),
                                );
                              }
                            },
                            size: 17,
                            activeColor: const Color(0xFFC69C55),
                            inactiveColor: isDark ? Colors.white70 : const Color(0xFF3D4152),
                          ),
                        ),
                      ),
                    ),
                    if (photoCount > 1)
                      Positioned(
                        bottom: 11,
                        right: 11,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, color: Colors.white, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                '$photoCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!listing.isAvailable)
                      Positioned(
                        bottom: 11,
                        left: 11,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: listing.isReserved
                                ? const Color(0xFFF2A14A)
                                : const Color(0xFF252832),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            listing.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 2, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: condColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_outlined, size: 10, color: condColor),
                              const SizedBox(width: 3),
                              Text(
                                listing.condition,
                                style: TextStyle(
                                  color: condColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.place_outlined, size: 11, color: Color(0xFF7D8394)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${listing.location} · ${AppFormatters.formatRelativeTime(listing.createdAt?.toDate())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF7D8394),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            AppFormatters.formatBDT(listing.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.price(
                              size: 16.5,
                              color: isDark ? Colors.white : const Color(0xFF252832),
                            ),
                          ),
                        ),
                        if (listing.negotiable)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handshake_outlined, size: 11, color: Color(0xFF24A889)),
                              SizedBox(width: 3),
                              Text(
                                'Neg.',
                                style: TextStyle(
                                  color: Color(0xFF24A889),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryIcon(String category) {
    final icons = {
      'Books': Icons.menu_book_rounded,
      'Electronics': Icons.devices_other_rounded,
      'Fashion': Icons.checkroom_rounded,
      'Sports': Icons.sports_basketball_rounded,
      'Furniture': Icons.chair_rounded,
    };
    return Center(
      child: Icon(
        icons[category] ?? Icons.category_rounded,
        size: 52,
        color: Colors.white.withValues(alpha: 0.92),
      ),
    );
  }

  LinearGradient _categoryGradient(String category) {
    const palettes = {
      'Books': [Color(0xFF4E5A58), Color(0xFF7C8986)],
      'Electronics': [Color(0xFF667B72), Color(0xFF91A49D)],
      'Fashion': [Color(0xFF9A815A), Color(0xFFBEA984)],
      'Sports': [Color(0xFF4A5565), Color(0xFF818B99)],
      'Furniture': [Color(0xFF806D57), Color(0xFFA99980)],
      'Other': [Color(0xFF697184), Color(0xFFA1A7B5)],
    };
    final colors = palettes[category] ?? palettes['Other']!;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }
}

class ListingDetailSheet extends StatefulWidget {
  final Listing listing;
  final bool isDesktopDialog;

  const ListingDetailSheet({
    super.key,
    required this.listing,
    this.isDesktopDialog = false,
  });

  /// Shows a responsive Split-Pane Dialog on Desktop (>= 780px) or Sheet on Mobile.
  static Future<void> show(BuildContext context, Listing listing) {
    final isWide = MediaQuery.sizeOf(context).width >= 780;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ListingDetailSheet(listing: listing, isDesktopDialog: true),
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingDetailSheet(listing: listing),
    );
  }

  @override
  State<ListingDetailSheet> createState() => _ListingDetailSheetState();
}

class _ListingDetailSheetState extends State<ListingDetailSheet> {
  final amount = TextEditingController();
  final message = TextEditingController();
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    amount.text = widget.listing.price.toString();
  }

  @override
  void dispose() {
    amount.dispose();
    message.dispose();
    super.dispose();
  }

  void _openDirectChat(BuildContext context, User currentUser) {
    final buyerId = currentUser.uid;
    final buyerName = currentUser.displayName ?? 'Buyer';
    final threadId = context.read<ChatProvider>().threadIdFor(widget.listing.id, buyerId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingChatScreen(
          threadId: threadId,
          listingId: widget.listing.id,
          listingTitle: widget.listing.title,
          listingPrice: widget.listing.price,
          buyerId: buyerId,
          buyerName: buyerName,
          sellerId: widget.listing.sellerId,
          sellerName: widget.listing.sellerName,
        ),
      ),
    );
  }

  Widget _buildStickyActionBar(
    BuildContext context,
    OfferProvider offers,
    User? currentUser,
    bool isOwner,
    bool isDark,
  ) {
    final isGuest = currentUser == null;
    if (isGuest) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE7E4DC)),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().exitGuestMode();
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Sign In to Chat or Make Offer'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF252832),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
    }

    if (isOwner || !widget.listing.isAvailable) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE7E4DC)),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _openDirectChat(context, currentUser),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Chat'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: submitting || offers.busy ? null : () => _handleSubmitOffer(context, offers),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF252832),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: submitting || offers.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.listing.negotiable
                          ? 'Submit Offer'
                          : 'Order at ${AppFormatters.formatBDT(widget.listing.price)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsColumn(
    BuildContext context,
    ListingProvider listingProvider,
    bool isOwner,
    bool isDark, {
    bool includeGallery = true,
    ScrollController? controller,
  }) {
    final createdDate = widget.listing.createdAt?.toDate();
    final askPrice = widget.listing.price;
    final offer90 = ((askPrice * 0.90) / 10).round() * 10;
    final offer95 = ((askPrice * 0.95) / 10).round() * 10;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        if (!widget.isDesktopDialog)
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        if (includeGallery) ...[
          ListingPhotoGallery(
            images: widget.listing.galleryImages,
            height: 230,
            fallback: const Center(
              child: Icon(Icons.inventory_2_outlined, size: 54, color: Color(0xFF667B72)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.listing.title,
                style: AppTypography.display(
                  size: 23,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF252832),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _statusChip(widget.listing.status),
            IconButton(
              tooltip: 'Copy shareable listing link',
              icon: const Icon(Icons.share_outlined, size: 20),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final shareUrl =
                    'https://pass-it-on-2f422.web.app/?listing=${widget.listing.id}';
                await Clipboard.setData(ClipboardData(text: shareUrl));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Shareable listing link copied to clipboard'),
                  ),
                );
              },
            ),
            if (!isOwner && FirebaseAuth.instance.currentUser != null)
              IconButton(
                tooltip: 'Report listing',
                icon: const Icon(
                  Icons.flag_outlined,
                  size: 20,
                  color: Color(0xFFD94B64),
                ),
                onPressed: () => ReportSheet.show(
                  context,
                  targetType: 'listing',
                  targetId: widget.listing.id,
                  targetTitle: widget.listing.title,
                  targetUserId: widget.listing.sellerId,
                ),
              ),
            if (widget.isDesktopDialog) ...[
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              AppFormatters.formatBDT(widget.listing.price),
              style: AppTypography.price(
                size: 26,
                color: isDark ? Colors.white : const Color(0xFF252832),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: widget.listing.negotiable
                    ? const Color(0xFF24A889).withValues(alpha: 0.14)
                    : const Color(0xFF626779).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.listing.negotiable
                        ? Icons.handshake_outlined
                        : Icons.lock_outline_rounded,
                    size: 12,
                    color: widget.listing.negotiable
                        ? const Color(0xFF24A889)
                        : (isDark ? Colors.grey.shade300 : const Color(0xFF626779)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.listing.negotiable ? 'Negotiable' : 'Fixed Price',
                    style: TextStyle(
                      color: widget.listing.negotiable
                          ? const Color(0xFF24A889)
                          : (isDark ? Colors.grey.shade300 : const Color(0xFF626779)),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF777D8E)),
            const SizedBox(width: 4),
            Text(
              '${widget.listing.location} · Posted ${AppFormatters.formatRelativeTime(createdDate)}',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.listing.description,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : const Color(0xFF4B505E),
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _infoTile('Category', widget.listing.category, Icons.category_outlined, isDark),
            const SizedBox(width: 10),
            _infoTile('Condition', widget.listing.condition, Icons.auto_awesome_outlined, isDark),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => SellerProfileSheet.show(
            context,
            sellerId: widget.listing.sellerId,
            sellerName: widget.listing.sellerName,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF262C38) : const Color(0xFFF0EBDC),
                  child: Text(
                    widget.listing.sellerName.isEmpty
                        ? '?'
                        : widget.listing.sellerName[0].toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF252832),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.listing.sellerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'View seller rating, reviews & active items',
                        style: TextStyle(fontSize: 12, color: Color(0xFF667B72)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final ok = await listingProvider.toggleFavorite(widget.listing);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sign in to save items')),
                      );
                    }
                  },
                  icon: Icon(
                    listingProvider.favoriteIds.contains(widget.listing.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: const Color(0xFFC69C55),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isOwner && widget.listing.isAvailable && FirebaseAuth.instance.currentUser != null) ...[
          const SizedBox(height: 14),
          if (widget.listing.negotiable) ...[
            const Text(
              'Quick Offer Presets',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF667B72)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (offer90 > 0 && offer90 < askPrice)
                  ActionChip(
                    label: Text('-10% (${AppFormatters.formatBDT(offer90)})', style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => amount.text = offer90.toString()),
                  ),
                if (offer95 > 0 && offer95 < askPrice)
                  ActionChip(
                    label: Text('-5% (${AppFormatters.formatBDT(offer95)})', style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => amount.text = offer95.toString()),
                  ),
                ActionChip(
                  label: Text('Ask (${AppFormatters.formatBDT(askPrice)})', style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => amount.text = askPrice.toString()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Your offer (৳)', Icons.payments_outlined, isDark),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: message,
            maxLines: 2,
            decoration: _inputDecoration(
              'Pickup preference or note (optional)',
              Icons.message_outlined,
              isDark,
            ),
          ),
        ],
        if (isOwner)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Manage or edit this listing from the Sell tab.',
              style: TextStyle(color: Color(0xFF777D8E)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<OfferProvider>();
    final listingProvider = context.watch<ListingProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.listing.sellerId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isDesktopDialog) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 620),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F9FD),
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: isDark ? const Color(0xFF13151A) : const Color(0xFFEFEDE7),
                    child: Center(
                      child: ListingPhotoGallery(
                        images: widget.listing.galleryImages,
                        height: 520,
                        fallback: const Center(
                          child: Icon(Icons.inventory_2_outlined, size: 72, color: Color(0xFF667B72)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildDetailsColumn(
                          context,
                          listingProvider,
                          isOwner,
                          isDark,
                          includeGallery: false,
                        ),
                      ),
                      _buildStickyActionBar(context, offers, currentUser, isOwner, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F9FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _buildDetailsColumn(
                    context,
                    listingProvider,
                    isOwner,
                    isDark,
                    includeGallery: true,
                    controller: scrollController,
                  ),
                ),
                _buildStickyActionBar(context, offers, currentUser, isOwner, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmitOffer(BuildContext context, OfferProvider offers) async {
    final value = widget.listing.negotiable
        ? int.tryParse(amount.text.trim())
        : widget.listing.price;
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid offer amount greater than zero')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final admin = context.read<AdminProvider>();

    // Check live listing & eligibility BEFORE collecting order fee!
    final preCheckError = await offers.verifyOfferEligibility(widget.listing);
    if (preCheckError != null) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(preCheckError)));
      }
      return;
    }

    final feeSettings = admin.feeSettings;
    String feeTxnId = '';
    String? paymentDocId;

    if (feeSettings.feesEnabled && feeSettings.buyerOrderFee > 0) {
      if (!context.mounted) return;
      final payment = await PaymentCheckoutSheet.show(
        context,
        title: 'Escrow Order Processing Fee',
        subtitle: 'Auto-refunded in ledger if seller declines or cancels',
        feeType: 'buyer_order_fee',
        amount: feeSettings.buyerOrderFee,
        referenceId: widget.listing.id,
        referenceTitle: widget.listing.title,
      );
      if (payment == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Payment cancelled. Offer was not submitted.')),
          );
        }
        return;
      }
      feeTxnId = payment.transactionId;
      paymentDocId = payment.id;
    }

    setState(() => submitting = true);
    try {
      final ok = await offers.makeOffer(
        widget.listing,
        value,
        message.text,
        feePaid: feeTxnId.isNotEmpty,
        feeTransactionId: feeTxnId,
        paymentId: paymentDocId ?? '',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (feeTxnId.isNotEmpty
                    ? 'Order secured (Txn: $feeTxnId). Offer submitted!'
                    : 'Offer sent!')
                : '${offers.error ?? 'Could not send offer'}${paymentDocId != null ? ' (Ref: $feeTxnId)' : ''}',
          ),
        ),
      );
      if (ok) navigator.pop();
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Widget _statusChip(String status) {
    final color = status == 'available'
        ? const Color(0xFF24A889)
        : status == 'reserved'
            ? const Color(0xFFF2A14A)
            : const Color(0xFF777D8E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, bool isDark) =>
      Expanded(
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 12, color: const Color(0xFF667B72)),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF9196A4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
