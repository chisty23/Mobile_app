import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfferProvider>();
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Offers',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: tabs,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF252832),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorPadding: const EdgeInsets.all(5),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF777D8E),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: 'Made'),
                  Tab(text: 'Received'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _OfferList(offers: provider.made, received: false),
                _OfferList(offers: provider.received, received: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferList extends StatelessWidget {
  final List<MarketOffer> offers;
  final bool received;
  const _OfferList({required this.offers, required this.received});

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.handshake_outlined,
              size: 54,
              color: Color(0xFF9A9FAF),
            ),
            const SizedBox(height: 12),
            Text(
              received ? 'No offers received' : 'No offers made',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your marketplace activity appears here.',
              style: TextStyle(color: Color(0xFF777D8E)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _OfferCard(offer: offers[i], received: received),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final MarketOffer offer;
  final bool received;
  const _OfferCard({required this.offer, required this.received});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfferProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusChip(offer.isExpired ? 'expired' : offer.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(received ? 'Offer from ${offer.buyerName}' : 'Your offer'),
          const SizedBox(height: 4),
          Text(
            '${offer.amount} ৳',
            style: const TextStyle(
              color: Color(0xFF252832),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (offer.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“${offer.message}”',
              style: const TextStyle(color: Color(0xFF777D8E), height: 1.35),
            ),
          ],
          if (!offer.isExpired &&
              (offer.status == 'pending' || offer.status == 'countered')) ...[
            const SizedBox(height: 12),
            if (received)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.busy
                          ? null
                          : () async {
                              final ok = await provider.transition(
                                offer,
                                'decline',
                              );
                              _snack(context, ok, provider.error);
                            },
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: provider.busy
                          ? null
                          : () async {
                              final ok = await provider.transition(
                                offer,
                                'accept',
                              );
                              _snack(context, ok, provider.error);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF252832),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: provider.busy
                        ? null
                        : () => _showCounter(context, offer, provider),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    tooltip: 'Counter',
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.busy
                          ? null
                          : () async {
                              final ok = await provider.transition(
                                offer,
                                'withdraw',
                              );
                              _snack(context, ok, provider.error);
                            },
                      child: const Text('Withdraw'),
                    ),
                  ),
                  if (offer.status == 'countered') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: provider.busy
                            ? null
                            : () async {
                                final ok = await provider.transition(
                                  offer,
                                  'acceptCounter',
                                );
                                _snack(context, ok, provider.error);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF24A889),
                        ),
                        child: const Text('Accept counter'),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  void _showCounter(
    BuildContext context,
    MarketOffer offer,
    OfferProvider provider,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Counter offer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New amount',
            prefixText: '৳ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = int.tryParse(controller.text.trim());
              if (amount == null) return;
              final ok = await provider.counterOffer(offer, amount);
              if (context.mounted) Navigator.pop(context);
              _snack(context, ok, provider.error);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, bool ok, String? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Offer updated' : error ?? 'Action failed')),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(1)}',
    );
    final color = status == 'accepted'
        ? const Color(0xFF24A889)
        : status == 'pending' || status == 'countered'
        ? const Color(0xFFF2A14A)
        : status == 'expired'
        ? const Color(0xFF777D8E)
        : const Color(0xFFD94B64);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
