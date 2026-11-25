import 'package:cloud_firestore/cloud_firestore.dart';

class PublicUserProfile {
  final String uid;
  final String name;
  final String photoUrl;
  final String bio;
  final String department;
  final String location;
  final String batchYear;
  final String meetupSpot;
  final bool verifiedStudent;
  final bool phoneVerified;
  final bool emailVerified;
  final int soldCount;
  final int boughtCount;
  final int ratingSum;
  final int ratingCount;
  final bool isBanned;
  final DateTime? updatedAt;

  const PublicUserProfile({
    required this.uid,
    this.name = 'PassItOn Member',
    this.photoUrl = '',
    this.bio = '',
    this.department = '',
    this.location = '',
    this.batchYear = '',
    this.meetupSpot = '',
    this.verifiedStudent = false,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.soldCount = 0,
    this.boughtCount = 0,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.isBanned = false,
    this.updatedAt,
  });

  double get averageRating => ratingCount == 0 ? 0.0 : ratingSum / ratingCount;

  int get completionPercent {
    var score = 0;
    if (name.trim().isNotEmpty) score += 20;
    if (photoUrl.trim().isNotEmpty) score += 25;
    if (bio.trim().isNotEmpty) score += 20;
    if (department.trim().isNotEmpty) score += 15;
    if (location.trim().isNotEmpty) score += 10;
    if (meetupSpot.trim().isNotEmpty || batchYear.trim().isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  factory PublicUserProfile.fromMap(String uid, Map<String, dynamic>? d) {
    final data = d ?? const <String, dynamic>{};
    return PublicUserProfile(
      uid: uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'PassItOn Member',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      department: (data['department'] as String?) ?? '',
      location: (data['location'] as String?) ?? '',
      batchYear: (data['batchYear'] as String?) ?? '',
      meetupSpot: (data['meetupSpot'] as String?) ?? '',
      verifiedStudent: data['verifiedStudent'] == true,
      phoneVerified: data['phoneVerified'] == true,
      emailVerified: data['emailVerified'] == true,
      soldCount: (data['soldCount'] as num?)?.toInt() ?? 0,
      boughtCount: (data['boughtCount'] as num?)?.toInt() ?? 0,
      ratingSum: (data['ratingSum'] as num?)?.toInt() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      isBanned: data['isBanned'] == true,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory PublicUserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PublicUserProfile.fromMap(doc.id, doc.data());
  }
}

class ListingComment {
  final String id;
  final String listingId;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String text;
  final bool isSeller;
  final DateTime createdAt;

  ListingComment({
    required this.id,
    required this.listingId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl = '',
    required this.text,
    this.isSeller = false,
    required this.createdAt,
  });

  factory ListingComment.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String listingId = '',
  }) {
    final d = doc.data() ?? {};
    return ListingComment(
      id: doc.id,
      listingId: (d['listingId'] as String?) ?? listingId,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Campus Member',
      authorPhotoUrl: d['authorPhotoUrl'] ?? '',
      text: d['text'] ?? '',
      isSeller: d['isSeller'] == true,
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class Listing {
  final String id;
  final String title;
  final String description;
  final String category;
  final String condition;
  final String location;
  final int price;
  final bool negotiable;
  final String imageUrl;
  final List<String> images;
  final String sellerId;
  final String sellerName;
  final String sellerPhotoUrl;
  final String status;
  final String reservedFor;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool feePaid;
  final String feeTransactionId;
  final bool statsCounted;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    this.location = 'Campus Dorm / Hall',
    required this.price,
    required this.negotiable,
    required this.imageUrl,
    this.images = const [],
    required this.sellerId,
    required this.sellerName,
    this.sellerPhotoUrl = '',
    required this.status,
    required this.reservedFor,
    this.createdAt,
    this.updatedAt,
    this.feePaid = false,
    this.feeTransactionId = '',
    this.statsCounted = false,
  });

  factory Listing.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final primaryUrl = (d['imageUrl'] as String?) ?? '';
    final rawImages = (d['images'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        [];
    final mergedImages = rawImages.isNotEmpty
        ? rawImages
        : (primaryUrl.trim().isNotEmpty ? [primaryUrl.trim()] : <String>[]);

    return Listing(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? 'Other',
      condition: d['condition'] ?? 'used',
      location: d['location'] ?? 'Campus Dorm / Hall',
      price: (d['price'] as num?)?.toInt() ?? 0,
      negotiable: d['negotiable'] ?? false,
      imageUrl: mergedImages.isNotEmpty ? mergedImages.first : primaryUrl,
      images: mergedImages,
      sellerId: d['sellerId'] ?? '',
      sellerName: d['sellerName'] ?? 'Unknown user',
      sellerPhotoUrl: d['sellerPhotoUrl'] ?? '',
      status: d['status'] ?? 'available',
      reservedFor: d['reservedFor'] ?? '',
      createdAt: d['createdAt'] is Timestamp ? d['createdAt'] : null,
      updatedAt: d['updatedAt'] is Timestamp ? d['updatedAt'] : null,
      feePaid: d['feePaid'] ?? false,
      feeTransactionId: d['feeTransactionId'] ?? '',
      statsCounted: d['statsCounted'] ?? false,
    );
  }

  List<String> get galleryImages => images.isNotEmpty
      ? images
      : (imageUrl.trim().isNotEmpty ? [imageUrl.trim()] : const []);

  bool get isAvailable => status == 'available';
  bool get isReserved => status == 'reserved';
  bool get isSold => status == 'sold';
  bool get isNegotiable => negotiable;
}

class OfferHistoryEntry {
  final String by;
  final int amount;
  final DateTime? at;

  OfferHistoryEntry({
    required this.by,
    required this.amount,
    this.at,
  });

  factory OfferHistoryEntry.fromMap(Map<String, dynamic> map) {
    return OfferHistoryEntry(
      by: map['by']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      at: map['at'] is Timestamp ? (map['at'] as Timestamp).toDate() : null,
    );
  }
}

class MarketOffer {
  final String id;
  final String listingId;
  final String listingTitle;
  final String sellerId;
  final String sellerName;
  final String sellerPhotoUrl;
  final String buyerId;
  final String buyerName;
  final String buyerPhotoUrl;
  final int amount;
  final String lastUpdatedBy;
  final String message;
  final String status;
  final String handoverCode;
  final bool hasPin;
  final bool isRated;
  final List<OfferHistoryEntry> history;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool feePaid;
  final String feeTransactionId;

  MarketOffer({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.sellerId,
    this.sellerName = '',
    this.sellerPhotoUrl = '',
    required this.buyerId,
    required this.buyerName,
    this.buyerPhotoUrl = '',
    required this.amount,
    this.lastUpdatedBy = '',
    required this.message,
    required this.status,
    this.handoverCode = '',
    this.hasPin = false,
    this.isRated = false,
    this.history = const [],
    this.createdAt,
    this.updatedAt,
    this.feePaid = false,
    this.feeTransactionId = '',
  });

  factory MarketOffer.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawHistory = (d['history'] as List<dynamic>?) ?? const [];
    final parsedHistory = rawHistory
        .whereType<Map<String, dynamic>>()
        .map(OfferHistoryEntry.fromMap)
        .toList();

    return MarketOffer(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      sellerId: d['sellerId'] ?? '',
      sellerName: d['sellerName'] ?? '',
      sellerPhotoUrl: d['sellerPhotoUrl'] ?? '',
      buyerId: d['buyerId'] ?? '',
      buyerName: d['buyerName'] ?? 'Unknown user',
      buyerPhotoUrl: d['buyerPhotoUrl'] ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      lastUpdatedBy: d['lastUpdatedBy'] ?? '',
      message: d['message'] ?? '',
      status: d['status'] ?? 'pending',
      handoverCode: d['handoverCode'] ?? '',
      hasPin: d['hasPin'] ?? ((d['handoverCode'] as String? ?? '').isNotEmpty),
      isRated: d['isRated'] ?? false,
      history: parsedHistory,
      createdAt: d['createdAt'] is Timestamp ? d['createdAt'] : null,
      updatedAt: d['updatedAt'] is Timestamp ? d['updatedAt'] : null,
      feePaid: d['feePaid'] ?? false,
      feeTransactionId: d['feeTransactionId'] ?? '',
    );
  }

  bool get isExpired =>
      createdAt != null &&
      DateTime.now().difference(createdAt!.toDate()).inHours >= 48 &&
      (status == 'pending' || status == 'countered');
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl = '',
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? 'Member',
      senderPhotoUrl: d['senderPhotoUrl'] ?? '',
      text: d['text'] ?? '',
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class ChatThread {
  final String id;
  final String listingId;
  final String listingTitle;
  final int listingPrice;
  final String buyerId;
  final String buyerName;
  final String buyerPhotoUrl;
  final String sellerId;
  final String sellerName;
  final String sellerPhotoUrl;
  final String lastMessage;
  final DateTime updatedAt;

  ChatThread({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingPrice,
    required this.buyerId,
    required this.buyerName,
    this.buyerPhotoUrl = '',
    required this.sellerId,
    required this.sellerName,
    this.sellerPhotoUrl = '',
    required this.lastMessage,
    required this.updatedAt,
  });

  factory ChatThread.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatThread(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      listingPrice: (d['listingPrice'] as num?)?.toInt() ?? 0,
      buyerId: d['buyerId'] ?? '',
      buyerName: d['buyerName'] ?? 'Buyer',
      buyerPhotoUrl: d['buyerPhotoUrl'] ?? '',
      sellerId: d['sellerId'] ?? '',
      sellerName: d['sellerName'] ?? 'Seller',
      sellerPhotoUrl: d['sellerPhotoUrl'] ?? '',
      lastMessage: d['lastMessage'] ?? '',
      updatedAt: d['updatedAt'] is Timestamp
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class SellerReview {
  final String id;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final String buyerPhotoUrl;
  final int stars;
  final String comment;
  final DateTime createdAt;

  SellerReview({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    this.buyerPhotoUrl = '',
    required this.stars,
    required this.comment,
    required this.createdAt,
  });

  factory SellerReview.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SellerReview(
      id: doc.id,
      sellerId: d['sellerId'] ?? '',
      buyerId: d['buyerId'] ?? '',
      buyerName: d['buyerName'] ?? 'Verified Buyer',
      buyerPhotoUrl: d['buyerPhotoUrl'] ?? '',
      stars: (d['stars'] as num?)?.toInt() ?? 5,
      comment: d['comment'] ?? '',
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'offer_received', 'offer_accepted', 'counter_offer', 'offer_declined', 'offer_withdrawn', 'listing_sold'
  final String listingId;
  final String listingTitle;
  final String offerId;
  final int amount;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.listingId,
    required this.listingTitle,
    required this.offerId,
    required this.amount,
    required this.timestamp,
    this.isRead = false,
  });
}

class CategoryPreset {
  final String name;
  final String category;
  final String imageUrl;

  const CategoryPreset({
    required this.name,
    required this.category,
    required this.imageUrl,
  });
}

class PresetCatalog {
  static const List<CategoryPreset> presets = [
    CategoryPreset(
      name: 'College Textbook',
      category: 'Books',
      imageUrl:
          'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Study Notes & Binder',
      category: 'Books',
      imageUrl:
          'https://images.unsplash.com/photo-1517842645767-c639042777db?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Laptop / Mac',
      category: 'Electronics',
      imageUrl:
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Wireless Headphones',
      category: 'Electronics',
      imageUrl:
          'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Tablet / iPad',
      category: 'Electronics',
      imageUrl:
          'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Scientific Calculator',
      category: 'Electronics',
      imageUrl:
          'https://images.unsplash.com/photo-1594980596870-8aa52a78d8cd?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Campus Hoodie',
      category: 'Fashion',
      imageUrl:
          'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'College Backpack',
      category: 'Fashion',
      imageUrl:
          'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Campus Bike',
      category: 'Sports',
      imageUrl:
          'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Badminton / Tennis Racket',
      category: 'Sports',
      imageUrl:
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Desk Study Lamp',
      category: 'Furniture',
      imageUrl:
          'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Desk Chair',
      category: 'Furniture',
      imageUrl:
          'https://images.unsplash.com/photo-1580481077111-9a7b7444155b?w=800&auto=format&fit=crop&q=80',
    ),
    CategoryPreset(
      name: 'Insulated Flask',
      category: 'Other',
      imageUrl:
          'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=800&auto=format&fit=crop&q=80',
    ),
  ];

  static String defaultForCategory(String category) {
    for (final preset in presets) {
      if (preset.category.toLowerCase() == category.toLowerCase()) {
        return preset.imageUrl;
      }
    }
    return presets.first.imageUrl;
  }
}

class PlatformFeeSettings {
  final int sellerListingFee;
  final int buyerOrderFee;
  final bool feesEnabled;
  final DateTime? updatedAt;
  final String updatedBy;

  const PlatformFeeSettings({
    this.sellerListingFee = 20,
    this.buyerOrderFee = 50,
    this.feesEnabled = true,
    this.updatedAt,
    this.updatedBy = 'admin',
  });

  factory PlatformFeeSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PlatformFeeSettings();
    return PlatformFeeSettings(
      sellerListingFee: (data['sellerListingFee'] as num?)?.toInt() ?? 20,
      buyerOrderFee: (data['buyerOrderFee'] as num?)?.toInt() ?? 50,
      feesEnabled: data['feesEnabled'] ?? true,
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'] ?? 'admin',
    );
  }

  Map<String, dynamic> toMap() => {
        'sellerListingFee': sellerListingFee,
        'buyerOrderFee': buyerOrderFee,
        'feesEnabled': feesEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      };
}

class PlatformPaymentRecord {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String type; // 'seller_listing_fee' | 'buyer_order_fee'
  final int amount; // in BDT
  final String currency; // 'BDT'
  final String method; // 'bKash' | 'Nagad' | 'Rocket' | 'Campus Wallet'
  final String transactionId;
  final String referenceId; // listingId or offerId
  final String referenceTitle;
  final String status; // 'completed' | 'refunded'
  final DateTime createdAt;

  PlatformPaymentRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.type,
    required this.amount,
    this.currency = 'BDT',
    required this.method,
    required this.transactionId,
    required this.referenceId,
    this.referenceTitle = '',
    this.status = 'completed',
    required this.createdAt,
  });

  factory PlatformPaymentRecord.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PlatformPaymentRecord(
      id: doc.id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? 'Anonymous trader',
      userEmail: d['userEmail'] ?? '',
      type: d['type'] ?? 'seller_listing_fee',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      currency: d['currency'] ?? 'BDT',
      method: d['method'] ?? 'bKash',
      transactionId: d['transactionId'] ?? '',
      referenceId: d['referenceId'] ?? '',
      referenceTitle: d['referenceTitle'] ?? '',
      status: d['status'] ?? 'completed',
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'type': type,
        'amount': amount,
        'currency': currency,
        'method': method,
        'transactionId': transactionId,
        'referenceId': referenceId,
        'referenceTitle': referenceTitle,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class PaymentInitResult {
  final String mode; // 'sandbox_completed' | 'redirect'
  final PlatformPaymentRecord? payment;
  final String? gatewayUrl;
  final String? transactionId;

  const PaymentInitResult({
    required this.mode,
    this.payment,
    this.gatewayUrl,
    this.transactionId,
  });
}

class ReportRecord {
  final String id;
  final String targetType; // 'listing' | 'user'
  final String targetId;
  final String targetTitle;
  final String targetUserId;
  final String reporterId;
  final String reporterName;
  final String reason;
  final String details;
  final String status; // 'open' | 'resolved' | 'dismissed'
  final DateTime createdAt;

  ReportRecord({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    this.targetUserId = '',
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    this.details = '',
    this.status = 'open',
    required this.createdAt,
  });

  factory ReportRecord.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ReportRecord(
      id: doc.id,
      targetType: d['targetType'] ?? 'listing',
      targetId: d['targetId'] ?? '',
      targetTitle: d['targetTitle'] ?? '',
      targetUserId: d['targetUserId'] ?? '',
      reporterId: d['reporterId'] ?? '',
      reporterName: d['reporterName'] ?? 'Campus Member',
      reason: d['reason'] ?? 'Suspicious activity',
      details: d['details'] ?? '',
      status: d['status'] ?? 'open',
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class PlatformMetrics {
  final int totalRevenueBDT;
  final int refundedRevenueBDT;
  final int sellerRevenueBDT;
  final int buyerRevenueBDT;
  final bool hasData;

  const PlatformMetrics({
    this.totalRevenueBDT = 0,
    this.refundedRevenueBDT = 0,
    this.sellerRevenueBDT = 0,
    this.buyerRevenueBDT = 0,
    this.hasData = false,
  });

  factory PlatformMetrics.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const PlatformMetrics();
    return PlatformMetrics(
      totalRevenueBDT: (d['totalRevenueBDT'] as num?)?.toInt() ?? 0,
      refundedRevenueBDT: (d['refundedRevenueBDT'] as num?)?.toInt() ?? 0,
      sellerRevenueBDT: (d['sellerRevenueBDT'] as num?)?.toInt() ?? 0,
      buyerRevenueBDT: (d['buyerRevenueBDT'] as num?)?.toInt() ?? 0,
      hasData: true,
    );
  }
}
