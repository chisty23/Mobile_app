import 'package:firebase_auth/firebase_auth.dart';
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
                                      final me = FirebaseAuth.instance.currentUser;
                                      final dir = context.watch<ProfileDirectoryProvider>();
                                      final myName = me == null
                                          ? 'Manage prices & photos'
                                          : dir.nameFor(
                                              me.uid,
                                              fallback: me.displayName ?? 'Seller',
                                            );
                                      return Row(
                                        children: [
                                          if (me != null) ...[
                                            UserAvatar(
                                              uid: me.uid,
                                              name: myName,
                                              radius: 10,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Flexible(
                                            child: Text(
                                              me == null
                                                  ? 'Manage prices, photos, and availability'
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
            child: Container(
              width: 68,
              height: 68,
              color: const Color(0xFF667B72).withValues(alpha: 0.14),
              child: SmartListingImage(
                imageUrl: listing.imageUrl,
                fit: BoxFit.cover,
                fallback: const Center(
                  child: Icon(Icons.inventory_2_outlined, color: Color(0xFF667B72)),
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
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
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
                      'This removes it permanently from the marketplace.',
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
                if (confirmed == true) await provider.deleteListing(listing);
              } else if (value == 'available') {
                await provider.updateStatus(listing, 'available');
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
                  await provider.updateStatus(listing, 'sold');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          hasBuyer
                              ? 'Sale completed! Verified profile stats updated.'
                              : 'Listing marked as sold.',
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
  final List<String> _photos = [];
  bool _pickingPhotos = false;
  bool _showAdvancedLinks = false;

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

  Future<void> _pickPhotosFromDevice() async {
    final remaining = 3 - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos per listing')),
      );
      return;
    }
    setState(() => _pickingPhotos = true);
    try {
      final picked = await pickCompressedImages(maxCount: remaining);
      if (picked.isNotEmpty && mounted) {
        setState(() => _photos.addAll(picked.take(remaining)));
      }
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  void _addPhotoUrl() {
    final raw = imageUrl.text.trim();
    if (raw.isEmpty || Uri.tryParse(raw)?.hasScheme != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid http/https image link')),
      );
      return;
    }
    if (_photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos per listing')),
      );
      return;
    }
    setState(() {
      _photos.add(raw);
      imageUrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.editing != null;

    final relevantPresets = PresetCatalog.presets
        .where((p) => p.category.toLowerCase() == category.toLowerCase())
        .toList();

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
                              final me = FirebaseAuth.instance.currentUser;
                              final dir = context.watch<ProfileDirectoryProvider>();
                              final myName = me == null
                                  ? 'Seller'
                                  : dir.nameFor(
                                      me.uid,
                                      fallback: me.displayName ?? 'Seller',
                                    );
                              return Row(
                                children: [
                                  if (me != null) ...[
                                    UserAvatar(
                                      uid: me.uid,
                                      name: myName,
                                      radius: 10,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Text(
                                      isEditing
                                          ? 'Update item details, pricing, or photos.'
                                          : 'Posting publicly as $myName · Up to 3 photos.',
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
                // Hero Photo Dropzone Box
                InkWell(
                  onTap: _pickingPhotos ? null : _pickPhotosFromDevice,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF667B72).withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_pickingPhotos)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(Icons.add_a_photo_outlined, color: Color(0xFF667B72), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Upload Item Photos (${_photos.length}/3)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Items with real photos sell 4x faster — tap to add from device',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF777D8E)),
                        ),
                        if (_photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
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
                                        fallback: const Icon(Icons.broken_image_outlined),
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
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
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
                        ],
                      ],
                    ),
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
                        decoration: _decoration('Category', Icons.category_outlined, isDark),
                        items: const [
                          'Books',
                          'Electronics',
                          'Fashion',
                          'Sports',
                          'Furniture',
                          'Other',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (value) => setState(() => category = value ?? 'Books'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: condition,
                        decoration: _decoration('Condition', Icons.auto_awesome_outlined, isDark),
                        items: const ['new', 'like-new', 'used', 'worn']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) => setState(() => condition = value ?? 'used'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: location,
                  decoration: _decoration('Campus / Pickup Location', Icons.location_on_outlined, isDark),
                  items: AppFormatters.listingLocations
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _showAdvancedLinks = !_showAdvancedLinks),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvancedLinks ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: const Color(0xFF667B72),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Or add photo via URL / category preset',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF667B72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAdvancedLinks) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in (relevantPresets.isNotEmpty
                            ? relevantPresets
                            : PresetCatalog.presets))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.photo_camera_outlined, size: 15),
                              label: Text(p.name, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                if (_photos.length < 3 && !_photos.contains(p.imageUrl)) {
                                  setState(() => _photos.add(p.imageUrl));
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: imageUrl,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: 'Paste Image Link (optional)',
                            prefixIcon: const Icon(Icons.link_rounded),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addPhotoUrl,
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
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: negotiable,
                  onChanged: (value) => setState(() => negotiable = value),
                  title: const Text('Price is negotiable'),
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
      paymentId: paymentDocId ?? '',
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
