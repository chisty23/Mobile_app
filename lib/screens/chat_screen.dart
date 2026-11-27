import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../widgets/seller_profile_sheet.dart';
import '../widgets/user_avatar.dart';

class ListingChatScreen extends StatefulWidget {
  final String threadId;
  final String listingId;
  final String listingTitle;
  final int listingPrice;
  final String buyerId;
  final String buyerName;
  final String buyerPhotoUrl;
  final String sellerId;
  final String sellerName;
  final String sellerPhotoUrl;

  const ListingChatScreen({
    super.key,
    required this.threadId,
    required this.listingId,
    required this.listingTitle,
    required this.listingPrice,
    required this.buyerId,
    required this.buyerName,
    this.buyerPhotoUrl = '',
    required this.sellerId,
    required this.sellerName,
    this.sellerPhotoUrl = '',
  });

  @override
  State<ListingChatScreen> createState() => _ListingChatScreenState();
}

class _ListingChatScreenState extends State<ListingChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickQuestions = [
    'Hi, is this still available?',
    'Can we meet on campus to inspect?',
    'Are original accessories/receipt included?',
    'What is your final asking price?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatProvider>().markThreadRead(widget.threadId);
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _msgController.text).trim();
    if (text.isEmpty) return;

    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await chat.sendMessage(
      threadId: widget.threadId,
      listingId: widget.listingId,
      listingTitle: widget.listingTitle,
      listingPrice: widget.listingPrice,
      buyerId: widget.buyerId,
      buyerName: widget.buyerName,
      sellerId: widget.sellerId,
      sellerName: widget.sellerName,
      text: text,
    );
    if (!mounted) return;
    if (ok) {
      chat.markThreadRead(widget.threadId);
      if (overrideText == null) _msgController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(chat.error ?? 'Could not send message. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final dir = context.watch<ProfileDirectoryProvider>();
    final currentUid = context.watch<AuthProvider>().uid ?? '';
    final isBuyer = currentUid == widget.buyerId;
    final peerId = isBuyer ? widget.sellerId : widget.buyerId;
    final fallbackPeerName = isBuyer ? widget.sellerName : widget.buyerName;
    final peerName = dir.nameFor(peerId, fallback: fallbackPeerName);
    final peerPhoto = dir.photoFor(
      peerId,
      fallback: isBuyer ? widget.sellerPhotoUrl : widget.buyerPhotoUrl,
    );
    final myFallbackName = isBuyer ? widget.buyerName : widget.sellerName;
    final myPhoto = dir.photoFor(
      currentUid,
      fallback: isBuyer ? widget.buyerPhotoUrl : widget.sellerPhotoUrl,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            UserAvatar(
              uid: peerId,
              name: peerName,
              photoUrl: peerPhoto,
              radius: 18,
              onTap: () => SellerProfileSheet.show(
                context,
                sellerId: peerId,
                sellerName: peerName,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${widget.listingTitle} · ${AppFormatters.formatBDT(widget.listingPrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF626779),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: chat.messagesStream(widget.threadId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load messages: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFD94B64)),
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data ?? const [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 46,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Ask before making an offer',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Confirm condition, battery health, receipt, or meetup point with $peerName.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        final mine = msg.senderId == currentUid;
                        final bubbleAvatar = UserAvatar(
                          uid: msg.senderId,
                          name: msg.senderName.isNotEmpty
                              ? msg.senderName
                              : (mine ? myFallbackName : peerName),
                          photoUrl: msg.senderPhotoUrl.isNotEmpty
                              ? msg.senderPhotoUrl
                              : (mine ? myPhoto : peerPhoto),
                          radius: 14,
                          onTap: () => SellerProfileSheet.show(
                            context,
                            sellerId: msg.senderId,
                            sellerName: msg.senderName.isNotEmpty
                                ? msg.senderName
                                : peerName,
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment:
                                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!mine) ...[
                                bubbleAvatar,
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 320),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? const Color(0xFF252832)
                                        : (isDark ? const Color(0xFF1E222B) : Colors.white),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(mine ? 16 : 4),
                                      bottomRight: Radius.circular(mine ? 4 : 16),
                                    ),
                                    border: mine
                                        ? null
                                        : Border.all(
                                            color: isDark
                                                ? const Color(0xFF2E3442)
                                                : Colors.grey.shade200,
                                          ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white
                                              : (isDark ? Colors.white : const Color(0xFF252832)),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppFormatters.formatRelativeTime(msg.createdAt),
                                        style: TextStyle(
                                          color: mine ? Colors.white54 : Colors.grey.shade500,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 8),
                                bubbleAvatar,
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (isBuyer)
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _quickQuestions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ActionChip(
                      label: Text(_quickQuestions[i], style: const TextStyle(fontSize: 12)),
                      onPressed: () => _send(_quickQuestions[i]),
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: chat.sending ? null : () => _send(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF252832),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(14),
                        ),
                        child: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatsDrawerSheet extends StatelessWidget {
  const ChatsDrawerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final uid = context.watch<AuthProvider>().uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
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
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direct Messages',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Buyer & seller item inquiries',
                              style: TextStyle(fontSize: 12, color: Color(0xFF777D8E)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${chat.threads.length} chats',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF667B72),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: chat.threads.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No conversations yet. Open any listing and tap "Message Seller" to ask questions before buying.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF777D8E)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: chat.threads.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final t = chat.threads[i];
                            final isBuyer = t.buyerId == uid;
                            final peerId = isBuyer ? t.sellerId : t.buyerId;
                            final peerName = isBuyer ? t.sellerName : t.buyerName;
                            final peerPhoto =
                                isBuyer ? t.sellerPhotoUrl : t.buyerPhotoUrl;
                            return ListTile(
                              tileColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: UserAvatar(
                                uid: peerId,
                                name: peerName,
                                photoUrl: peerPhoto,
                                radius: 22,
                              ),
                              title: Text(
                                '$peerName · ${t.listingTitle}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              subtitle: Text(
                                t.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                AppFormatters.formatRelativeTime(t.updatedAt),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF777D8E)),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListingChatScreen(
                                      threadId: t.id,
                                      listingId: t.listingId,
                                      listingTitle: t.listingTitle,
                                      listingPrice: t.listingPrice,
                                      buyerId: t.buyerId,
                                      buyerName: t.buyerName,
                                      buyerPhotoUrl: t.buyerPhotoUrl,
                                      sellerId: t.sellerId,
                                      sellerName: t.sellerName,
                                      sellerPhotoUrl: t.sellerPhotoUrl,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First-class Messages tab view for the primary navigation shell.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final dir = context.watch<ProfileDirectoryProvider>();
    final uid = context.watch<AuthProvider>().uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = chat.threads.where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.listingTitle.toLowerCase().contains(q) ||
          t.buyerName.toLowerCase().contains(q) ||
          t.sellerName.toLowerCase().contains(q) ||
          t.lastMessage.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667B72).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
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
                            'Messages',
                            style: AppTypography.display(
                              size: 28,
                              letterSpacing: -0.6,
                              color: isDark ? Colors.white : const Color(0xFF252832),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Direct buyer & seller item inquiries',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF6A7080),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (chat.threads.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search chats by item or member...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE6E4DC),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE6E4DC),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.forum_outlined,
                                size: 52,
                                color: Color(0xFF9A9FAF),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _query.isNotEmpty ? 'No matching conversations' : 'Your inbox is empty',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _query.isNotEmpty
                                    ? 'Try a different item title or name.'
                                    : 'Open any listing and tap "Chat" to ask sellers questions before ordering.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          final isBuyer = t.buyerId == uid;
                          final peerId = isBuyer ? t.sellerId : t.buyerId;
                          final peerName = dir.nameFor(
                            peerId,
                            fallback: isBuyer ? t.sellerName : t.buyerName,
                          );
                          final peerPhoto = dir.photoFor(
                            peerId,
                            fallback: isBuyer ? t.sellerPhotoUrl : t.buyerPhotoUrl,
                          );
                          final unread =
                              uid.isNotEmpty && chat.isThreadUnread(t);
                          return Material(
                            color: isDark ? const Color(0xFF1E222B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListingChatScreen(
                                      threadId: t.id,
                                      listingId: t.listingId,
                                      listingTitle: t.listingTitle,
                                      listingPrice: t.listingPrice,
                                      buyerId: t.buyerId,
                                      buyerName: t.buyerName,
                                      buyerPhotoUrl: t.buyerPhotoUrl,
                                      sellerId: t.sellerId,
                                      sellerName: t.sellerName,
                                      sellerPhotoUrl: t.sellerPhotoUrl,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF2E3442)
                                        : const Color(0xFFEBE9E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      uid: peerId,
                                      name: peerName,
                                      photoUrl: peerPhoto,
                                      radius: 22,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  peerName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (unread) ...[
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFF24A889),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    const Icon(
                                                      Icons.schedule_rounded,
                                                      size: 12,
                                                      color: Color(0xFF777D8E),
                                                    ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    AppFormatters.formatRelativeTime(t.updatedAt),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF777D8E),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.sell_outlined,
                                                size: 13,
                                                color: Color(0xFF667B72),
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  t.listingTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF667B72),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                AppFormatters.formatBDT(t.listingPrice),
                                                style: AppTypography.price(
                                                  size: 12.5,
                                                  color: const Color(0xFF667B72),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            t.lastMessage,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : const Color(0xFF5E6372),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
