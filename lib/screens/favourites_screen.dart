import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../widgets/animated_ui.dart';
import '../widgets/smart_image.dart';
import 'browse_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final listingProvider = context.watch<ListingProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allFavorites = listingProvider.favoriteListings;
    final favorites = allFavorites.where((l) {
      if (_query.isEmpty) return true;
      return l.title.toLowerCase().contains(_query.toLowerCase()) ||
          l.category.toLowerCase().contains(_query.toLowerCase()) ||
          l.description.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC69C55).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFC69C55),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Favourites',
                            style: AppTypography.display(size: 26),
                          ),
                          Text(
                            '${allFavorites.length} saved items',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (allFavorites.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Filter your saved items...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            if (favorites.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC69C55).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_outline_rounded,
                            size: 44,
                            color: Color(0xFFC69C55),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _query.isNotEmpty ? 'No matches in favourites' : 'No saved items yet',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _query.isNotEmpty
                              ? 'Try searching with a different keyword.'
                              : 'Tap the heart icon on any listing while browsing the campus marketplace to save items for quick negotiation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.explore_rounded),
                          label: const Text('Explore Marketplace'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF252832),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList.separated(
                  itemCount: favorites.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = favorites[i];
                    return StaggeredSlideFade(
                      index: i,
                      child: _FavouriteItemCard(
                        listing: item,
                        onTap: () => ListingDetailSheet.show(context, item),
                        onRemove: () async {
                          await listingProvider.toggleFavorite(item);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed "${item.title}" from favourites'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => listingProvider.toggleFavorite(item),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavouriteItemCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavouriteItemCard({
    required this.listing,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3442) : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33000000) : const Color(0x0C000000),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFF667B72).withValues(alpha: 0.15),
                child: SmartListingImage(
                  imageUrl: listing.imageUrl,
                  fit: BoxFit.cover,
                  fallback: const Center(
                    child: Icon(Icons.category_rounded, size: 36, color: Color(0xFF667B72)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _statusBadge(listing.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.sell_outlined, size: 12, color: Color(0xFF858A99)),
                      const SizedBox(width: 4),
                      Text(
                        '${listing.category} · ${listing.condition}',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF858A99),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppFormatters.formatBDT(listing.price),
                        style: AppTypography.price(
                          size: 18,
                          color: isDark ? Colors.white : const Color(0xFF252832),
                        ),
                      ),
                      SpringHeartIcon(
                        isFavorite: true,
                        onTap: onRemove,
                        size: 20,
                        activeColor: const Color(0xFFC69C55),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'available'
        ? const Color(0xFF24A889)
        : status == 'reserved'
            ? const Color(0xFFF2A14A)
            : const Color(0xFF777D8E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingStatusDot(color: color, size: 6),
          const SizedBox(width: 5),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
