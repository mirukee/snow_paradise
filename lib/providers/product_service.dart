import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../utils/image_compressor.dart';
import '../constants/categories.dart';

/// 자동완성 추천 타입
enum SuggestionType {
  title,    // 상품 제목
  brand,    // 브랜드
  category, // 카테고리
}

/// 자동완성 추천 아이템
class SearchSuggestion {
  final String value;
  final SuggestionType type;
  final String? brandKey; // 브랜드일 경우 해당 속성 키 (예: brand_board)
  final String? categoryLabel; // 카테고리 라벨 (예: 스키, 보드, 의류, 장비)

  const SearchSuggestion({
    required this.value,
    required this.type,
    this.brandKey,
    this.categoryLabel,
  });

  String get displayText {
    switch (type) {
      case SuggestionType.brand:
        if (categoryLabel != null) {
          return '$value ($categoryLabel 브랜드)';
        }
        return '$value (브랜드)';
      case SuggestionType.category:
        return '$value (카테고리)';
      case SuggestionType.title:
        return value;
    }
  }
}

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

  // 페이징 관련 상태
  List<Product> _paginatedProducts = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMoreProducts = true;
  bool _isPaginationLoading = false;
  static const int _pageSize = 20;

  List<Product> get productList => _productList;

  // 관리자용: 필터링되지 않은 모든 상품 반환
  List<Product> get allProductsForAdmin => _allProductList;

  // 페이징된 상품 리스트 (무한 스크롤용)
  List<Product> get paginatedProducts => _paginatedProducts;
  bool get hasMoreProducts => _hasMoreProducts;
  bool get isPaginationLoading => _isPaginationLoading;

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
  Future<void> addProduct(Product product, {List<XFile>? images}) async {
    // 여러 이미지 업로드 처리
    final List<String> uploadedImageUrls = [];
    
    // 로컬 이미지 리스트 준비 (직접 전달된 images가 우선)
    final filesToUpload = images ?? product.localImagePaths.map((path) => XFile(path)).toList();

    for (int i = 0; i < filesToUpload.length; i++) {
      final file = filesToUpload[i];
      // ImageCompressor를 통해 바이트 얻기 (JPEG 변환 및 압축)
      // path가 없는 메모리 파일일 수 있으므로 XFile 객체 자체를 전달
      final compressedBytes = await ImageCompressor.compressImage(file);
      
      if (compressedBytes == null) continue;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${product.id}_$i.jpg'; // 항상 .jpg 확장자 사용
      final ref = _storage.ref().child('uploads/$fileName');

      // 메타데이터 없이 데이터 업로드
      await ref.putData(compressedBytes);

      final downloadUrl = await ref.getDownloadURL();
      uploadedImageUrls.add(downloadUrl);
    }
    
    // 기존 imageUrls도 포함 (이미 업로드된 이미지가 있는 경우)
    final allImageUrls = [...uploadedImageUrls, ...product.imageUrls];

    final keywords = generateKeywords(product.title);
    await _firestore.collection('products').add({
      'id': product.id,
      'title': product.title,
      'price': product.price,
      'brand': product.brand,
      'category': product.category,
      'keywords': keywords,
      'condition': product.condition,
      'imageUrls': allImageUrls,
      'imageUrl': allImageUrls.isNotEmpty ? allImageUrls.first : '', // 하위 호환
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
      'subCategory': product.subCategory, // 소분류 저장
      'specs': product.specs, // 상세 스펙 저장
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
      'brand': updatedProduct.brand,
      'category': updatedProduct.category,
      'keywords': generateKeywords(updatedProduct.title),
      'condition': updatedProduct.condition,
      'description': updatedProduct.description,
      'size': updatedProduct.size,
      'year': updatedProduct.year,
      'subCategory': updatedProduct.subCategory, // 소분류 업데이트
      'specs': updatedProduct.specs, // 상세 스펙 업데이트
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

  /// 페이징 상태 초기화
  void resetPagination() {
    _paginatedProducts = [];
    _lastDocument = null;
    _hasMoreProducts = true;
    _isPaginationLoading = false;
    notifyListeners();
  }

  /// 페이징된 상품 첫 페이지 로드
  Future<void> fetchProductsPaginated({
    String? category,
    String? query,
  }) async {
    resetPagination();
    await loadMoreProducts(category: category, query: query);
  }

  /// 추가 상품 로드 (무한 스크롤)
  Future<void> loadMoreProducts({
    String? category,
    String? query,
  }) async {
    if (!_hasMoreProducts || _isPaginationLoading) return;

    _isPaginationLoading = true;
    notifyListeners();

    try {
      // 기본 쿼리 생성
      Query<Map<String, dynamic>> firestoreQuery = _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      // 커서 적용 (다음 페이지)
      if (_lastDocument != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(_lastDocument!);
      }

      final snapshot = await firestoreQuery.get();

      if (snapshot.docs.isEmpty) {
        _hasMoreProducts = false;
      } else {
        _lastDocument = snapshot.docs.last;

        final newProducts = snapshot.docs.map(_productFromDoc).toList();

        // 로컬 필터링: 차단 사용자, 카테고리, 검색어
        final filteredProducts = _filterBlockedProducts(newProducts).where((product) {
          // Hidden 상태 제외
          if (product.status == ProductStatus.hidden) return false;

          // 카테고리 필터
          if (category != null && category != '전체') {
            if (product.category != category) return false;
          }

          // 검색어 필터
          if (query != null && query.trim().isNotEmpty) {
            final normalizedQuery = query.trim().toLowerCase();
            final titleMatch = product.title.toLowerCase().contains(normalizedQuery);
            final brandMatch = product.brand.toLowerCase().contains(normalizedQuery);
            final subCategoryMatch = product.subCategory.toLowerCase().contains(normalizedQuery);
            final descriptionMatch = product.description.toLowerCase().contains(normalizedQuery);
            final specsMatch = product.specs.values.any(
              (value) => value.toString().toLowerCase().contains(normalizedQuery),
            );
            if (!titleMatch && !brandMatch && !subCategoryMatch && !descriptionMatch && !specsMatch) {
              return false;
            }
          }

          return true;
        }).toList();

        _paginatedProducts.addAll(filteredProducts);

        // 마지막 페이지인지 확인
        if (snapshot.docs.length < _pageSize) {
          _hasMoreProducts = false;
        }
      }
    } catch (_) {
      // 에러 발생 시 더 이상 로드하지 않음
      _hasMoreProducts = false;
    } finally {
      _isPaginationLoading = false;
      notifyListeners();
    }
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

  /// 타입 정보가 포함된 자동완성 추천 (브랜드 필터 자동 적용 지원)
  List<SearchSuggestion> getSearchSuggestionsWithType(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return [];
    }

    final suggestions = <SearchSuggestion>[];
    final addedValues = <String>{};

    // 1. 브랜드 매칭 (CategoryAttributes에서 정의된 브랜드 목록)
    // 카테고리별로 구분하여 표시 (예: 살로몬(스키) vs 살로몬(장비))
    final brandDefinitions = [
      (CategoryAttributes.ATTR_BRAND_SKI, '스키', CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_SKI]),
      (CategoryAttributes.ATTR_BRAND_BOARD, '보드', CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_BOARD]),
      (CategoryAttributes.ATTR_BRAND_APPAREL, '의류', CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_APPAREL]),
      (CategoryAttributes.ATTR_BRAND_GEAR, '장비', CategoryAttributes.definitions[CategoryAttributes.ATTR_BRAND_GEAR]),
    ];

    final addedKeys = <String>{}; // "브랜드_카테고리키" 조합으로 중복 체크

    for (final (key, categoryLabel, definition) in brandDefinitions) {
      if (definition == null) continue;
      for (final brand in definition.options) {
        if (brand == '기타') continue; // '기타'는 제외
        final uniqueKey = '${brand}_$key';
        if (brand.toLowerCase().contains(normalizedQuery) && !addedKeys.contains(uniqueKey)) {
          suggestions.add(SearchSuggestion(
            value: brand,
            type: SuggestionType.brand,
            brandKey: key,
            categoryLabel: categoryLabel,
          ));
          addedKeys.add(uniqueKey);
        }
      }
    }

    // 2. 상품 제목/브랜드 매칭 (기존 로직)
    for (final product in _productList) {
      if (product.status == ProductStatus.hidden) continue;
      if (suggestions.length >= 10) break;

      // 상품 브랜드가 이미 추가되지 않았으면 추가
      if (product.brand.toLowerCase().contains(normalizedQuery) && !addedValues.contains(product.brand)) {
        suggestions.add(SearchSuggestion(
          value: product.brand,
          type: SuggestionType.brand,
        ));
        addedValues.add(product.brand);
      }

      // 상품 제목
      if (product.title.toLowerCase().contains(normalizedQuery) && !addedValues.contains(product.title)) {
        suggestions.add(SearchSuggestion(
          value: product.title,
          type: SuggestionType.title,
        ));
        addedValues.add(product.title);
      }
    }

    return suggestions.take(10).toList();
  }

  // 검색 결과 상품 리스트 반환 (로컬 필터링)
  // Firestore 쿼리(array-contains) 대신 로컬에서 부분 문자열 일치(contains)를 사용하여
  // "Board" 검색 시 "Snowboard"가 검색되도록 개선
  Future<List<Product>> searchProducts(String query, String? category) async {
    final normalizedQuery = query.trim().toLowerCase();

    return _productList.where((product) {
      // 1. 카테고리 필터
      if (category != null && category != '전체') {
        if (product.category != category) return false;
      }

      // 2. 검색어 필터 (제목, 브랜드, 서브카테고리, 상세 스펙, 설명 포함)
      if (normalizedQuery.isNotEmpty) {
        final titleMatch = product.title.toLowerCase().contains(normalizedQuery);
        final brandMatch = product.brand.toLowerCase().contains(normalizedQuery);
        final subCategoryMatch = product.subCategory.toLowerCase().contains(normalizedQuery);
        final descriptionMatch = product.description.toLowerCase().contains(normalizedQuery);
        
        // 스펙(Specs) 값 중 하나라도 검색어를 포함하는지 확인
        final specsMatch = product.specs.values.any(
          (value) => value.toString().toLowerCase().contains(normalizedQuery),
        );

        if (!titleMatch && !brandMatch && !subCategoryMatch && !descriptionMatch && !specsMatch) {
          return false;
        }
      }
      
      // Hidden 상태는 _productList에서 이미 필터링 되었을 수 있으나 안전장치
      return product.status != ProductStatus.hidden;
    }).toList();
  }

  /// 검색어를 Firestore에 기록 (인기 검색어 집계용)
  /// 검색 횟수를 증가시키고 마지막 검색 시간을 업데이트
  Future<void> recordSearchKeyword(String keyword) async {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty || normalized.length < 2) return;

    final docRef = _firestore.collection('search_keywords').doc(normalized);
    
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (snapshot.exists) {
          // 기존 검색어: 카운트 증가
          transaction.update(docRef, {
            'count': FieldValue.increment(1),
            'lastSearchedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // 새 검색어: 문서 생성
          transaction.set(docRef, {
            'keyword': normalized,
            'count': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSearchedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (_) {
      // 검색어 기록 실패는 무시 (사용자 경험에 영향 없음)
    }
  }

  /// 인기 검색어 상위 N개 조회
  Future<List<String>> getPopularKeywords({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('search_keywords')
          .orderBy('count', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['keyword'] as String? ?? '')
          .where((keyword) => keyword.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
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
