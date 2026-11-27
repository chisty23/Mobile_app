import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../screens/browse_screen.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import 'report_sheet.dart';
import 'smart_image.dart';
import 'user_avatar.dart';

class SellerProfileSheet extends StatelessWidget {
  final String sellerId;
  final String sellerName;

  const SellerProfileSheet({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  static Future<void> show(
    BuildContext context, {
    required String sellerId,
    required String sellerName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SellerProfileSheet(
        sellerId: sellerId,
        sellerName: sellerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, scrollController) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F9FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: context.read<RatingProvider>().fetchSellerPublicData(sellerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? {};
                final profile = (data['profile'] as Map<String, dynamic>?) ?? {};
                final reviews = (data['reviews'] as List<SellerReview>?) ?? const [];
                final activeListings = (data['listings'] as List<Listing>?) ?? const [];

                final dept = (profile['department'] as String?) ?? '';
                final hostel = (profile['hostel'] as String?) ?? '';
                final photoUrl = (profile['photoUrl'] as String?) ?? '';
                final bio = (profile['bio'] as String?) ?? '';
                final location = (profile['location'] as String?) ?? '';
                final batchYear = (profile['batchYear'] as String?) ?? '';
                final meetupSpot = (profile['meetupSpot'] as String?) ?? '';
                final soldCount = (profile['soldCount'] as num?)?.toInt() ?? 0;
                final ratingSum = (profile['ratingSum'] as num?)?.toInt() ?? 0;
                final ratingCount = (profile['ratingCount'] as num?)?.toInt() ?? 0;
                final avgRating = ratingCount == 0 ? 0.0 : ratingSum / ratingCount;
                final isVerifiedStudent = profile['verifiedStudent'] == true;
                final phoneVerified = profile['phoneVerified'] == true;
                final currentUid = context.watch<AuthProvider>().uid;
                final resolvedSellerName = sellerName.trim().isNotEmpty
                    ? sellerName.trim()
                    : AppFormatters.unknownUserName;

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        UserAvatar(
                          uid: sellerId,
                          name: resolvedSellerName,
                          photoUrl: photoUrl,
                          radius: 32,
                          showBorder: true,
                          showVerifiedBadge: isVerifiedStudent || phoneVerified,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      resolvedSellerName,
                                      style: AppTypography.display(size: 22),
                                    ),
                                  ),
                                  if (isVerifiedStudent) ...[
                                    const SizedBox(width: 6),
                                    const Tooltip(
                                      message: 'Verified campus .edu email',
                                      child: Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF24A889),
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (dept.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.school_outlined,
                                      size: 13,
                                      color: Color(0xFF667B72),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        batchYear.isNotEmpty ? '$dept · Batch $batchYear' : dept,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : const Color(0xFF777D8E),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (location.isNotEmpty ||
                                  hostel.isNotEmpty ||
                                  meetupSpot.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.place_outlined,
                                        size: 13,
                                        color: Color(0xFF667B72),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          [
                                            if (hostel.isNotEmpty) hostel,
                                            if (location.isNotEmpty) location,
                                            if (meetupSpot.isNotEmpty) 'Meetup: $meetupSpot',
                                          ].join(' · '),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : const Color(0xFF777D8E),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Color(0xFFC69C55), size: 17),
                                      const SizedBox(width: 4),
                                      Text(
                                        ratingCount == 0
                                            ? 'No reviews yet'
                                            : '${avgRating.toStringAsFixed(1)} ($ratingCount reviews)',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF24A889),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$soldCount verified sales',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : const Color(0xFF777D8E),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (currentUid != null && currentUid != sellerId)
                          IconButton(
                            tooltip: 'Report seller',
                            icon: const Icon(
                              Icons.flag_outlined,
                              color: Color(0xFFD94B64),
                            ),
                            onPressed: () => ReportSheet.show(
                              context,
                              targetType: 'user',
                              targetId: sellerId,
                              targetTitle: sellerName,
                              targetUserId: sellerId,
                            ),
                          ),
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          bio,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? Colors.grey.shade300 : const Color(0xFF4B505E),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Icon(Icons.reviews_outlined, size: 18, color: Color(0xFFC69C55)),
                        const SizedBox(width: 8),
                        Text(
                          'Buyer Reviews (${reviews.length})',
                          style: AppTypography.display(size: 17),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (reviews.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'This seller has not received buyer reviews yet.',
                          style: TextStyle(color: Color(0xFF777D8E), fontSize: 13),
                        ),
                      )
                    else
                      ...reviews.map(
                        (r) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E222B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        UserAvatar(
                                          uid: r.buyerId,
                                          name: r.buyerName,
                                          photoUrl: r.buyerPhotoUrl,
                                          radius: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            r.buyerName,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      for (int s = 1; s <= 5; s++)
                                        Icon(
                                          s <= r.stars ? Icons.star_rounded : Icons.star_border_rounded,
                                          size: 15,
                                          color: const Color(0xFFC69C55),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              if (r.comment.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(r.comment, style: const TextStyle(fontSize: 13)),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                AppFormatters.formatRelativeTime(r.createdAt),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9196A4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (activeListings.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF667B72)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'More from $sellerName (${activeListings.length})',
                              style: AppTypography.display(size: 17),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 170,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: activeListings.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final item = activeListings[i];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                ListingDetailSheet.show(context, item);
                              },
                              child: Container(
                                width: 140,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E222B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SmartListingImage(
                                          imageUrl: item.imageUrl,
                                          fit: BoxFit.cover,
                                          fallback: const Center(
                                            child: Icon(Icons.inventory_2_outlined),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.formatBDT(item.price),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: Color(0xFF24A889),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
