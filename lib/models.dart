import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String id;
  final String title;
  final String description;
  final String category;
  final String condition;
  final int price;
  final bool negotiable;
  final String imageUrl;
  final String sellerId;
  final String sellerName;
  final String status;
  final String reservedFor;
  final Timestamp? createdAt;

  Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.price,
    required this.negotiable,
    required this.imageUrl,
    required this.sellerId,
    required this.sellerName,
    required this.status,
    required this.reservedFor,
    this.createdAt,
  });

  factory Listing.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Listing(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? 'Other',
      condition: d['condition'] ?? 'used',
      price: (d['price'] as num?)?.toInt() ?? 0,
      negotiable: d['negotiable'] ?? false,
      imageUrl: d['imageUrl'] ?? '',
      sellerId: d['sellerId'] ?? '',
      sellerName: d['sellerName'] ?? 'Unknown user',
      status: d['status'] ?? 'available',
      reservedFor: d['reservedFor'] ?? '',
      createdAt: d['createdAt'] is Timestamp ? d['createdAt'] : null,
    );
  }

  bool get isAvailable => status == 'available';
  bool get isReserved => status == 'reserved';
  bool get isSold => status == 'sold';
}

class MarketOffer {
  final String id;
  final String listingId;
  final String listingTitle;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final int amount;
  final String message;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  MarketOffer({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.amount,
    required this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory MarketOffer.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MarketOffer(
      id: doc.id,
      listingId: d['listingId'] ?? '',
      listingTitle: d['listingTitle'] ?? '',
      sellerId: d['sellerId'] ?? '',
      buyerId: d['buyerId'] ?? '',
      buyerName: d['buyerName'] ?? 'Unknown user',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      message: d['message'] ?? '',
      status: d['status'] ?? 'pending',
      createdAt: d['createdAt'],
      updatedAt: d['updatedAt'],
    );
  }

  bool get isExpired =>
      createdAt != null &&
      DateTime.now().difference(createdAt!.toDate()).inHours >= 48 &&
      (status == 'pending' || status == 'countered');
}
