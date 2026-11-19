import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';

class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellProvider>();
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your listings',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6552FF), Color(0xFF8172FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const CreateListingSheet(),
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      tooltip: 'Create listing',
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
                    const Text(
                      'Create your first listing.',
                      style: TextStyle(color: Color(0xFF777D8E)),
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
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              sliver: SliverList.separated(
                itemCount: provider.myListings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _MyListingCard(listing: provider.myListings[i]),
              ),
            ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6552FF), Color(0xFF24C3A6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
                const SizedBox(height: 6),
                Text(
                  '${listing.price} ৳',
                  style: const TextStyle(
                    color: Color(0xFF6552FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete listing?'),
                    content: const Text(
                      'This removes it from the marketplace.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await provider.deleteListing(listing);
              } else if (value == 'available') {
                await provider.updateStatus(listing, 'available');
              } else if (value == 'sold') {
                await provider.updateStatus(listing, 'sold');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'available',
                child: Text('Release / Available'),
              ),
              PopupMenuItem(value: 'sold', child: Text('Mark sold')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class CreateListingSheet extends StatefulWidget {
  const CreateListingSheet({super.key});

  @override
  State<CreateListingSheet> createState() => _CreateListingSheetState();
}

class _CreateListingSheetState extends State<CreateListingSheet> {
  final title = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final imageUrl = TextEditingController();
  String category = 'Books';
  String condition = 'used';
  bool negotiable = true;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellProvider>();
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
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
          const SizedBox(height: 16),
          const Text(
            'Create a listing',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: title,
            decoration: _decoration('Title', Icons.title_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: _decoration('Description', Icons.notes_rounded),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: _decoration('Category', Icons.category_outlined),
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
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: condition,
            decoration: _decoration('Condition', Icons.auto_awesome_outlined),
            items: const [
              'new',
              'like-new',
              'used',
              'worn',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => condition = value ?? 'used'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: _decoration('Price (৳)', Icons.payments_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: imageUrl,
            keyboardType: TextInputType.url,
            decoration: _decoration(
              'Optional pasted image link',
              Icons.link_rounded,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: negotiable,
            onChanged: (value) => setState(() => negotiable = value),
            title: const Text('Price is negotiable'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: provider.busy
                  ? null
                  : () async {
                      final value = int.tryParse(price.text.trim());
                      if (value == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid positive price'),
                          ),
                        );
                        return;
                      }
                      final ok = await provider.createListing(
                        title: title.text,
                        description: description.text,
                        category: category,
                        condition: condition,
                        price: value,
                        negotiable: negotiable,
                        imageUrl: imageUrl.text,
                      );
                      if (context.mounted) {
                        if (ok) Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Listing published'
                                  : provider.error ?? 'Error',
                            ),
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6552FF),
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
                  : const Text(
                      'Publish listing',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
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
