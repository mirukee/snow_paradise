import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductStatus { forSale, reserved, soldOut, hidden }

ProductStatus productStatusFromString(String? value) {
  switch (value) {
    case 'reserved':
      return ProductStatus.reserved;
    case 'soldOut':
      return ProductStatus.soldOut;
    case 'hidden':
      return ProductStatus.hidden;
    case 'forSale':
    default:
      return ProductStatus.forSale;
  }
}

extension ProductStatusX on ProductStatus {
  String get firestoreValue {
    switch (this) {
      case ProductStatus.forSale:
        return 'forSale';
      case ProductStatus.reserved:
        return 'reserved';
      case ProductStatus.soldOut:
        return 'soldOut';
      case ProductStatus.hidden:
        return 'hidden';
    }
  }

  String get label {
    switch (this) {
      case ProductStatus.forSale:
        return '판매중';
      case ProductStatus.reserved:
        return '예약중';
      case ProductStatus.soldOut:
        return '거래완료';
      case ProductStatus.hidden:
        return '숨김';
    }
  }
}

List<String> generateKeywords(String title) {
  final normalized = title.toLowerCase().trim();
  if (normalized.isEmpty) {
    return [];
  }
  final keywords = <String>{};
  for (final word in normalized.split(RegExp(r'\s+'))) {
    final trimmed = word.trim();
    if (trimmed.isNotEmpty) {
      keywords.add(trimmed);
    }
  }
  return keywords.toList();
}

class Product {
  final String id;
  final String? docId;
  final DateTime createdAt;
  final String title;
  final int price;
  final String brand;
  final String category;
  final List<String> keywords;
  final String condition;
  final String imageUrl;
  final String? localImagePath;
  final String description;
  final String size;
  final String year;
  final String sellerName;
  final String sellerProfile;
  final String sellerId;
  final ProductStatus status;
  final int likeCount;
  final int chatCount;

  Product({
    required this.id,
    this.docId,
    DateTime? createdAt,
    required this.title,
    required this.price,
    required this.brand,
    this.category = '기타',
    this.keywords = const [],
    required this.condition,
    required this.imageUrl,
    this.localImagePath,
    required this.description,
    required this.size,
    required this.year,
    required this.sellerName,
    required this.sellerProfile,
    this.sellerId = '',
    this.status = ProductStatus.forSale,
    this.likeCount = 0,
    this.chatCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Product.fromJson(Map<String, dynamic> json, {String? docId}) {
    int parseCount(dynamic value) {
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawCreatedAt = json['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : rawCreatedAt is DateTime
            ? rawCreatedAt
            : DateTime.fromMillisecondsSinceEpoch(0);
    final rawPrice = json['price'];
    final rawKeywords = json['keywords'];
    final keywords = rawKeywords is Iterable
        ? rawKeywords
            .map((keyword) => keyword.toString().trim().toLowerCase())
            .where((keyword) => keyword.isNotEmpty)
            .toList()
        : <String>[];

    return Product(
      id: json['id']?.toString() ?? docId ?? '',
      docId: docId,
      createdAt: createdAt,
      title: json['title']?.toString() ?? '',
      price: rawPrice is num ? rawPrice.toInt() : 0,
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? '기타',
      keywords: keywords,
      condition: json['condition']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      localImagePath: json['localImagePath']?.toString(),
      description: json['description']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? '',
      sellerProfile: json['sellerProfile']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? '',
      status: productStatusFromString(json['status']?.toString()),
      likeCount: parseCount(json['likeCount']),
      chatCount: parseCount(json['chatCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt,
      'title': title,
      'price': price,
      'brand': brand,
      'category': category,
      'keywords': keywords,
      'condition': condition,
      'imageUrl': imageUrl,
      'description': description,
      'size': size,
      'year': year,
      'sellerName': sellerName,
      'sellerProfile': sellerProfile,
      'sellerId': sellerId,
      'status': status.firestoreValue,
      'likeCount': likeCount,
      'chatCount': chatCount,
    };
  }
}
