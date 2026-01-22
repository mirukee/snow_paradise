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
  final String subCategory;
  final Map<String, String> specs; // 상세 스펙 (동적 속성) // 소분류 추가
  /// 여러 이미지 URL 목록 (최대 10개)
  final List<String> imageUrls;
  /// 로컬 이미지 경로 목록 (업로드 전)
  final List<String> localImagePaths;
  final String description;
  final String size;
  final String year;
  final String sellerName;
  final String sellerProfile;
  final String sellerId;
  final List<String> tradeMethods;
  final String tradeLocationKey;
  final ProductStatus status;
  final int likeCount;
  final int chatCount;

  /// 대표 이미지 URL (첫 번째 이미지, 하위 호환용)
  String get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';
  
  /// 로컬 대표 이미지 경로 (하위 호환용)
  String? get localImagePath => localImagePaths.isNotEmpty ? localImagePaths.first : null;

  Product({
    required this.id,
    this.docId,
    DateTime? createdAt,
    required this.title,
    required this.price,
    required this.brand,
    this.category = '기타',
    this.subCategory = '',
    this.specs = const {}, // 기본값
    this.keywords = const [],
    required this.condition,
    // 단일 imageUrl 지원 (하위 호환)
    String? imageUrl,
    List<String>? imageUrls,
    // 단일 localImagePath 지원 (하위 호환)
    String? localImagePath,
    List<String>? localImagePaths,
    required this.description,
    required this.size,
    required this.year,
    required this.sellerName,
    required this.sellerProfile,
    required this.sellerId,
    this.tradeMethods = const [],
    this.tradeLocationKey = '',
    this.status = ProductStatus.forSale,
    this.likeCount = 0,
    this.chatCount = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       // imageUrls 처리: 전달된 리스트 우선, 없으면 단일 URL로 리스트 생성
       imageUrls = imageUrls ?? 
           (imageUrl != null && imageUrl.isNotEmpty ? [imageUrl] : []),
       // localImagePaths 처리: 전달된 리스트 우선, 없으면 단일 경로로 리스트 생성
       localImagePaths = localImagePaths ?? 
           (localImagePath != null && localImagePath.isNotEmpty ? [localImagePath] : []);

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

    // imageUrls 파싱 (배열 또는 단일 문자열 지원)
    List<String> imageUrls = [];
    final rawImageUrls = json['imageUrls'];
    final rawImageUrl = json['imageUrl'];
    
    if (rawImageUrls is Iterable) {
      imageUrls = rawImageUrls
          .map((url) => url.toString().trim())
          .where((url) => url.isNotEmpty)
          .toList();
    } else if (rawImageUrl != null && rawImageUrl.toString().trim().isNotEmpty) {
      imageUrls = [rawImageUrl.toString().trim()];
    }

    return Product(
      id: json['id']?.toString() ?? docId ?? '',
      docId: docId,
      createdAt: createdAt,
      title: json['title']?.toString() ?? '',
      price: rawPrice is num ? rawPrice.toInt() : 0,
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? '기타',
      subCategory: json['subCategory']?.toString() ?? '', // JSON 파싱 추가
      specs: Map<String, String>.from(json['specs'] ?? {}), // JSON 파싱 추가
      keywords: keywords,
      condition: json['condition']?.toString() ?? '',
      imageUrls: imageUrls,
      description: json['description']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? '',
      sellerProfile: json['sellerProfile']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? '',
      tradeMethods: _parseTradeMethods(json['tradeMethods']),
      tradeLocationKey: json['tradeLocationKey']?.toString() ?? '',
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
      'subCategory': subCategory,
      'specs': specs, // JSON 변환 추가
      'keywords': keywords,
      'condition': condition,
      'imageUrls': imageUrls,
      'imageUrl': imageUrl, // 하위 호환용
      'description': description,
      'size': size,
      'year': year,
      'sellerName': sellerName,
      'sellerProfile': sellerProfile,
      'sellerId': sellerId,
      'tradeMethods': tradeMethods,
      'tradeLocationKey': tradeLocationKey,
      'status': status.firestoreValue,
      'likeCount': likeCount,
      'chatCount': chatCount,
    };
  }
}

List<String> _parseTradeMethods(dynamic raw) {
  if (raw is Iterable) {
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }
  if (raw is String) {
    final normalized = raw.trim();
    return normalized.isEmpty ? [] : [normalized];
  }
  return [];
}
