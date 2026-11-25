import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../widgets/animated_ui.dart';
import 'chat_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  String _stageFilter = 'all';

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

  bool _matchesFilter(MarketOffer offer, {required bool received}) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    switch (_stageFilter) {
      case 'action':
        if (offer.isExpired) return false;
        if (received) {
          if (offer.status == 'pending') return true;
          if (offer.status == 'countered') {
            return offer.lastUpdatedBy.isNotEmpty && offer.lastUpdatedBy != uid;
          }
          return false;
        } else {
          if (offer.status == 'countered') {
            return offer.lastUpdatedBy.isEmpty || offer.lastUpdatedBy != uid;
          }
          if (offer.status == 'completed' && !offer.isRated) return true;
          return false;
        }
      case 'meetups':
        return offer.status == 'accepted';
      case 'completed':
        return offer.status == 'completed' ||
            offer.status == 'declined' ||
            offer.status == 'withdrawn' ||
            offer.isExpired;
      default:
        return true;
    }
  }

  int _countForFilter(
    List<MarketOffer> list,
    String filter, {
    required bool received,
  }) {
    final prev = _stageFilter;
    _stageFilter = filter;
    final count = list.where((o) => _matchesFilter(o, received: received)).length;
    _stageFilter = prev;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfferProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC69C55).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.handshake_rounded,
                            color: Color(0xFFC69C55),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offers & Meetups',
                                style: AppTypography.display(
                                  size: 28,
                                  letterSpacing: -0.6,
                                  color: isDark ? Colors.white : const Color(0xFF252832),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Track negotiations, escrow-protected meetups, and handover PINs',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF777D8E),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFECEAE2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TabBar(
                        controller: tabs,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: isDark ? const Color(0xFF282E3B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: isDark ? Colors.white : const Color(0xFF252832),
                        unselectedLabelColor:
                            isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.move_to_inbox_rounded, size: 17),
                                const SizedBox(width: 6),
                                const Text('Received'),
                                if (provider.received.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _tabCountBadge(
                                    provider.received.length,
                                    const Color(0xFFC69C55),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.outbox_rounded, size: 17),
                                const SizedBox(width: 6),
                                const Text('Sent'),
                                if (provider.made.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _tabCountBadge(
                                    provider.made.length,
                                    const Color(0xFF24A889),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterPill(
                            'all',
                            'All Trades',
                            isDark,
                            icon: Icons.apps_rounded,
                          ),
                          const SizedBox(width: 8),
                          _filterPill(
                            'action',
                            'Action Needed',
                            isDark,
                            icon: Icons.notification_important_outlined,
                            highlightColor: const Color(0xFFF2A14A),
                          ),
                          const SizedBox(width: 8),
                          _filterPill(
                            'meetups',
                            'Meetups & PIN',
                            isDark,
                            icon: Icons.pin_outlined,
                            highlightColor: const Color(0xFF24A889),
                          ),
                          const SizedBox(width: 8),
                          _filterPill(
                            'completed',
                            'History',
                            isDark,
                            icon: Icons.history_rounded,
                            highlightColor: const Color(0xFF777D8E),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: tabs,
                  children: [
                    _buildOfferList(
                      context,
                      provider.received,
                      received: true,
                      provider: provider,
                      isDark: isDark,
                    ),
                    _buildOfferList(
                      context,
                      provider.made,
                      received: false,
                      provider: provider,
                      isDark: isDark,
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

  Widget _tabCountBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _filterPill(
    String key,
    String label,
    bool isDark, {
    required IconData icon,
    Color? highlightColor,
  }) {
    final selected = _stageFilter == key;
    final provider = context.read<OfferProvider>();
    final activeList = tabs.index == 0 ? provider.received : provider.made;
    final count = key == 'all'
        ? activeList.length
        : _countForFilter(activeList, key, received: tabs.index == 0);
    final accent = highlightColor ?? const Color(0xFFC69C55);

    return GestureDetector(
      onTap: () => setState(() => _stageFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? accent.withValues(alpha: 0.22) : const Color(0xFF252832))
              : (isDark ? const Color(0xFF1E222B) : Colors.white),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? (isDark ? accent : const Color(0xFF252832))
                : (isDark ? const Color(0xFF2E3442) : const Color(0xFFE5E2D9)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? (isDark ? accent : Colors.white)
                  : accent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? (isDark ? accent : Colors.white)
                    : (isDark ? Colors.grey.shade300 : const Color(0xFF4A5060)),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfferList(
    BuildContext context,
    List<MarketOffer> allOffers, {
    required bool received,
    required OfferProvider provider,
    required bool isDark,
  }) {
    if (allOffers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFC69C55).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  received
                      ? Icons.mark_email_unread_outlined
                      : Icons.handshake_outlined,
                  size: 42,
                  color: const Color(0xFFC69C55),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                received ? 'No incoming offers yet' : 'No sent offers yet',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                received
                    ? 'When campus buyers submit bids on your items, they will appear here for review.'
                    : 'Open any listing in Explore and submit a fair offer to start negotiating.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = allOffers
        .where((o) => _matchesFilter(o, received: received))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_off_rounded,
                size: 40,
                color: isDark ? Colors.grey.shade500 : const Color(0xFF777D8E),
              ),
              const SizedBox(height: 12),
              const Text(
                'No trades match this stage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(() => _stageFilter = 'all'),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Show All Trades'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final offer = filtered[index];
        return _buildOfferCard(
          context,
          offer,
          received: received,
          provider: provider,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    MarketOffer offer, {
    required bool received,
    required OfferProvider provider,
    required bool isDark,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final effectiveStatus = offer.isExpired ? 'expired' : offer.status;
    final bool isMyTurn;
    if (offer.status == 'countered') {
      isMyTurn = offer.lastUpdatedBy.isNotEmpty
          ? offer.lastUpdatedBy != uid
          : !received;
    } else if (offer.status == 'pending') {
      isMyTurn = received;
    } else {
      isMyTurn = false;
    }

    final chatProv = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: offer.status == 'accepted'
              ? const Color(0xFF24A889).withValues(alpha: 0.45)
              : isMyTurn && !offer.isExpired
                  ? const Color(0xFFF2A14A).withValues(alpha: 0.45)
                  : (isDark ? const Color(0xFF2E3442) : const Color(0xFFE7E4DC)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header: Title, Turn/Escrow badges, Status pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.listingTitle,
                      style: AppTypography.display(
                        size: 18,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF252832),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          received
                              ? Icons.person_outline_rounded
                              : Icons.storefront_outlined,
                          size: 14,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          received
                              ? 'From ${offer.buyerName}'
                              : 'Negotiating with Seller',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF777D8E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(effectiveStatus),
            ],
          ),

          const SizedBox(height: 14),

          // Price row + Badges
          Row(
            children: [
              Text(
                AppFormatters.formatBDT(offer.amount),
                style: AppTypography.price(
                  size: 23,
                  color: isDark ? Colors.white : const Color(0xFF252832),
                ),
              ),
              const SizedBox(width: 10),
              if (offer.feePaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24A889).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 12,
                        color: Color(0xFF24A889),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Escrow Protected',
                        style: TextStyle(
                          color: Color(0xFF24A889),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isMyTurn && !offer.isExpired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2A14A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'YOUR TURN',
                    style: TextStyle(
                      color: Color(0xFFF2A14A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // 3-step Transaction Stepper
          const SizedBox(height: 14),
          _OfferProgressStepper(
            status: offer.status,
            isExpired: offer.isExpired,
            isDark: isDark,
          ),

          if (offer.message.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151820) : const Color(0xFFF6F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"${offer.message.trim()}"',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF494F5E),
                ),
              ),
            ),
          ],

          // Negotiation History Chips
          if (offer.history.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Offer history:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                  ),
                ),
                for (int i = 0; i < offer.history.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: i == offer.history.length - 1
                          ? const Color(0xFFC69C55).withValues(alpha: 0.16)
                          : (isDark
                              ? const Color(0xFF252A36)
                              : const Color(0xFFEFEDE6)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppFormatters.formatBDT(offer.history[i].amount),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: i == offer.history.length - 1
                            ? const Color(0xFFC69C55)
                            : (isDark
                                ? Colors.grey.shade300
                                : const Color(0xFF4F5565)),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Handover 4-digit PIN Box when Accepted
          if (offer.status == 'accepted') ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final buyerPin = provider.pinForOffer(offer);
                if (!received && buyerPin.isNotEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF24A889).withValues(alpha: isDark ? 0.18 : 0.12),
                          const Color(0xFFC69C55).withValues(alpha: isDark ? 0.12 : 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF24A889).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF24A889).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.pin_rounded,
                            color: Color(0xFF24A889),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'YOUR PRIVATE HANDOVER PIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF24A889),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                buyerPin.split('').join(' '),
                                style: AppTypography.price(size: 23),
                              ),
                              Text(
                                'Share with seller ONLY when inspecting the item in person.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : const Color(0xFF535969),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: buyerPin),
                            );
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Handover PIN $buyerPin copied to clipboard',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('Copy PIN'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF24A889),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (!received) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24A889).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Loading your private handover PIN...',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2A14A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF2A14A).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.handshake_rounded,
                        color: Color(0xFFF2A14A),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Item reserved for buyer. Meet on campus and enter buyer\'s 4-digit PIN to finalize trade.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 14),

          // Actions Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Always let buyer & seller open 1-to-1 chat
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListingChatScreen(
                        threadId: chatProv.threadIdFor(offer.listingId, offer.buyerId),
                        listingId: offer.listingId,
                        listingTitle: offer.listingTitle,
                        listingPrice: offer.amount,
                        buyerId: offer.buyerId,
                        buyerName: offer.buyerName,
                        sellerId: offer.sellerId,
                        sellerName: received ? 'You' : 'Seller',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Chat'),
              ),

              if (!offer.isExpired &&
                  (offer.status == 'pending' || offer.status == 'countered')) ...[
                if (isMyTurn) ...[
                  if (received)
                    FilledButton.icon(
                      onPressed: provider.busy
                          ? null
                          : () async {
                              final ok = await provider.transition(offer, 'accept');
                              _snack(
                                messenger,
                                ok,
                                ok
                                    ? 'Offer accepted! Buyer received a 4-digit Handover PIN.'
                                    : provider.error,
                              );
                            },
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Accept'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF24A889),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: provider.busy
                          ? null
                          : () async {
                              final ok =
                                  await provider.transition(offer, 'acceptCounter');
                              _snack(
                                messenger,
                                ok,
                                ok
                                    ? 'Counter accepted! Show your Handover PIN at meetup.'
                                    : provider.error,
                              );
                            },
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Accept Counter'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF24A889),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: provider.busy
                        ? null
                        : () => _showCounter(context, offer, provider),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: Text(
                      offer.status == 'countered' ? 'Re-Counter' : 'Counter',
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF252A36)
                          : const Color(0xFFF3F1EC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      received ? 'Waiting for buyer' : 'Waiting for seller',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF777D8E),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: provider.busy
                      ? null
                      : () async {
                          final action = received ? 'decline' : 'withdraw';
                          final ok = await provider.transition(offer, action);
                          _snack(
                            messenger,
                            ok,
                            ok
                                ? (received
                                    ? 'Offer declined (escrow fee refunded)'
                                    : 'Offer withdrawn (escrow fee refunded)')
                                : provider.error,
                          );
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD94B64),
                  ),
                  child: Text(received ? 'Decline' : 'Withdraw'),
                ),
              ] else if (offer.status == 'accepted') ...[
                if (received) ...[
                  FilledButton.icon(
                    onPressed: provider.busy
                        ? null
                        : () => _confirmCompleteWithPin(context, offer, provider),
                    icon: const Icon(Icons.verified_rounded, size: 16),
                    label: const Text('Verify PIN & Complete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF24A889),
                    ),
                  ),
                  TextButton(
                    onPressed: provider.busy
                        ? null
                        : () async {
                            final ok = await provider.transition(offer, 'decline');
                            _snack(
                              messenger,
                              ok,
                              ok ? 'Reservation cancelled' : provider.error,
                            );
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD94B64),
                    ),
                    child: const Text('Cancel Deal'),
                  ),
                ] else
                  TextButton(
                    onPressed: provider.busy
                        ? null
                        : () async {
                            final ok = await provider.transition(offer, 'withdraw');
                            _snack(
                              messenger,
                              ok,
                              ok
                                  ? 'Reservation cancelled (escrow fee refunded)'
                                  : provider.error,
                            );
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD94B64),
                    ),
                    child: const Text('Cancel Meetup'),
                  ),
              ] else if (offer.status == 'completed' && !received) ...[
                if (!offer.isRated)
                  FilledButton.icon(
                    onPressed: () => _showRatingDialog(context, offer),
                    icon: const Icon(Icons.star_rounded, size: 16),
                    label: const Text('Rate Seller'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC69C55),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24A889).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Color(0xFF24A889)),
                        SizedBox(width: 4),
                        Text(
                          'Reviewed',
                          style: TextStyle(
                            color: Color(0xFF24A889),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else if (offer.isExpired && !received) ...[
                TextButton(
                  onPressed: provider.busy
                      ? null
                      : () async {
                          final ok = await provider.transition(offer, 'withdraw');
                          _snack(
                            messenger,
                            ok,
                            ok
                                ? 'Expired offer cleared & fee refunded'
                                : provider.error,
                          );
                        },
                  child: const Text('Clear & Refund'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCompleteWithPin(
    BuildContext context,
    MarketOffer offer,
    OfferProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinConfirmDialog(),
    );

    if (pin != null) {
      final ok = await provider.transition(
        offer,
        'complete',
        handoverPin: pin,
      );
      _snack(
        messenger,
        ok,
        ok ? 'Sale completed! Buyer can now rate you.' : provider.error,
      );
    }
  }

  void _showCounter(
    BuildContext context,
    MarketOffer offer,
    OfferProvider provider,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => _CounterOfferDialog(
        currentAmount: offer.amount,
        onSubmit: (amount) async {
          final ok = await provider.counterOffer(offer, amount);
          _snack(
            messenger,
            ok,
            ok ? 'Counter offer sent (${AppFormatters.formatBDT(amount)})' : provider.error,
          );
        },
      ),
    );
  }

  void _showRatingDialog(BuildContext context, MarketOffer offer) {
    final messenger = ScaffoldMessenger.of(context);
    final ratingProvider = context.read<RatingProvider>();
    showDialog<void>(
      context: context,
      builder: (_) => _RateSellerDialog(
        onSubmit: (stars, comment) async {
          final ok = await ratingProvider.rateSale(
            listingId: offer.listingId,
            sellerId: offer.sellerId,
            stars: stars,
            comment: comment,
            offerId: offer.id,
          );
          _snack(
            messenger,
            ok,
            ok ? 'Rating submitted!' : ratingProvider.error ?? 'Could not rate',
          );
        },
      ),
    );
  }

  void _snack(ScaffoldMessengerState messenger, bool ok, String? message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? (message ?? 'Offer updated') : (message ?? 'Action failed')),
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(1)}',
    );
    final color = status == 'accepted' || status == 'completed'
        ? const Color(0xFF24A889)
        : status == 'pending' || status == 'countered'
            ? const Color(0xFFF2A14A)
            : status == 'expired'
                ? const Color(0xFF777D8E)
                : const Color(0xFFD94B64);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingStatusDot(color: color, size: 6),
          const SizedBox(width: 5),
          Text(
            normalized.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferProgressStepper extends StatelessWidget {
  final String status;
  final bool isExpired;
  final bool isDark;

  const _OfferProgressStepper({
    required this.status,
    required this.isExpired,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpired || status == 'declined' || status == 'withdrawn') {
      final label = isExpired
          ? '48-hour response window expired'
          : status == 'withdrawn'
              ? 'Offer withdrawn by buyer'
              : 'Offer declined';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (isExpired ? const Color(0xFF777D8E) : const Color(0xFFD94B64))
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isExpired ? Icons.timer_off_rounded : Icons.cancel_outlined,
              size: 15,
              color: isExpired ? const Color(0xFF777D8E) : const Color(0xFFD94B64),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isExpired ? const Color(0xFF777D8E) : const Color(0xFFD94B64),
              ),
            ),
          ],
        ),
      );
    }

    final int reachedStep = status == 'completed'
        ? 3
        : status == 'accepted'
            ? 2
            : 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151820) : const Color(0xFFF7F6F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _stepNode(1, '1. Bid', reachedStep > 1, reachedStep == 1, isDark),
          _connector(reachedStep >= 2, isDark),
          _stepNode(2, '2. Reserved', reachedStep > 2, reachedStep == 2, isDark),
          _connector(reachedStep >= 3, isDark),
          _stepNode(3, '3. Handover', reachedStep >= 3, false, isDark),
        ],
      ),
    );
  }

  Widget _stepNode(
    int number,
    String label,
    bool done,
    bool current,
    bool isDark,
  ) {
    final Color bg;
    final Color fg;
    if (done) {
      bg = const Color(0xFF24A889);
      fg = Colors.white;
    } else if (current) {
      bg = const Color(0xFFF2A14A);
      fg = Colors.white;
    } else {
      bg = isDark ? const Color(0xFF282E3B) : const Color(0xFFE3E0D6);
      fg = isDark ? Colors.grey.shade400 : const Color(0xFF777D8E);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: fg,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: done || current ? FontWeight.w800 : FontWeight.w600,
            color: done
                ? const Color(0xFF24A889)
                : current
                    ? const Color(0xFFF2A14A)
                    : (isDark ? Colors.grey.shade400 : const Color(0xFF777D8E)),
          ),
        ),
      ],
    );
  }

  Widget _connector(bool active, bool isDark) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF24A889)
              : (isDark ? const Color(0xFF2A303E) : const Color(0xFFE0DDD2)),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _PinConfirmDialog extends StatefulWidget {
  const _PinConfirmDialog();

  @override
  State<_PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends State<_PinConfirmDialog> {
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Buyer Handover PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ask the buyer for the 4-digit verification PIN shown in their Offers tab before handing over the item.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
            decoration: const InputDecoration(
              labelText: '4-Digit Handover PIN',
              hintText: '• • • •',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _pinCtrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF24A889)),
          child: const Text('Complete Sale'),
        ),
      ],
    );
  }
}

class _CounterOfferDialog extends StatefulWidget {
  final int currentAmount;
  final Future<void> Function(int amount) onSubmit;

  const _CounterOfferDialog({
    required this.currentAmount,
    required this.onSubmit,
  });

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentAmount}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Counter Offer'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Proposed Amount',
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
            final amount = int.tryParse(_controller.text.trim());
            if (amount == null || amount <= 0) return;
            Navigator.pop(context);
            await widget.onSubmit(amount);
          },
          child: const Text('Send Counter'),
        ),
      ],
    );
  }
}

class _RateSellerDialog extends StatefulWidget {
  final Future<void> Function(int stars, String comment) onSubmit;

  const _RateSellerDialog({required this.onSubmit});

  @override
  State<_RateSellerDialog> createState() => _RateSellerDialogState();
}

class _RateSellerDialogState extends State<_RateSellerDialog> {
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Seller'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= 5; i++)
                IconButton(
                  icon: Icon(
                    i <= _stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFC69C55),
                    size: 32,
                  ),
                  onPressed: () => setState(() => _stars = i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              labelText: 'Optional review comment',
              hintText: 'Great communication, item as described...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final comment = _comment.text.trim();
            Navigator.pop(context);
            await widget.onSubmit(_stars, comment);
          },
          child: const Text('Submit Rating'),
        ),
      ],
    );
  }
}
