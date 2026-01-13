class Product {
  final String id;
  final String? docId;
  final DateTime createdAt;
  final String title;
  final int price;
  final String brand;
  final String category;
  final String condition;
  final String imageUrl;
  final String? localImagePath;
  final String description;
  final String size;
  final String year;
  final String sellerName;
  final String sellerProfile;
  final String sellerId;

  Product({
    required this.id,
    this.docId,
    DateTime? createdAt,
    required this.title,
    required this.price,
    required this.brand,
    required this.category,
    required this.condition,
    required this.imageUrl,
    this.localImagePath,
    required this.description,
    required this.size,
    required this.year,
    required this.sellerName,
    required this.sellerProfile,
    this.sellerId = '',
  }) : createdAt = createdAt ?? DateTime.now();
}
