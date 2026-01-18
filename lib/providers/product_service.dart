import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../utils/storage_uploader.dart';

class ProductService extends ChangeNotifier {
  ProductService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _listenToAuthChanges();
    fetchProducts();
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _blockedUsersSubscription;
  StreamSubscription<User?>? _authSubscription;

  // 전체 상품 리스트 (실시간 Firestore 데이터)
  List<Product> _productList = [];
  List<Product> _allProductList = [];
  Set<String> _blockedUserIds = {};

  // 찜한 상품 ID 목록
  final Set<String> _likedProductIds = {};

  List<Product> get productList => _productList;

  List<Product> getByCategory(String category) {
    return _productList
        .where(
          (product) =>
              product.category == category &&
              product.status != ProductStatus.hidden,
        )
        .toList();
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
    return _productList
        .where(
          (product) =>
              _likedProductIds.contains(product.id) &&
              product.status != ProductStatus.hidden,
        )
        .toList();
  }

  Future<List<Product>> getWishlistProducts(String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return [];
    }

    final likesSnapshot = await _firestore
        .collection('users')
        .doc(trimmedUid)
        .collection('likes')
        .get();

    if (likesSnapshot.docs.isEmpty) {
      return [];
    }

    final productIds = likesSnapshot.docs
        .map((doc) => doc.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (productIds.isEmpty) {
      return [];
    }

    final products = await Future.wait(productIds.map((productId) async {
      final snapshot = await _firestore
          .collection('products')
          .where('id', isEqualTo: productId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return _productFromDoc(snapshot.docs.first);
    }));

    final filteredProducts = products.whereType<Product>().toList();
    return _filterBlockedProducts(filteredProducts)
        .where((product) => product.status != ProductStatus.hidden)
        .toList();
  }

  // 찜 여부 확인 함수
  bool isLiked(String productId) {
    return _likedProductIds.contains(productId);
  }

  // 찜하기 토글 함수 (누르면 켜지고, 다시 누르면 꺼짐)
  Future<void> toggleLike(String productId, String uid) async {
    final trimmedProductId = productId.trim();
    final trimmedUid = uid.trim();
    if (trimmedProductId.isEmpty || trimmedUid.isEmpty) {
      return;
    }

    final productRef = await _findProductRefById(trimmedProductId);
    if (productRef == null) {
      return;
    }

    final likeRef = _firestore
        .collection('users')
        .doc(trimmedUid)
        .collection('likes')
        .doc(trimmedProductId);

    bool? isLiked;
    try {
      await _firestore.runTransaction((transaction) async {
        final likeSnapshot = await transaction.get(likeRef);
        if (!likeSnapshot.exists) {
          transaction.set(likeRef, {
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(productRef, {
            'likeCount': FieldValue.increment(1),
          });
          isLiked = true;
        } else {
          transaction.delete(likeRef);
          transaction.update(productRef, {
            'likeCount': FieldValue.increment(-1),
          });
          isLiked = false;
        }
      });
    } catch (_) {
      return;
    }

    if (isLiked == true) {
      _likedProductIds.add(trimmedProductId);
    } else if (isLiked == false) {
      _likedProductIds.remove(trimmedProductId);
    }
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

    final keywords = generateKeywords(product.title);
    await _firestore.collection('products').add({
      'id': product.id,
      'title': product.title,
      'price': product.price,
      'brand': product.brand,
      'category': product.category,
      'keywords': keywords,
      'condition': product.condition,
      'imageUrl': imageUrl,
      'description': product.description,
      'size': product.size,
      'year': product.year,
      'sellerName': product.sellerName,
      'sellerProfile': product.sellerProfile,
      'sellerId': product.sellerId,
      'status': product.status.firestoreValue,
      'likeCount': product.likeCount,
      'chatCount': product.chatCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(Product updatedProduct) async {
    final docRef = await _findProductRefById(updatedProduct.id);
    if (docRef == null) {
      return;
    }

    await docRef.update({
      'title': updatedProduct.title,
      'price': updatedProduct.price,
      'category': updatedProduct.category,
      'keywords': generateKeywords(updatedProduct.title),
      'condition': updatedProduct.condition,
      'description': updatedProduct.description,
      'size': updatedProduct.size,
      'year': updatedProduct.year,
    });
  }

  Future<void> updateProductStatus(
    String productId,
    ProductStatus newStatus,
  ) async {
    final docRef = await _findProductRefById(productId);
    if (docRef == null) {
      throw StateError('상품 문서를 찾을 수 없습니다.');
    }

    await docRef.update({
      'status': newStatus.firestoreValue,
    });
  }

  Future<void> deleteProduct(String docId, String imageUrl) async {
    if (docId.isEmpty) {
      return;
    }

    if (imageUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } catch (_) {
        // Ignore storage delete failures so DB delete always runs.
      }
    }

    await _firestore.collection('products').doc(docId).delete();

    final removedProducts =
        _productList.where((product) => product.docId == docId).toList();
    _productList.removeWhere((product) => product.docId == docId);
    for (final product in removedProducts) {
      _likedProductIds.remove(product.id);
    }
    notifyListeners();
  }

  Future<void> removeProduct(String productId) async {
    final docRef = await _findProductRefById(productId);
    if (docRef == null) {
      return;
    }
    var imageUrl = '';
    for (final product in _productList) {
      if (product.docId == docRef.id || product.id == productId) {
        imageUrl = product.imageUrl;
        break;
      }
    }

    await deleteProduct(docRef.id, imageUrl);
  }

  void fetchProducts() {
    _productsSubscription?.cancel();
    _productsSubscription = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _allProductList = snapshot.docs.map(_productFromDoc).toList();
      _applyBlockedFilter();
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
      if (product.status == ProductStatus.hidden) {
        continue;
      }
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

  // 검색 결과 상품 리스트 반환 (Firestore 쿼리)
  Future<List<Product>> searchProducts(String query, String? category) async {
    Query<Map<String, dynamic>> queryRef = _firestore.collection('products');
    if (category != null && category != '전체') {
      queryRef = queryRef.where('category', isEqualTo: category);
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      final words = normalizedQuery.split(RegExp(r'\s+'));
      final targetWord = words.firstWhere(
        (word) => word.trim().isNotEmpty,
        orElse: () => '',
      );
      if (targetWord.isNotEmpty) {
        queryRef = queryRef.where('keywords', arrayContains: targetWord);
      }
    }

    queryRef = queryRef.orderBy('createdAt', descending: true);
    final snapshot = await queryRef.get();
    final products = snapshot.docs.map(_productFromDoc).toList();
    return _filterBlockedProducts(products)
        .where((product) => product.status != ProductStatus.hidden)
        .toList();
  }

  Product _productFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Product.fromJson(data, docId: doc.id);
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findProductRefById(
    String productId,
  ) async {
    final trimmedId = productId.trim();
    if (trimmedId.isEmpty) {
      return null;
    }
    final snapshot = await _firestore
        .collection('products')
        .where('id', isEqualTo: trimmedId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first.reference;
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) {
      _blockedUsersSubscription?.cancel();
      _blockedUserIds = {};
      if (user == null) {
        _applyBlockedFilter();
        return;
      }
      _blockedUsersSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocked_users')
          .snapshots()
          .listen((snapshot) {
        _blockedUserIds = snapshot.docs
            .map((doc) => doc.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
        _applyBlockedFilter();
      });
    });
  }

  void _applyBlockedFilter() {
    _productList = _filterBlockedProducts(_allProductList);
    notifyListeners();
  }

  List<Product> _filterBlockedProducts(List<Product> products) {
    if (_blockedUserIds.isEmpty) {
      return List<Product>.from(products);
    }
    return products
        .where(
          (product) =>
              product.sellerId.isEmpty ||
              !_blockedUserIds.contains(product.sellerId),
        )
        .toList();
  }
}
