import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import 'detail_screen.dart';
import '../widgets/product_image.dart';
import '../constants/categories.dart';
import '../widgets/dynamic_attribute_form.dart';

/// 카테고리별 상품 목록 화면
/// 서브카테고리 탭, 필터 칩, 2열 그리드 레이아웃을 제공합니다.
class CategoryProductScreen extends StatefulWidget {
  final String category;

  const CategoryProductScreen({super.key, required this.category});

  @override
  State<CategoryProductScreen> createState() => _CategoryProductScreenState();
}

class _CategoryProductScreenState extends State<CategoryProductScreen> {
  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textGrey = Color(0xFF637688);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // 선택된 서브카테고리 인덱스
  int _selectedSubCategoryIndex = 0;
  final ScrollController _scrollController = ScrollController();
  late final String _contextKey;
  bool _isAutoFetching = false;
  
  // 적용된 필터 스펙 (Key: Attribute Key, Value: Selected Option)
  Map<String, dynamic> _filterSpecs = {};

  // 카테고리별 서브카테고리 정의 (상수 파일 사용)
  // 선택된 탭을 위해 '전체'를 맨 앞에 추가
  List<String> get _currentSubCategories {
    final subs = CategoryConstants.getSubCategories(widget.category);
    return ['전체', ...subs];
  }

  String _formatPrice(int price) {
    final buffer = StringBuffer();
    final priceString = price.toString();
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(priceString[i]);
    }
    buffer.write('원');
    return buffer.toString();
  }

  String _formatTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${createdAt.month}/${createdAt.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrentRoute &&
        productService.activeQueryKey != _contextKey &&
        !productService.isPaginationLoading &&
        !_isAutoFetching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshProducts(context.read<ProductService>());
      });
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 (AppBar 대체)
            _buildHeader(context),
            // 서브카테고리 탭
            _buildSubCategoryTabs(),
            // 상품 그리드
            Expanded(
              child: () {
                final products = productService.paginatedProducts;
                if (products.isEmpty &&
                    (productService.isPaginationLoading ||
                        _isAutoFetching)) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return products.isEmpty
                    ? _buildEmptyState()
                    : _buildProductGrid(context, products, productService);
              }(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _contextKey =
        'category-${widget.category}-${DateTime.now().microsecondsSinceEpoch}';
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      final productService = context.read<ProductService>();
      if (productService.hasMoreProducts &&
          !productService.isPaginationLoading) {
        productService.loadMoreProducts();
      }
    }
  }

  Future<void> _refreshProducts(
    ProductService productService, {
    bool force = false,
  }) async {
    if (_isAutoFetching && !force) {
      return;
    }
    _isAutoFetching = true;
    final subCategory = _currentSubCategories[_selectedSubCategoryIndex];
    await productService.fetchProductsPaginated(
      category: widget.category,
      subCategory: subCategory == '전체' ? null : subCategory,
      filterSpecs: _filterSpecs,
      contextKey: _contextKey,
    );
    _isAutoFetching = false;
  }

  /// 헤더 - 뒤로가기, 타이틀, 필터 버튼
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // 뒤로가기 버튼
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: textDark,
              size: 22,
            ),
          ),
          // 타이틀
          Expanded(
            child: Text(
              widget.category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // 필터 버튼
          IconButton(
            onPressed: () => _showFilterBottomSheet(context),
            icon: const Icon(
              Icons.tune,
              color: textDark,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// 서브카테고리 탭 (가로 스크롤)
  Widget _buildSubCategoryTabs() {
    return Container(
      color: surfaceLight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_currentSubCategories.length, (index) {
            final isSelected = _selectedSubCategoryIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 24),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSubCategoryIndex = index;
                    _filterSpecs.clear(); // 탭 변경 시 필터 초기화
                  });
                  _refreshProducts(
                    context.read<ProductService>(),
                    force: true,
                  );
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _currentSubCategories[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? primaryBlue : textGrey,
                        ),
                      ),
                    ),
                    // 선택 인디케이터
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : Colors.transparent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 빈 상태 표시
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: textGrey,
          ),
          SizedBox(height: 16),
          Text(
            '등록된 상품이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textGrey,
            ),
          ),
        ],
      ),
    );
  }

  /// 상품 그리드 (2열)
  Widget _buildProductGrid(
    BuildContext context,
    List<Product> products,
    ProductService productService,
  ) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.55, // 3:4 비율 + 텍스트 영역
      ),
      itemCount:
          products.length + (productService.hasMoreProducts ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= products.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return _buildProductCard(context, products[index], productService);
      },
    );
  }

  /// 상품 카드 UI
  Widget _buildProductCard(
    BuildContext context,
    Product product,
    ProductService productService,
  ) {
    final isLiked = productService.isLiked(product.id);
    final isReserved = product.status == ProductStatus.reserved;
    final isSoldOut = product.status == ProductStatus.soldOut ||
        product.status == ProductStatus.hidden;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(product: product),
          ),
        );
      },
      child: Opacity(
        opacity: isSoldOut ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            Expanded(
              child: Stack(
                children: [
                  // 상품 이미지
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.grey[100],
                        child: buildProductImage(
                          product,
                          fit: BoxFit.cover,
                          errorIconSize: 32,
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 좋아요 버튼
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        final currentUser =
                            context.read<UserService>().currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그인이 필요합니다.')),
                          );
                          return;
                        }
                        productService.toggleLike(product.id, currentUser.uid);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isLiked ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 예약중 오버레이
                  if (isReserved)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '예약중',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 상품 정보
            Text(
              product.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textDark,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${product.sellerName.isNotEmpty ? product.sellerName : '판매자'} · ${_formatTimeAgo(product.createdAt)}',
              style: const TextStyle(
                fontSize: 11,
                color: textGrey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _formatPrice(product.price),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필터 바텀 시트 표시
  void _showFilterBottomSheet(BuildContext context) async {
    final subCategory = _currentSubCategories[_selectedSubCategoryIndex];
    
    // '전체' 탭에서는 상세 필터 미지원
    if (subCategory == '전체') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 분류를 선택하면 필터를 사용할 수 있습니다.')),
      );
      return;
    }

    final productService = context.read<ProductService>();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        category: widget.category,
        subCategory: subCategory,
        initialSpecs: _filterSpecs,
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _filterSpecs = result;
      });
      _refreshProducts(
        productService,
        force: true,
      );
    }
  }
}

/// 필터 바텀 시트 위젯
class _FilterBottomSheet extends StatefulWidget {
  final String category;
  final String subCategory;
  final Map<String, dynamic> initialSpecs;

  const _FilterBottomSheet({
    required this.category,
    required this.subCategory,
    required this.initialSpecs,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textGrey = Color(0xFF637688);

  // 로컬 필터 상태
  late final Map<String, dynamic> _selectedSpecs;

  @override
  void initState() {
    super.initState();
    _selectedSpecs = Map.from(widget.initialSpecs);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '상세 필터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                GestureDetector(
                  onTap: _resetFilters,
                  child: const Text(
                    '초기화',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textGrey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 필터 컨텐츠
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: DynamicAttributeForm(
                category: widget.category,
                subCategory: widget.subCategory,
                selectedSpecs: _selectedSpecs,
                isFilterMode: true, // 상세 필터 모드 활성화 (다중 선택/범위 입력)
                onSpecChanged: (key, value) {
                  setState(() {
                    _selectedSpecs[key] = value;
                  });
                },
              ),
            ),
          ),
          // 적용 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selectedSpecs),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  '적용하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 초기화
  void _resetFilters() {
    setState(() {
      _selectedSpecs.clear();
    });
  }
}
