import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../utils/photo_picker.dart';
import '../widgets/animated_ui.dart';
import '../widgets/payment_checkout_sheet.dart';
import '../widgets/smart_image.dart';
import '../widgets/user_avatar.dart';

class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: CustomScrollView(
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
                                color: const Color(0xFF667B72).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFF667B72),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your listings',
                                    style: AppTypography.display(
                                      size: 28,
                                      letterSpacing: -0.6,
                                      color: isDark ? Colors.white : const Color(0xFF252832),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Builder(
                                    builder: (context) {
                                      final auth = context.watch<AuthProvider>();
                                      final me = auth.uid;
                                      final dir = context.watch<ProfileDirectoryProvider>();
                                      final myName = me == null
                                          ? 'Manage prices & photos'
                                          : dir.nameFor(
                                              me,
                                              fallback: auth.displayName,
                                            );
                                      return Row(
                                        children: [
                                          if (me != null) ...[
                                            UserAvatar(
                                              uid: me,
                                              name: myName,
                                              radius: 10,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Flexible(
                                            child: Text(
                                              me == null
                                                  ? 'Manage prices, links, and availability'
                                                  : 'Posting as $myName · Manage items',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : const Color(0xFF6A7080),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      BouncyTap(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const CreateListingSheet(),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF252832), Color(0xFF667B72)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 4),
                              Text(
                                'Post Item',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.myListings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 54,
                            color: Color(0xFF9A9FAF),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your shop is empty',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Upload real photos and list items to reach buyers nearby.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const CreateListingSheet(),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Create listing'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF252832),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: provider.myListings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _MyListingCard(listing: provider.myListings[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  final Listing listing;
  const _MyListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellProvider>();
    final pendingCount = provider.pendingOfferCountFor(listing.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3442) : const Color(0xFFEBE9E1),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 68,
              height: 68,
              child: SmartListingImage(
                imageUrl: listing.imageUrl,
                fit: BoxFit.cover,
                fallback: ListingCategoryArtwork.fallback(
                  listing.category,
                  iconSize: 30,
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
                          fontSize: 15,
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
                    Flexible(
                      child: Text(
                        '${listing.category} · ${listing.condition}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF858A99),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.place_outlined, size: 12, color: Color(0xFF858A99)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        listing.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF858A99),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      AppFormatters.formatBDT(listing.price),
                      style: AppTypography.price(
                        size: 16,
                        color: isDark ? Colors.white : const Color(0xFF252832),
                      ),
                    ),
                    if (listing.galleryImages.length > 1) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.photo_library_outlined, size: 12, color: Color(0xFF667B72)),
                      const SizedBox(width: 3),
                      Text(
                        '${listing.galleryImages.length} photos',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667B72),
                        ),
                      ),
                    ],
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2A14A).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$pendingCount active ${pendingCount == 1 ? 'offer' : 'offers'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD9822B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !provider.busy,
            onSelected: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              if (value == 'edit') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CreateListingSheet(editing: listing),
                );
              } else if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete listing?'),
                    content: const Text(
                      'This removes it from Discover and keeps saved history safely flagged.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD94B64),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ok = await provider.deleteListing(listing);
                  if (context.mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Listing deleted.' : (provider.error ?? 'Could not delete listing'),
                        ),
                      ),
                    );
                  }
                }
              } else if (value == 'reserve') {
                final ok = await provider.reserveListing(listing);
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Listing marked reserved.'
                            : (provider.error ?? 'Could not reserve listing'),
                      ),
                    ),
                  );
                }
              } else if (value == 'available') {
                final ok = await provider.releaseReservedListing(listing);
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Listing is available again.'
                            : (provider.error ?? 'Could not release listing'),
                      ),
                    ),
                  );
                }
              } else if (value == 'sold') {
                final hasBuyer = listing.reservedFor.isNotEmpty;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Mark as Sold?'),
                    content: Text(
                      hasBuyer
                          ? 'Finalizing this verified sale will mark the listing sold and update profile stats.'
                          : 'No active buyer offer is linked. Marking sold will archive the item from Discover (without incrementing verified sales count).',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirm Sold'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ok = await provider.markSold(listing);
                  if (context.mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? (hasBuyer
                                  ? 'Sale completed! Verified profile stats updated.'
                                  : 'Listing marked as sold.')
                              : (provider.error ?? 'Could not mark sold'),
                        ),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              if (!listing.isSold)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Details & Photos'),
                    ],
                  ),
                ),
              if (listing.isAvailable)
                const PopupMenuItem(
                  value: 'reserve',
                  child: Text('Reserve Listing'),
                ),
              if (listing.status != 'available')
                const PopupMenuItem(
                  value: 'available',
                  child: Text('Release / Set Available'),
                ),
              if (listing.status != 'sold')
                const PopupMenuItem(
                  value: 'sold',
                  child: Text('Mark Sold'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Listing', style: TextStyle(color: Color(0xFFD94B64))),
              ),
            ],
          ),
        ],
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CreateListingSheet extends StatefulWidget {
  final Listing? editing;
  const CreateListingSheet({super.key, this.editing});

  @override
  State<CreateListingSheet> createState() => _CreateListingSheetState();
}

class _CreateListingSheetState extends State<CreateListingSheet> {
  final _formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final imageUrl = TextEditingController();
  String category = 'Books';
  String condition = 'used';
  String location = AppFormatters.listingLocations.first;
  bool negotiable = true;
  bool _pickingPhotos = false;
  final List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    final edit = widget.editing;
    if (edit != null) {
      title.text = edit.title;
      description.text = edit.description;
      price.text = edit.price.toString();
      category = edit.category;
      condition = edit.condition;
      location = AppFormatters.listingLocations.contains(edit.location)
          ? edit.location
          : AppFormatters.listingLocations.first;
      negotiable = edit.negotiable;
      _photos.addAll(edit.galleryImages);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    imageUrl.dispose();
    super.dispose();
  }

  void _addPhotoUrl() {
    final raw = imageUrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste an external https:// image URL first')),
      );
      return;
    }
    final validationError = AppFormatters.validateOptionalHttpsImageUrl(raw);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    if (_photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos per listing')),
      );
      return;
    }
    if (_photos.contains(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This photo link is already added')),
      );
      return;
    }
    setState(() {
      _photos.add(raw);
      imageUrl.clear();
    });
  }

  Future<void> _pickDevicePhotos() async {
    if (_pickingPhotos) return;
    if (_photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos per listing')),
      );
      return;
    }
    if (!supportsDevicePhotoPicker) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Device gallery picker works on Web, Android, and iOS. On desktop, paste an https:// URL below.',
          ),
        ),
      );
      return;
    }
    setState(() => _pickingPhotos = true);
    try {
      final remaining = 3 - _photos.length;
      final picked = await pickCompressedImages(
        maxCount: remaining,
        maxDimension: 640,
      );
      if (!mounted || picked.isEmpty) return;

      var added = 0;
      var rejected = 0;
      var currentEmbeddedChars = _photos
          .where(AppFormatters.isValidDataImageUri)
          .fold<int>(0, (sum, p) => sum + p.length);

      final accepted = <String>[];
      for (final img in picked) {
        if (_photos.length + accepted.length >= 3) break;
        if (!AppFormatters.isValidImageSource(img)) {
          rejected++;
          continue;
        }
        final nextLen = AppFormatters.isValidDataImageUri(img) ? img.length : 0;
        if (currentEmbeddedChars + nextLen >
            AppFormatters.maxListingTotalImageChars) {
          rejected++;
          continue;
        }
        if (!_photos.contains(img) && !accepted.contains(img)) {
          accepted.add(img);
          currentEmbeddedChars += nextLen;
          added++;
        }
      }

      if (accepted.isNotEmpty) {
        setState(() => _photos.addAll(accepted));
      }
      if (rejected > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? '$added photo(s) added; $rejected skipped due to size limit.'
                  : 'Selected image exceeded the compact size limit; try a smaller photo or https:// URL.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.editing != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.90,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F9FD),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667B72).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
                        color: const Color(0xFF667B72),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Listing' : 'Create a Listing',
                            style: AppTypography.display(size: 24),
                          ),
                          const SizedBox(height: 3),
                          Builder(
                            builder: (context) {
                              final auth = context.watch<AuthProvider>();
                              final me = auth.uid;
                              final dir = context.watch<ProfileDirectoryProvider>();
                              final myName = me == null
                                  ? AppFormatters.unknownUserName
                                  : dir.nameFor(
                                      me,
                                      fallback: auth.displayName,
                                    );
                              return Row(
                                children: [
                                  if (me != null) ...[
                                    UserAvatar(
                                      uid: me,
                                      name: myName,
                                      radius: 10,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      isEditing
                                          ? 'Update item details, pricing, or photos.'
                                          : 'Posting publicly as $myName · Optional device photos or links.',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : const Color(0xFF777D8E),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF667B72).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Color(0xFF667B72), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Item Photos (${_photos.length}/3 optional)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Upload photos from your device or paste https:// image URLs (up to 3 total), or leave empty for category artwork.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF777D8E)),
                      ),
                      const SizedBox(height: 12),
                      if (_photos.isEmpty)
                        Container(
                          height: 108,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: ListingCategoryArtwork.gradient(category),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                ListingCategoryArtwork.iconData(category),
                                size: 42,
                                color: Colors.white.withValues(alpha: 0.94),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$category fallback artwork preview',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 86,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 10),
                            itemBuilder: (context, i) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 86,
                                    height: 86,
                                    child: SmartListingImage(
                                      imageUrl: _photos[i],
                                      fit: BoxFit.cover,
                                      fallback: ListingCategoryArtwork.fallback(category, iconSize: 28),
                                    ),
                                  ),
                                ),
                                if (i == 0)
                                  Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        'Cover',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _photos.removeAt(i)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: (_photos.length >= 3 || _pickingPhotos)
                              ? null
                              : _pickDevicePhotos,
                          icon: _pickingPhotos
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                          label: Text(
                            _pickingPhotos
                                ? 'Compressing device photo...'
                                : _photos.length >= 3
                                    ? 'Maximum 3 photos attached'
                                    : 'Choose Photo from Device',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: imageUrl,
                              keyboardType: TextInputType.url,
                              onFieldSubmitted: (_) => _addPhotoUrl(),
                              decoration: InputDecoration(
                                labelText: 'Or paste https:// image URL',
                                hintText: 'https://example.com/photo.jpg',
                                prefixIcon: const Icon(Icons.add_link_rounded),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF181B22)
                                    : const Color(0xFFF6F5F1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _photos.length >= 3 ? null : _addPhotoUrl,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF667B72),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: title,
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'Please enter a title (at least 3 characters)';
                    }
                    return null;
                  },
                  decoration: _decoration('Title', Icons.title_rounded, isDark),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().length < 5) {
                      return 'Please describe the condition and details';
                    }
                    return null;
                  },
                  decoration: _decoration('Description', Icons.notes_rounded, isDark),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        isExpanded: true,
                        decoration: _decoration('Category', Icons.category_outlined, isDark),
                        items: const [
                          'Books',
                          'Electronics',
                          'Fashion',
                          'Sports',
                          'Furniture',
                          'Other',
                        ]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => category = value ?? 'Books'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: condition,
                        isExpanded: true,
                        decoration: _decoration('Condition', Icons.auto_awesome_outlined, isDark),
                        items: const ['new', 'like-new', 'used', 'worn']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => condition = value ?? 'used'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: location,
                  isExpanded: true,
                  decoration: _decoration('Campus / Pickup Location', Icons.location_on_outlined, isDark),
                  items: AppFormatters.listingLocations
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => location = value ?? AppFormatters.listingLocations.first),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid positive price';
                    }
                    return null;
                  },
                  decoration: _decoration('Price (৳)', Icons.payments_outlined, isDark),
                ),
                const SizedBox(height: 8),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: negotiable,
                    onChanged: (value) => setState(() => negotiable = value),
                    title: const Text('Price is negotiable'),
                  ),
                ),
                if (!isEditing) ...[
                  Builder(
                    builder: (context) {
                      final feeSettings = context.watch<AdminProvider>().feeSettings;
                      final hasFee = feeSettings.feesEnabled && feeSettings.sellerListingFee > 0;
                      return Container(
                        margin: const EdgeInsets.only(top: 6, bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: hasFee
                              ? const Color(0xFFC69C55).withValues(alpha: 0.12)
                              : const Color(0xFF24A889).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasFee ? Icons.receipt_long_outlined : Icons.check_circle_outline,
                              size: 18,
                              color: hasFee ? const Color(0xFFC69C55) : const Color(0xFF24A889),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasFee
                                    ? 'Transparent Platform Fee: ${AppFormatters.formatBDT(feeSettings.sellerListingFee)} payable at checkout to go live.'
                                    : 'Free posting enabled — zero listing fees right now.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF252832),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: provider.busy
                        ? null
                        : () => _handleSubmit(context, provider, isEditing),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF252832),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: provider.busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Save Changes' : 'Publish listing',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    SellProvider provider,
    bool isEditing,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final pendingUrl = imageUrl.text.trim();
    if (pendingUrl.isNotEmpty) {
      final urlErr = AppFormatters.validateOptionalHttpsImageUrl(pendingUrl);
      if (urlErr != null) {
        messenger.showSnackBar(SnackBar(content: Text(urlErr)));
        return;
      }
      if (_photos.length < 3 && !_photos.contains(pendingUrl)) {
        _photos.add(pendingUrl);
        imageUrl.clear();
      }
    }
    final value = int.parse(price.text.trim());

    if (isEditing) {
      final ok = await provider.updateListing(
        listingId: widget.editing!.id,
        title: title.text,
        description: description.text,
        category: category,
        condition: condition,
        location: location,
        price: value,
        negotiable: negotiable,
        images: _photos,
        imageUrl: _photos.isNotEmpty ? _photos.first : '',
      );
      if (!mounted) return;
      if (ok) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok ? 'Listing updated!' : provider.error ?? 'Could not update listing'),
        ),
      );
      return;
    }

    final admin = context.read<AdminProvider>();
    final feeSettings = admin.feeSettings;
    String feeTxnId = '';
    String? paymentDocId;

    if (feeSettings.feesEnabled && feeSettings.sellerListingFee > 0) {
      final payment = await PaymentCheckoutSheet.show(
        context,
        title: 'Seller Listing Fee',
        subtitle: 'Auto-refunded in ledger if publishing fails',
        feeType: 'seller_listing_fee',
        amount: feeSettings.sellerListingFee,
        referenceId: 'new_listing',
        referenceTitle: title.text.trim(),
      );
      if (payment == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Payment cancelled. Product was not listed.')),
          );
        }
        return;
      }
      feeTxnId = payment.transactionId;
      paymentDocId = payment.id;
    }

    final ok = await provider.createListing(
      title: title.text,
      description: description.text,
      category: category,
      condition: condition,
      location: location,
      price: value,
      negotiable: negotiable,
      images: _photos,
      imageUrl: _photos.isNotEmpty ? _photos.first : '',
      feePaid: feeTxnId.isNotEmpty,
      feeTransactionId: feeTxnId,
    );

    if (!mounted) return;
    if (ok) navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (feeTxnId.isNotEmpty
                  ? 'Listing fee paid (Txn: $feeTxnId). Published to marketplace!'
                  : 'Listing published!')
              : '${provider.error ?? 'Could not create listing'}${paymentDocId != null ? ' (Ref: $feeTxnId)' : ''}',
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, bool isDark) =>
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
