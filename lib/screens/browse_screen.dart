import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final listing = context.watch<ListingProvider>();
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Discover',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Find something worth passing on',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            sliver: SliverToBoxAdapter(
              child: TextField(
                onChanged: listing.setQuery,
                decoration: InputDecoration(
                  hintText: 'Search books, bikes, gadgets...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: const Icon(Icons.tune_rounded),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.88),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(left: 20),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final item in [
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
                          label: Text(item),
                          selected: listing.category == item,
                          selectedColor: const Color(0xFF252832),
                          labelStyle: TextStyle(
                            color: listing.category == item
                                ? Colors.white
                                : const Color(0xFF626779),
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => listing.setCategory(item),
                          side: BorderSide.none,
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    '${listing.filtered.length} items',
                    style: const TextStyle(
                      color: Color(0xFF777D8E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    initialValue: listing.sort,
                    onSelected: listing.setSort,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Newest', child: Text('Newest')),
                      PopupMenuItem(
                        value: 'Price low',
                        child: Text('Price: low to high'),
                      ),
                      PopupMenuItem(
                        value: 'Price high',
                        child: Text('Price: high to low'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sort_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Sort',
                            style: TextStyle(fontWeight: FontWeight.w700),
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
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (listing.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(
                context,
                Icons.wifi_off_rounded,
                'Poor internet connection',
                listing.error!,
              ),
            )
          else if (listing.filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(
                context,
                Icons.shopping_bag_outlined,
                'No listings yet',
                'Try another search or category.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ListingCard(listing: listing.filtered[i]),
                  childCount: listing.filtered.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
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
          Text(subtitle, style: const TextStyle(color: Color(0xFF777D8E))),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    final isFavorite = provider.favoriteIds.contains(listing.id);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ListingDetailSheet(listing: listing),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: _categoryGradient(listing.category),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:
                            listing.imageUrl.isNotEmpty &&
                                Uri.tryParse(listing.imageUrl)?.hasScheme ==
                                    true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  listing.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _categoryIcon(listing.category),
                                ),
                              )
                            : _categoryIcon(listing.category),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: GestureDetector(
                          onTap: () => provider.toggleFavorite(listing),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 19,
                              color: isFavorite
                                  ? const Color(0xFFC69C55)
                                  : const Color(0xFF3D4152),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${listing.category} · ${listing.condition}',
                        style: const TextStyle(
                          color: Color(0xFF858A99),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_money(listing.price)} ৳',
                        style: const TextStyle(
                          color: Color(0xFF252832),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        size: 56,
        color: Colors.white.withValues(alpha: 0.94),
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
  const ListingDetailSheet({super.key, required this.listing});

  @override
  State<ListingDetailSheet> createState() => _ListingDetailSheetState();
}

class _ListingDetailSheetState extends State<ListingDetailSheet> {
  final amount = TextEditingController();
  final message = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    amount.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offers = context.watch<OfferProvider>();
    final listingProvider = context.watch<ListingProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.listing.sellerId;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.listing.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _statusChip(widget.listing.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_money(widget.listing.price)} ৳',
              style: const TextStyle(
                color: const Color(0xFF252832),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.listing.description,
                style: const TextStyle(color: Color(0xFF5E6372), height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _infoTile('Category', widget.listing.category),
                const SizedBox(width: 10),
                _infoTile('Condition', widget.listing.condition),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFF0EBDC),
                child: Text(
                  widget.listing.sellerName.isEmpty
                      ? '?'
                      : widget.listing.sellerName[0],
                ),
              ),
              title: Text(
                widget.listing.sellerName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Seller'),
              trailing: IconButton(
                onPressed: () => listingProvider.toggleFavorite(widget.listing),
                icon: Icon(
                  listingProvider.favoriteIds.contains(widget.listing.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: const Color(0xFFC69C55),
                ),
              ),
            ),
            if (!isOwner && widget.listing.isAvailable) ...[
              const SizedBox(height: 14),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Your offer (৳)', Icons.payments),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: message,
                maxLines: 2,
                decoration: _inputDecoration(
                  'Short message',
                  Icons.message_outlined,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: submitting || offers.busy
                      ? null
                      : () async {
                          final value = int.tryParse(amount.text.trim());
                          if (value == null) return;
                          setState(() => submitting = true);
                          try {
                            final ok = await offers.makeOffer(
                              widget.listing,
                              value,
                              message.text,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Offer sent'
                                      : offers.error ?? 'Could not send offer',
                                ),
                              ),
                            );
                            if (ok) Navigator.pop(context);
                          } finally {
                            if (mounted) {
                              setState(() => submitting = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF252832),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: submitting || offers.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Make offer',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  amount.text = widget.listing.price.toString();
                  setState(() {});
                },
                child: const Text('Use asking price'),
              ),
            ],
            if (isOwner)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Manage this listing from the Sell tab.',
                  style: TextStyle(color: Color(0xFF777D8E)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'available'
        ? const Color(0xFF24A889)
        : status == 'reserved'
        ? const Color(0xFFF2A14A)
        : const Color(0xFF777D8E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _infoTile(String label, String value) => Expanded(
    child: Container(
      height: 72,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9196A4), fontSize: 12),
          ),
          const SizedBox(height: 5),
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

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}

String _money(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final pos = text.length - i;
    buffer.write(text[i]);
    if (pos > 1 && pos % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
