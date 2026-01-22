import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

class WishlistPage {
  final List<Product> products;
  final DocumentSnapshot<Map<String, dynamic>>? lastLikeDoc;
  final bool hasMore;

  const WishlistPage({
    required this.products,
    required this.lastLikeDoc,
    required this.hasMore,
  });
}

class _SearchCriteria {
  final String? category;
  final String? subCategory;
  final String query;
  final Map<String, dynamic> filterSpecs;
  final List<String> tradeLocationKeys;
  final String? sellerId;

  const _SearchCriteria({
    required this.category,
    required this.subCategory,
    required this.query,
    required this.filterSpecs,
    required this.tradeLocationKeys,
    required this.sellerId,
  });

  String get normalizedQuery => query.trim().toLowerCase();
}

class ProductService extends ChangeNotifier {
  ProductService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    bool isAdmin = false,
    int latestLimit = 200,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _isAdmin = isAdmin,
        _latestLimit = latestLimit {
    _listenToAuthChanges();
    fetchProducts();
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final bool _isAdmin;
  final int _latestLimit;
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
  final Map<String, DocumentSnapshot> _queryCursors = {};
  bool _hasMoreProducts = true;
  bool _isPaginationLoading = false;
  static const int _pageSize = 20;
  static const int _adminPageSize = 50;
  static const int _priceBucketSize = 100000;
  static const int _lengthBucketSize = 5;
  static const int _maxWhereInValues = 10;
  static const List<String> _brandAttributeKeys = [
    CategoryAttributes.ATTR_BRAND_SKI,
    CategoryAttributes.ATTR_BRAND_BOARD,
    CategoryAttributes.ATTR_BRAND_APPAREL,
    CategoryAttributes.ATTR_BRAND_GEAR,
  ];

  List<Product> _adminBaseProducts = [];
  List<Product> _adminExtraProducts = [];
  DocumentSnapshot<Map<String, dynamic>>? _adminLastDocument;
  bool _hasMoreAdminProducts = true;
  bool _isAdminLoadingMore = false;

  List<String> _cachedPopularKeywords = [];
  DateTime? _popularKeywordsCacheTime;
  bool _isPopularKeywordsLoading = false;
  static const Duration _popularKeywordsCacheTtl = Duration(minutes: 5);

  _SearchCriteria? _activeSearchCriteria;
  List<String> _activeQueryTokens = [];
  List<int>? _activePriceBuckets;
  String? _activeQueryKey;
  int _queryRevision = 0;

  List<Product> get productList => _productList;

  // 관리자용: 필터링되지 않은 모든 상품 반환
  List<Product> get allProductsForAdmin => _allProductList;
  bool get hasMoreAdminProducts => _hasMoreAdminProducts;
  bool get isAdminLoadingMore => _isAdminLoadingMore;

  // 페이징된 상품 리스트 (무한 스크롤용)
  List<Product> get paginatedProducts => _paginatedProducts;
  bool get hasMoreProducts => _hasMoreProducts;
  bool get isPaginationLoading => _isPaginationLoading;
  String? get activeQueryKey => _activeQueryKey;

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
        .toSet()
        .toList();

    if (productIds.isEmpty) {
      return [];
    }

    final productsByDocId = <String, Product>{};
    for (var i = 0; i < productIds.length; i += _maxWhereInValues) {
      final batchIds = productIds.skip(i).take(_maxWhereInValues).toList();
      final snapshot = await _firestore
          .collection('products')
          .where('id', whereIn: batchIds)
          .get();
      for (final doc in snapshot.docs) {
        productsByDocId[doc.id] = _productFromDoc(doc);
      }
    }

    final filteredProducts = productsByDocId.values.toList();
    return _filterBlockedProducts(filteredProducts)
        .where((product) => product.status != ProductStatus.hidden)
        .toList();
  }

  Future<WishlistPage> getWishlistProductsPage({
    required String uid,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty || limit <= 0) {
      return const WishlistPage(
        products: [],
        lastLikeDoc: null,
        hasMore: false,
      );
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(trimmedUid)
        .collection('likes')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    try {
      final likesSnapshot = await query.get();
      final hasMore = likesSnapshot.docs.length >= limit;
      final lastDoc =
          likesSnapshot.docs.isEmpty ? startAfter : likesSnapshot.docs.last;

      final productIds = likesSnapshot.docs
          .map((doc) => doc.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (productIds.isEmpty) {
        return WishlistPage(
          products: const [],
          lastLikeDoc: lastDoc,
          hasMore: hasMore,
        );
      }

      final productsById = <String, Product>{};
      for (var i = 0; i < productIds.length; i += _maxWhereInValues) {
        final batchIds = productIds.skip(i).take(_maxWhereInValues).toList();
        final snapshot = await _firestore
            .collection('products')
            .where('id', whereIn: batchIds)
            .get();
        for (final doc in snapshot.docs) {
          final product = _productFromDoc(doc);
          if (product.id.isNotEmpty) {
            productsById[product.id] = product;
          }
        }
      }

      final orderedProducts = <Product>[];
      for (final productId in productIds) {
        final product = productsById[productId];
        if (product != null) {
          orderedProducts.add(product);
        }
      }

      final filtered = _filterBlockedProducts(orderedProducts)
          .where((product) => product.status != ProductStatus.hidden)
          .toList();

      return WishlistPage(
        products: filtered,
        lastLikeDoc: lastDoc,
        hasMore: hasMore,
      );
    } catch (_) {
      return const WishlistPage(
        products: [],
        lastLikeDoc: null,
        hasMore: false,
      );
    }
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
          isLiked = true;
        } else {
          transaction.delete(likeRef);
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
    final ownerId = _auth.currentUser?.uid ?? product.sellerId;
    if (ownerId.trim().isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }

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
      final ref = _storage.ref().child('uploads/$ownerId/$fileName');

      // 메타데이터 없이 데이터 업로드
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(compressedBytes, metadata);

      final downloadUrl = await ref.getDownloadURL();
      uploadedImageUrls.add(downloadUrl);
    }
    
    // 기존 imageUrls도 포함 (이미 업로드된 이미지가 있는 경우)
    final allImageUrls = [...uploadedImageUrls, ...product.imageUrls];

    final keywords = generateKeywords(product.title);
    final searchFields = _buildProductSearchFields(product);
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
      'tradeMethods': product.tradeMethods,
      'status': product.status.firestoreValue,
      'likeCount': product.likeCount,
      'chatCount': product.chatCount,
      'createdAt': FieldValue.serverTimestamp(),
      'subCategory': product.subCategory, // 소분류 저장
      'specs': product.specs, // 상세 스펙 저장
      ...searchFields,
    });
  }

  Future<void> updateProduct(Product updatedProduct) async {
    final docRef = await _findProductRefById(updatedProduct.id);
    if (docRef == null) {
      return;
    }

    final searchFields = _buildProductSearchFields(updatedProduct);
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
      'tradeMethods': updatedProduct.tradeMethods,
      ...searchFields,
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
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (_isAdmin) {
      query = query.limit(_adminPageSize);
    } else {
      query = query.limit(_latestLimit);
    }

    _productsSubscription = query.snapshots().listen((snapshot) {
      final baseProducts = snapshot.docs.map(_productFromDoc).toList();
      if (_isAdmin) {
        _adminBaseProducts = baseProducts;
        if (_adminExtraProducts.isEmpty) {
          _adminLastDocument =
              snapshot.docs.isEmpty ? null : snapshot.docs.last;
          _hasMoreAdminProducts = snapshot.docs.length >= _adminPageSize;
        }
        _mergeAdminProducts();
      } else {
        _allProductList = baseProducts;
        _applyBlockedFilter();
      }
    });
  }

  Future<void> loadMoreAdminProducts() async {
    if (!_isAdmin || _isAdminLoadingMore || !_hasMoreAdminProducts) {
      return;
    }

    final lastDoc = _adminLastDocument;
    if (lastDoc == null) {
      return;
    }

    _isAdminLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(_adminPageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        _hasMoreAdminProducts = false;
        return;
      }

      _adminExtraProducts
          .addAll(snapshot.docs.map(_productFromDoc).toList());
      _adminLastDocument = snapshot.docs.last;
      _hasMoreAdminProducts = snapshot.docs.length >= _adminPageSize;
      _mergeAdminProducts();
    } catch (_) {
      // 관리자 추가 로드 실패는 무시하고 다음 시도를 허용합니다.
    } finally {
      _isAdminLoadingMore = false;
      notifyListeners();
    }
  }

  /// 페이징 상태 초기화
  void resetPagination() {
    _paginatedProducts = [];
    _queryCursors.clear();
    _hasMoreProducts = true;
    _isPaginationLoading = false;
    _activeQueryTokens = [];
    _activePriceBuckets = null;
    _activeSearchCriteria = null;
    _activeQueryKey = null;
    notifyListeners();
  }

  /// 페이징된 상품 첫 페이지 로드
  Future<void> fetchProductsPaginated({
    String? category,
    String? subCategory,
    String? query,
    Map<String, dynamic>? filterSpecs,
    String? sellerId,
    String? contextKey,
  }) async {
    _queryRevision++;
    resetPagination();
    final criteria = _buildSearchCriteria(
      category: category,
      subCategory: subCategory,
      query: query,
      filterSpecs: filterSpecs,
      sellerId: sellerId,
    );
    _activeSearchCriteria = criteria;
    _activeQueryTokens = _buildQueryTokens(criteria);
    _activePriceBuckets = _buildPriceBuckets(criteria);
    _activeQueryKey = contextKey;
    await loadMoreProducts();
  }

  /// 추가 상품 로드 (무한 스크롤)
  Future<void> loadMoreProducts() async {
    if (!_hasMoreProducts || _isPaginationLoading) return;
    if (_activeSearchCriteria == null) return;

    final revision = _queryRevision;
    _isPaginationLoading = true;
    notifyListeners();

    try {
      final criteria = _activeSearchCriteria!;
      final queryTokens =
          _activeQueryTokens.isEmpty ? ['__all__'] : _activeQueryTokens;
      final snapshots = await Future.wait(
        queryTokens.map((token) => _runPagedQuery(
              criteria: criteria,
              token: token,
              priceBuckets: _activePriceBuckets,
            )),
      );

      final combined = <String, Product>{};
      var hasMore = false;

      for (final snapshot in snapshots) {
        if (snapshot.docs.length >= _pageSize) {
          hasMore = true;
        }
        for (final doc in snapshot.docs) {
          combined[doc.id] = _productFromDoc(doc);
        }
      }

      final mergedProducts = combined.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (revision != _queryRevision) {
        return;
      }

      final filteredProducts =
          _applySearchFilters(_filterBlockedProducts(mergedProducts), criteria);

      final existingIds = _paginatedProducts
          .map((product) => product.docId ?? product.id)
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final product in filteredProducts) {
        final productId = product.docId ?? product.id;
        if (productId.isEmpty || existingIds.add(productId)) {
          _paginatedProducts.add(product);
        }
      }
      _hasMoreProducts = hasMore;
    } catch (_) {
      // 에러 발생 시 더 이상 로드하지 않음
      if (revision == _queryRevision) {
        _hasMoreProducts = false;
      }
    } finally {
      if (revision == _queryRevision) {
        _isPaginationLoading = false;
        notifyListeners();
      }
    }
  }

  _SearchCriteria _buildSearchCriteria({
    String? category,
    String? subCategory,
    String? query,
    Map<String, dynamic>? filterSpecs,
    String? sellerId,
  }) {
    final normalizedCategory =
        category == null || category == '전체' ? null : category;
    final normalizedSubCategory =
        subCategory == null || subCategory == '전체' ? null : subCategory;
    final normalizedSellerId =
        sellerId == null || sellerId.trim().isEmpty ? null : sellerId.trim();
    final specs = Map<String, dynamic>.from(filterSpecs ?? {});
    final tradeLocationKeys = _extractTradeLocationKeys(specs);
    return _SearchCriteria(
      category: normalizedCategory,
      subCategory: normalizedSubCategory,
      query: query ?? '',
      filterSpecs: specs,
      tradeLocationKeys: tradeLocationKeys,
      sellerId: normalizedSellerId,
    );
  }

  List<int>? _buildPriceBuckets(_SearchCriteria criteria) {
    final priceFilter = criteria.filterSpecs['price'];
    if (priceFilter is! Map) {
      return null;
    }

    final minStr = priceFilter['min']?.toString().trim() ?? '';
    final maxStr = priceFilter['max']?.toString().trim() ?? '';
    if (minStr.isEmpty || maxStr.isEmpty) {
      return null;
    }

    final minPrice = int.tryParse(minStr) ?? 0;
    final maxPrice = int.tryParse(maxStr) ?? 0;
    if (minPrice <= 0 && maxPrice <= 0) {
      return null;
    }
    if (maxPrice < minPrice) {
      return null;
    }

    final minBucket = _priceToBucket(minPrice);
    final maxBucket = _priceToBucket(maxPrice);
    final bucketCount = maxBucket - minBucket + 1;
    if (bucketCount > _maxWhereInValues) {
      return null;
    }

    return List<int>.generate(
      bucketCount,
      (index) => minBucket + index,
    );
  }

  List<String> _buildQueryTokens(_SearchCriteria criteria) {
    final profile = (criteria.category != null && criteria.subCategory != null)
        ? CategoryAttributes.getFilterProfile(
            criteria.category!,
            criteria.subCategory!,
          )
        : const <String>[];

    final tokenOrder = _buildTokenOrder(profile);
    if (tokenOrder.isEmpty) {
      return [];
    }

    final tokenValues = <String, String?>{};
    var hasTokenFilter = false;

    for (final attrKey in profile) {
      final tokenKey = CategoryAttributes.getTokenKeyForAttribute(attrKey);
      if (tokenKey == null || tokenKey == 'y') continue;
      final value = _extractTokenValueForFilter(attrKey, criteria.filterSpecs);
      if (value != null) {
        tokenValues[tokenKey] = value;
        hasTokenFilter = true;
      }
    }

    final yearValues = tokenOrder.contains('y')
        ? _extractYearValues(criteria.filterSpecs)
        : <String>[];
    if (yearValues.isNotEmpty) {
      hasTokenFilter = true;
    }

    final locationValues = criteria.tradeLocationKeys
        .map(_normalizeTokenValue)
        .whereType<String>()
        .toList();
    if (locationValues.isNotEmpty) {
      hasTokenFilter = true;
    }

    if (!hasTokenFilter) {
      return [];
    }

    final resolvedYearValues =
        yearValues.isEmpty ? <String>['*'] : yearValues;
    final resolvedLocationValues = locationValues.isEmpty
        ? <String>['*']
        : locationValues;

    final tokens = <String>[];
    for (final yearValue in resolvedYearValues) {
      for (final locationValue in resolvedLocationValues) {
        final values = Map<String, String?>.from(tokenValues);
        if (tokenOrder.contains('y')) {
          values['y'] = yearValue == '*' ? null : yearValue;
        }
        values['loc'] = locationValue == '*' ? null : locationValue;
        tokens.add(_buildTokenString(tokenOrder, values));
      }
    }

    return tokens;
  }

  List<String> _buildTokenOrder(List<String> profile) {
    final order = <String>[];
    for (final attrKey in profile) {
      final tokenKey = CategoryAttributes.getTokenKeyForAttribute(attrKey);
      if (tokenKey == null) continue;
      if (!order.contains(tokenKey)) {
        order.add(tokenKey);
      }
    }
    if (!order.contains('loc')) {
      order.add('loc');
    }
    return order;
  }

  String? _extractTokenValueForFilter(
    String attributeKey,
    Map<String, dynamic> filterSpecs,
  ) {
    final filterVal = filterSpecs[attributeKey];
    if (filterVal == null) {
      return null;
    }

    if (CategoryAttributes.isLengthAttribute(attributeKey)) {
      return _extractLengthBucketValue(filterVal);
    }

    if (filterVal is List) {
      if (filterVal.length != 1) {
        return null;
      }
      return _normalizeFilterValue(attributeKey, filterVal.first.toString());
    }

    if (filterVal is Map) {
      return null;
    }

    if (filterVal is String) {
      return _normalizeFilterValue(attributeKey, filterVal);
    }

    return null;
  }

  List<String> _extractYearValues(Map<String, dynamic> filterSpecs) {
    final raw = filterSpecs[CategoryAttributes.ATTR_YEAR];
    if (raw is List) {
      return raw
          .map((value) => _normalizeTokenValue(value.toString()))
          .whereType<String>()
          .take(2)
          .toList();
    }
    if (raw is String) {
      final normalized = _normalizeTokenValue(raw);
      return normalized == null ? [] : [normalized];
    }
    return [];
  }

  String? _extractLengthBucketValue(dynamic filterVal) {
    String? minStr;
    String? maxStr;
    if (filterVal is Map) {
      minStr = filterVal['min']?.toString();
      maxStr = filterVal['max']?.toString();
    } else if (filterVal is String) {
      minStr = filterVal;
      maxStr = filterVal;
    }

    if (minStr == null || maxStr == null) {
      return null;
    }
    final minValue = int.tryParse(minStr.replaceAll(RegExp(r'[^0-9]'), ''));
    final maxValue = int.tryParse(maxStr.replaceAll(RegExp(r'[^0-9]'), ''));
    if (minValue == null || maxValue == null || minValue != maxValue) {
      return null;
    }

    final bucket = _lengthToBucket(minValue);
    return bucket?.toString();
  }

  String _buildTokenString(List<String> order, Map<String, String?> values) {
    final segments = <String>[];
    for (final key in order) {
      final value = values[key];
      final normalized = value == null || value.isEmpty ? '*' : value;
      segments.add('$key=$normalized');
    }
    return segments.join('|');
  }

  List<String> _buildTokenCombinations(
    List<String> order,
    Map<String, String?> values,
  ) {
    var tokens = <String>[''];
    for (final key in order) {
      final value = values[key];
      if (value == null || value.isEmpty) {
        tokens = tokens.map((token) {
          return _appendTokenSegment(token, key, '*');
        }).toList();
      } else {
        tokens = tokens.expand((token) {
          return [
            _appendTokenSegment(token, key, value),
            _appendTokenSegment(token, key, '*'),
          ];
        }).toList();
      }
    }
    return tokens.toSet().toList();
  }

  String _appendTokenSegment(String token, String key, String value) {
    final segment = '$key=$value';
    if (token.isEmpty) {
      return segment;
    }
    return '$token|$segment';
  }

  Map<String, dynamic> _buildProductSearchFields(Product product) {
    final priceBucket = _priceToBucket(product.price);
    final lengthBucket = _extractLengthBucketFromSpecs(product.specs);
    final filterTokens = _buildFilterTokensForProduct(product);

    final fields = <String, dynamic>{
      'priceBucket': priceBucket,
      'filterTokens': filterTokens,
      'tradeLocationKey': product.tradeLocationKey.trim(),
    };
    if (lengthBucket != null) {
      fields['lengthBucket'] = lengthBucket;
    }
    return fields;
  }

  List<String> _buildFilterTokensForProduct(Product product) {
    final profile = CategoryAttributes.getFilterProfile(
      product.category,
      product.subCategory,
    );
    final tokenOrder = _buildTokenOrder(profile);
    if (tokenOrder.isEmpty) {
      return [];
    }

    final values = <String, String?>{};
    for (final attrKey in profile) {
      final tokenKey = CategoryAttributes.getTokenKeyForAttribute(attrKey);
      if (tokenKey == null) continue;
      if (tokenKey == 'y') {
        final yearValue = product.specs[CategoryAttributes.ATTR_YEAR] ??
            product.year;
        values['y'] = _normalizeTokenValue(yearValue);
        continue;
      }
      if (CategoryAttributes.isLengthAttribute(attrKey)) {
        final lengthValue = product.specs[attrKey];
        final bucket = _lengthToBucket(
          int.tryParse(
                lengthValue?.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
              ) ??
              -1,
        );
        values[tokenKey] = bucket == null ? null : bucket.toString();
        continue;
      }
      final rawValue = product.specs[attrKey];
      values[tokenKey] = _normalizeFilterValue(attrKey, rawValue);
    }

    values['loc'] = _normalizeTokenValue(product.tradeLocationKey);
    return _buildTokenCombinations(tokenOrder, values);
  }

  int _priceToBucket(int price) {
    if (price <= 0) {
      return 0;
    }
    return price ~/ _priceBucketSize;
  }

  int? _lengthToBucket(int lengthValue) {
    if (lengthValue <= 0) {
      return null;
    }
    return (lengthValue ~/ _lengthBucketSize) * _lengthBucketSize;
  }

  int? _extractLengthBucketFromSpecs(Map<String, String> specs) {
    final lengthKeys = [
      CategoryAttributes.ATTR_LENGTH_SKI,
      CategoryAttributes.ATTR_LENGTH_BOARD,
    ];
    for (final key in lengthKeys) {
      final raw = specs[key];
      if (raw == null || raw.trim().isEmpty) continue;
      final value = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
      if (value == null) continue;
      return _lengthToBucket(value);
    }
    return null;
  }

  List<String> _extractTradeLocationKeys(Map<String, dynamic> filterSpecs) {
    final raw = filterSpecs['tradeLocationKeys'];
    if (raw is! List) {
      return [];
    }
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(2)
        .toList();
  }

  String? _normalizeTokenValue(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizeFilterValue(String attributeKey, String? value) {
    if (!_brandAttributeKeys.contains(attributeKey)) {
      return _normalizeTokenValue(value);
    }
    return _normalizeBrandValue(value);
  }

  String? _normalizeBrandValue(String? value) {
    if (value == null) {
      return null;
    }
    final withoutParens = value.replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ');
    return _normalizeTokenValue(withoutParens);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runPagedQuery({
    required _SearchCriteria criteria,
    required String token,
    required List<int>? priceBuckets,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (criteria.category != null) {
      query = query.where('category', isEqualTo: criteria.category);
    }
    if (criteria.subCategory != null) {
      query = query.where('subCategory', isEqualTo: criteria.subCategory);
    }
    if (criteria.sellerId != null) {
      query = query.where('sellerId', isEqualTo: criteria.sellerId);
    }
    if (priceBuckets != null && priceBuckets.isNotEmpty) {
      query = query.where('priceBucket', whereIn: priceBuckets);
    }
    if (token != '__all__') {
      query = query.where('filterTokens', arrayContains: token);
    }

    final cursor = _queryCursors[token];
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      _queryCursors[token] = snapshot.docs.last;
    }
    return snapshot;
  }

  List<Product> _applySearchFilters(
    List<Product> products,
    _SearchCriteria criteria,
  ) {
    final normalizedQuery = criteria.normalizedQuery;
    final priceFilter = criteria.filterSpecs['price'] as Map<String, dynamic>?;
    final tradeLocationKeys = criteria.tradeLocationKeys
        .map(_normalizeTokenValue)
        .whereType<String>()
        .toSet();

    return products.where((product) {
      if (product.status == ProductStatus.hidden) {
        return false;
      }

      if (criteria.subCategory != null &&
          criteria.subCategory!.isNotEmpty &&
          product.subCategory != criteria.subCategory) {
        return false;
      }
      if (criteria.sellerId != null &&
          criteria.sellerId!.isNotEmpty &&
          product.sellerId != criteria.sellerId) {
        return false;
      }

      if (priceFilter != null) {
        final minStr = priceFilter['min'] as String?;
        final maxStr = priceFilter['max'] as String?;

        if (minStr != null && minStr.isNotEmpty) {
          final minPrice = int.tryParse(minStr) ?? 0;
          if (product.price < minPrice) return false;
        }
        if (maxStr != null && maxStr.isNotEmpty) {
          final maxPrice = int.tryParse(maxStr) ?? 0;
          if (product.price > maxPrice) return false;
        }
      }

      if (tradeLocationKeys.isNotEmpty) {
        final locationKey = _normalizeTokenValue(product.tradeLocationKey);
        if (locationKey == null || !tradeLocationKeys.contains(locationKey)) {
          return false;
        }
      }

      for (final entry in criteria.filterSpecs.entries) {
        final filterKey = entry.key;
        final filterVal = entry.value;

        if (filterKey == 'price' || filterKey == 'tradeLocationKeys') {
          continue;
        }

        if (filterVal == null) continue;
        if (filterVal is String && filterVal.isEmpty) continue;
        if (filterVal is List && filterVal.isEmpty) continue;

      final productVal = product.specs[filterKey];
      if (productVal == null) return false;

      if (filterVal is List) {
        if (_brandAttributeKeys.contains(filterKey)) {
          final normalizedProduct = _normalizeBrandValue(productVal);
          if (normalizedProduct == null) return false;
          final normalizedFilters = filterVal
              .map((value) => _normalizeBrandValue(value.toString()))
              .whereType<String>()
              .toSet();
          if (!normalizedFilters.contains(normalizedProduct)) return false;
        } else {
          if (!filterVal.contains(productVal)) return false;
        }
      } else if (filterVal is Map) {
        final minStr = filterVal['min'] as String?;
        final maxStr = filterVal['max'] as String?;
        try {
          String pValStr =
                productVal.replaceAll(RegExp(r'[^0-9.]'), '');
            if (pValStr.isEmpty) return false;

            final pNum = double.parse(pValStr);

            if (minStr != null && minStr.isNotEmpty) {
              final minNum = double.parse(minStr);
              if (pNum < minNum) return false;
            }
            if (maxStr != null && maxStr.isNotEmpty) {
              final maxNum = double.parse(maxStr);
              if (pNum > maxNum) return false;
            }
          } catch (_) {
            return false;
          }
        } else {
          if (_brandAttributeKeys.contains(filterKey)) {
            final normalizedProduct = _normalizeBrandValue(productVal);
            final normalizedFilter = _normalizeBrandValue(filterVal.toString());
            if (normalizedProduct == null ||
                normalizedFilter == null ||
                normalizedProduct != normalizedFilter) {
              return false;
            }
          } else {
            if (productVal != filterVal) return false;
          }
        }
      }

      if (normalizedQuery.isNotEmpty) {
        final titleMatch =
            product.title.toLowerCase().contains(normalizedQuery);
        final brandMatch =
            product.brand.toLowerCase().contains(normalizedQuery);
        final categoryMatch =
            product.category.toLowerCase().contains(normalizedQuery);
        final subCategoryMatch =
            product.subCategory.toLowerCase().contains(normalizedQuery);
        final descriptionMatch =
            product.description.toLowerCase().contains(normalizedQuery);
        final specsMatch = product.specs.values.any(
          (value) => value.toString().toLowerCase().contains(normalizedQuery),
        );
        if (!titleMatch &&
            !brandMatch &&
            !categoryMatch &&
            !subCategoryMatch &&
            !descriptionMatch &&
            !specsMatch) {
          return false;
        }
      }

      return true;
    }).toList();
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

    final popularKeywords = _getCachedPopularKeywords(limit: 20);
    if (!_isPopularKeywordsCacheFresh()) {
      unawaited(getPopularKeywordsCached(limit: 20));
    }
    if (popularKeywords.isNotEmpty) {
      for (final keyword in popularKeywords) {
        if (suggestions.length >= 5) break;
        if (!keyword.toLowerCase().contains(normalizedQuery)) continue;
        if (addedValues.add(keyword)) {
          suggestions.add(SearchSuggestion(
            value: keyword,
            type: SuggestionType.title,
          ));
        }
      }
      if (suggestions.length >= 5) {
        return suggestions.take(10).toList();
      }
    }

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
        if (suggestions.length >= 10) break;
        if (brand.contains('기타')) continue; // '기타'는 제외
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
      if (suggestions.length >= 10) break;
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

    try {
      final callable = _functions.httpsCallable('recordSearchKeyword');
      await callable.call({'keyword': normalized});
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

  Future<List<String>> getPopularKeywordsCached({int limit = 10}) async {
    if (_isPopularKeywordsCacheFresh() &&
        _cachedPopularKeywords.length >= limit) {
      return _cachedPopularKeywords.take(limit).toList();
    }

    if (_isPopularKeywordsLoading) {
      return _cachedPopularKeywords.take(limit).toList();
    }

    _isPopularKeywordsLoading = true;
    try {
      final keywords = await getPopularKeywords(limit: limit);
      _cachedPopularKeywords = keywords;
      _popularKeywordsCacheTime = DateTime.now();
      return keywords;
    } finally {
      _isPopularKeywordsLoading = false;
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
        _blockedUserIds.remove(user.uid.trim());
        _applyBlockedFilter();
      });
    });
  }

  void _applyBlockedFilter() {
    _productList = _filterBlockedProducts(_allProductList);
    notifyListeners();
  }

  void _mergeAdminProducts() {
    final combined = <String, Product>{};
    for (final product in _adminBaseProducts) {
      final key = product.docId ?? product.id;
      if (key.isEmpty) continue;
      combined[key] = product;
    }
    for (final product in _adminExtraProducts) {
      final key = product.docId ?? product.id;
      if (key.isEmpty) continue;
      combined[key] = product;
    }

    final merged = combined.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _allProductList = merged;
    _applyBlockedFilter();
  }

  bool _isPopularKeywordsCacheFresh() {
    if (_popularKeywordsCacheTime == null) return false;
    final now = DateTime.now();
    return now.difference(_popularKeywordsCacheTime!) <
        _popularKeywordsCacheTtl;
  }

  List<String> _getCachedPopularKeywords({int limit = 10}) {
    if (_cachedPopularKeywords.isEmpty) {
      return [];
    }
    return _cachedPopularKeywords.take(limit).toList();
  }

  List<Product> _filterBlockedProducts(List<Product> products) {
    if (_blockedUserIds.isEmpty) {
      return List<Product>.from(products);
    }
    final currentUid = _auth.currentUser?.uid.trim();
    return products
        .where(
          (product) =>
              product.sellerId.isEmpty ||
              (currentUid != null && currentUid.isNotEmpty
                  ? product.sellerId == currentUid ||
                      !_blockedUserIds.contains(product.sellerId)
                  : !_blockedUserIds.contains(product.sellerId)),
        )
        .toList();
  }
}
