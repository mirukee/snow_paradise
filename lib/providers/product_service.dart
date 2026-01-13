import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../utils/storage_uploader.dart';

class ProductService extends ChangeNotifier {
  ProductService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance {
    fetchProducts();
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSubscription;

  // 전체 상품 리스트 (실시간 Firestore 데이터)
  List<Product> _productList = [];

  // 찜한 상품 ID 목록
  final Set<String> _likedProductIds = {};

  List<Product> get productList => _productList;

  List<Product> getByCategory(String category) {
    return _productList.where((product) => product.category == category).toList();
  }

  Product? getProductById(String productId) {
    for (final product in _productList) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  // 찜한 상품만 가져오는 함수
  List<Product> get likedProducts {
    return _productList.where((product) => _likedProductIds.contains(product.id)).toList();
  }

  // 찜 여부 확인 함수
  bool isLiked(String productId) {
    return _likedProductIds.contains(productId);
  }

  // 찜하기 토글 함수 (누르면 켜지고, 다시 누르면 꺼짐)
  void toggleLike(String productId) {
    if (_likedProductIds.contains(productId)) {
      _likedProductIds.remove(productId);
    } else {
      _likedProductIds.add(productId);
    }
    // "데이터가 바뀌었으니 화면들 다시 그려라!" 라고 방송
    notifyListeners();
  }

  // 새 상품을 리스트 맨 앞에 추가
  Future<void> addProduct(Product product) async {
    var imageUrl = product.imageUrl;
    if (product.localImagePath != null && product.localImagePath!.isNotEmpty) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${product.id}';
      final ref = _storage.ref().child('uploads/$fileName');

      if (kIsWeb) {
        final bytes = await XFile(product.localImagePath!).readAsBytes();
        await ref.putData(bytes);
      } else {
        await uploadFileFromPath(ref, product.localImagePath!);
      }

      imageUrl = await ref.getDownloadURL();
    }

    await _firestore.collection('products').add({
      'id': product.id,
      'title': product.title,
      'price': product.price,
      'brand': product.brand,
      'category': product.category,
      'condition': product.condition,
      'imageUrl': imageUrl,
      'description': product.description,
      'size': product.size,
      'year': product.year,
      'sellerName': product.sellerName,
      'sellerProfile': product.sellerProfile,
      'sellerId': product.sellerId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(Product updatedProduct) async {
    final docId = _resolveDocId(updatedProduct.id, updatedProduct.docId);
    if (docId == null) {
      return;
    }

    await _firestore.collection('products').doc(docId).update({
      'title': updatedProduct.title,
      'price': updatedProduct.price,
      'category': updatedProduct.category,
      'condition': updatedProduct.condition,
      'description': updatedProduct.description,
      'size': updatedProduct.size,
      'year': updatedProduct.year,
    });
  }

  Future<void> removeProduct(String productId) async {
    final docId = _resolveDocId(productId, null);
    if (docId == null) {
      return;
    }

    await _firestore.collection('products').doc(docId).delete();
    _likedProductIds.remove(productId);
  }

  void fetchProducts() {
    _productsSubscription?.cancel();
    _productsSubscription = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _productList = snapshot.docs.map(_productFromDoc).toList();
      notifyListeners();
    });
  }

  // 검색 자동완성용 키워드 추천 (제목/브랜드 중복 제거, 최대 10개)
  List<String> getSearchSuggestions(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return [];
    }

    final suggestions = <String>{};
    for (final product in _productList) {
      if (product.title.toLowerCase().contains(normalizedQuery)) {
        suggestions.add(product.title);
      }
      if (product.brand.toLowerCase().contains(normalizedQuery)) {
        suggestions.add(product.brand);
      }
      if (suggestions.length >= 10) {
        break;
      }
    }

    return suggestions.take(10).toList();
  }

  // 검색 결과 상품 리스트 반환 (제목/브랜드 기준)
  List<Product> searchProducts(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return [];
    }

    return _productList.where((product) {
      return product.title.toLowerCase().contains(normalizedQuery) ||
          product.brand.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Product _productFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrice = data['price'];
    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : rawCreatedAt is DateTime
            ? rawCreatedAt
            : DateTime.fromMillisecondsSinceEpoch(0);

    return Product(
      id: data['id']?.toString() ?? doc.id,
      docId: doc.id,
      createdAt: createdAt,
      title: data['title']?.toString() ?? '',
      price: rawPrice is num ? rawPrice.toInt() : 0,
      brand: data['brand']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      condition: data['condition']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      size: data['size']?.toString() ?? '',
      year: data['year']?.toString() ?? '',
      sellerName: data['sellerName']?.toString() ?? '',
      sellerProfile: data['sellerProfile']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
    );
  }

  String? _resolveDocId(String productId, String? explicitDocId) {
    if (explicitDocId != null && explicitDocId.isNotEmpty) {
      return explicitDocId;
    }
    for (final product in _productList) {
      if (product.id == productId) {
        return product.docId;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }
}
