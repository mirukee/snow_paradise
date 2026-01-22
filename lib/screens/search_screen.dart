import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/categories.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import 'detail_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/dynamic_attribute_form.dart';

/// 검색 화면 (Stitch 디자인 적용)
/// 텍스트 검색 + 카테고리 필터 + 상세 필터 기능 제공
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // 색상 상수 (Stitch 디자인)
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color backgroundLight = Color(0xFFF6F7F8);
  static const Color textDark = Color(0xFF111518);
  static const Color textMuted = Color(0xFF637688);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  final TextEditingController _controller = TextEditingController();
  Timer? _searchDebounceTimer;
  String _query = '';
  bool _isSubmitted = false;
  bool _isLoading = false;
  
  // 대분류 카테고리
  String _selectedCategory = '전체';
  late final List<String> _categories = [
    '전체',
    ...CategoryConstants.subCategories.keys,
  ];
  
  // 소분류 카테고리
  String _selectedSubCategory = '전체';
  List<String> get _subCategories {
    if (_selectedCategory == '전체') return [];
    return ['전체', ...CategoryConstants.getSubCategories(_selectedCategory)];
  }
  
  // 적용된 필터 스펙
  Map<String, dynamic> _filterSpecs = {};
  
  List<SearchSuggestion> _suggestions = []; // 타입 정보 포함
  List<String> _recentSearches = [];
  List<String> _popularKeywords = []; // 인기 검색어

  bool _initialSearchDone = false;
  
  // 무한 스크롤용 ScrollController
  final ScrollController _scrollController = ScrollController();
  late final String _contextKey;

  @override
  void initState() {
    super.initState();
    _contextKey = 'search-${DateTime.now().microsecondsSinceEpoch}';
    _loadRecentSearches();
    _scrollController.addListener(_onScroll); // 스크롤 리스너 추가
  }
  
  /// 스크롤 위치 감지 (무한 스크롤)
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 200.0; // 끝에서 200px 전에 로드 시작
    
    if (maxScroll - currentScroll <= threshold) {
      final productService = context.read<ProductService>();
      if (productService.hasMoreProducts && !productService.isPaginationLoading) {
        productService.loadMoreProducts();
      }
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recentSearches') ?? [];
    });
  }

  /// 인기 검색어 로드 (ProductService 사용)
  Future<void> _loadPopularKeywords() async {
    // didChangeDependencies에서 호출되므로 context.read 사용
    if (!mounted) return;
    final productService = context.read<ProductService>();
    final keywords = await productService.getPopularKeywordsCached(limit: 10);
    if (mounted) {
      setState(() {
        _popularKeywords = keywords;
      });
    }
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final normalized = query.trim();
    final updated = List<String>.from(_recentSearches);
    
    // Remove if exists to move to top
    updated.remove(normalized);
    updated.insert(0, normalized);
    
    // Limit to 10
    if (updated.length > 10) {
      updated.removeLast();
    }
    
    await prefs.setStringList('recentSearches', updated);
    setState(() {
      _recentSearches = updated;
    });
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = List<String>.from(_recentSearches)..remove(query);
    await prefs.setStringList('recentSearches', updated);
    setState(() {
      _recentSearches = updated;
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentSearches');
    setState(() {
      _recentSearches = [];
    });
  }

  bool _hasActiveFilters() {
    return _filterSpecs.entries.any((entry) {
      final value = entry.value;
      if (value == null) return false;
      if (value is String && value.isEmpty) return false;
      if (value is List && value.isEmpty) return false;
      if (value is Map) {
        return (value['min'] as String?)?.isNotEmpty == true ||
            (value['max'] as String?)?.isNotEmpty == true;
      }
      return true;
    });
  }

  bool _hasSearchCriteria() {
    final hasCategoryFilter =
        _selectedCategory != '전체' || _selectedSubCategory != '전체';
    return _query.trim().isNotEmpty || _hasActiveFilters() || hasCategoryFilter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 진입 시 한 번만 초기 검색 수행 (전체 상품 로드)
    if (!_initialSearchDone) {
      _initialSearchDone = true;
      final productService = context.read<ProductService>();
      _performSearch(productService);
      _loadPopularKeywords(); // 인기 검색어 로드 (여기서 호출해야 Provider 접근 가능)
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value, ProductService productService) {
    // 입력 중에는 자동완성만 갱신
    _searchDebounceTimer?.cancel();
    productService.resetPagination();
    setState(() {
      _query = value;
      _isSubmitted = false;
      _isLoading = false;
      _suggestions = [];
    });
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _suggestions = productService.getSearchSuggestionsWithType(value); // 타입 정보 포함
      });
    });
  }

  void _submitQuery(String value, ProductService productService) {
    _searchDebounceTimer?.cancel();
    final trimmedQuery = value.trim();
    if (trimmedQuery.isNotEmpty) {
      _addRecentSearch(trimmedQuery);
      productService.recordSearchKeyword(trimmedQuery); // 인기 검색어 기록
    }
    setState(() {
      _query = trimmedQuery;
    });
    _performSearch(productService);
  }
  
  void _clearQuery(ProductService productService) {
    _searchDebounceTimer?.cancel();
    _controller.clear();
    productService.resetPagination();
    setState(() {
      _query = '';
      _suggestions = [];
    });
    _performSearch(productService);
  }

  void _selectSuggestion(SearchSuggestion suggestion, ProductService productService) {
    // 브랜드 선택 시 필터에 자동 적용
    if (suggestion.type == SuggestionType.brand) {
      _controller.clear();
      setState(() {
        _query = '';
        _suggestions = [];
        // 브랜드 필터 초기화 후 해당 카테고리에만 적용
        _filterSpecs.remove('brand_ski');
        _filterSpecs.remove('brand_board');
        _filterSpecs.remove('brand_apparel');
        _filterSpecs.remove('brand_gear');
        
        if (suggestion.brandKey != null) {
          // 특정 카테고리에만 필터 적용
          _filterSpecs[suggestion.brandKey!] = suggestion.value;
        } else {
          // brandKey 없으면 모든 카테고리에 적용
          _filterSpecs['brand_ski'] = suggestion.value;
          _filterSpecs['brand_board'] = suggestion.value;
          _filterSpecs['brand_apparel'] = suggestion.value;
          _filterSpecs['brand_gear'] = suggestion.value;
        }
      });
      _performSearch(productService);
      // 사용자에게 알림
      final categoryText = suggestion.categoryLabel != null 
          ? '${suggestion.categoryLabel} 카테고리의' 
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryText "${suggestion.value}" 브랜드 필터가 적용되었습니다'),
          duration: const Duration(seconds: 2),
          backgroundColor: primaryBlue,
        ),
      );
    } else {
      // 제목 선택 시 기존 동작
      _controller.text = suggestion.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: suggestion.value.length),
      );
      _submitQuery(suggestion.value, productService);
    }
  }

  Future<void> _performSearch(ProductService productService) async {
    if (!_hasSearchCriteria()) {
      productService.resetPagination();
      setState(() {
        _isSubmitted = false;
        _isLoading = false;
        _suggestions = [];
      });
      return;
    }
    
    setState(() {
      _isSubmitted = true;
      _isLoading = true;
      _suggestions = [];
    });

    try {
      await productService.fetchProductsPaginated(
        category: _selectedCategory == '전체' ? null : _selectedCategory,
        subCategory: _selectedSubCategory == '전체' ? null : _selectedSubCategory,
        query: _query,
        filterSpecs: _filterSpecs,
        contextKey: _contextKey,
      );
      await _loadMoreUntilResults(productService);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreUntilResults(ProductService productService) async {
    const maxAutoPages = 3;
    var loadedPages = 0;
    while (productService.hasMoreProducts &&
        productService.paginatedProducts.isEmpty &&
        loadedPages < maxAutoPages) {
      await productService.loadMoreProducts();
      loadedPages += 1;
    }
  }

  void _selectCategory(String category, ProductService productService) {
    setState(() {
      _selectedCategory = category;
      _selectedSubCategory = '전체'; // 대분류 변경 시 소분류 초기화
      _filterSpecs.clear(); // 필터도 초기화
    });
    _performSearch(productService);
  }
  
  void _selectSubCategory(String subCategory, ProductService productService) {
    setState(() {
      _selectedSubCategory = subCategory;
      _filterSpecs.clear(); // 소분류 변경 시 필터 초기화
    });
    _performSearch(productService);
  }

  String _formatPrice(int price) {
    final buffer = StringBuffer('₩ ');
    final priceString = price.toString();
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(priceString[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final normalizedQuery = _query.trim();
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrentRoute &&
        _hasSearchCriteria() &&
        productService.activeQueryKey != _contextKey &&
        !productService.isPaginationLoading &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _performSearch(context.read<ProductService>());
      });
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 (검색바)
            _buildHeader(productService),
            // 필터 & 카테고리 영역
            _buildFilterAndCategories(productService),
            // 소분류 탭 (대분류 선택 시에만 표시)
            if (_subCategories.isNotEmpty) _buildSubCategoryChips(productService),
            // 검색 결과 영역
            Expanded(
              child: _buildSearchBody(productService, normalizedQuery),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 - 뒤로가기 + 검색바 + 지우기 버튼
  Widget _buildHeader(ProductService productService) {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
      child: Row(
        children: [
          // 뒤로가기 버튼
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left, size: 28, color: textDark),
            splashRadius: 24,
          ),
          // 검색바
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, size: 20, color: textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => _handleQueryChanged(value, productService),
                      onSubmitted: (value) => _submitQuery(value, productService),
                      decoration: const InputDecoration(
                        hintText: '브랜드, 모델명, 사이즈 등 검색',
                        hintStyle: TextStyle(
                          color: textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // 지우기 버튼 (텍스트가 있을 때만 표시)
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      onPressed: () => _clearQuery(productService),
                      icon: const Icon(Icons.close, size: 20, color: textMuted),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 버튼 + 카테고리 칩
  Widget _buildFilterAndCategories(ProductService productService) {
    // 적용된 필터 개수 계산
    int filterCount = _filterSpecs.entries.where((e) {
      final val = e.value;
      if (val == null) return false;
      if (val is String && val.isEmpty) return false;
      if (val is List && val.isEmpty) return false;
      if (val is Map) {
        return (val['min'] as String?)?.isNotEmpty == true ||
               (val['max'] as String?)?.isNotEmpty == true;
      }
      return true;
    }).length;
    
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 필터 버튼
            GestureDetector(
              onTap: () => _showFilterBottomSheet(context, productService),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: filterCount > 0 
                      ? Border.all(color: primaryBlue, width: 1.5)
                      : null,
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.tune, size: 20, color: textDark),
                    ),
                    // 필터 개수 뱃지
                    if (filterCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$filterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 구분선
            Container(
              width: 1,
              height: 24,
              color: const Color(0xFFE0E0E0),
            ),
            const SizedBox(width: 12),
            // 카테고리 칩들
            ..._categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _selectCategory(category, productService),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : backgroundLight,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 소분류 칩 (대분류 선택 시에만 표시)
  Widget _buildSubCategoryChips(ProductService productService) {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _subCategories.map((subCategory) {
            final isSelected = _selectedSubCategory == subCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _selectSubCategory(subCategory, productService),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryBlue : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      subCategory,
                      style: TextStyle(
                        color: isSelected ? primaryBlue : textMuted,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 검색 결과 본문
  Widget _buildSearchBody(ProductService productService, String normalizedQuery) {
    final results = productService.paginatedProducts;
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
      );
    }

    // 자동완성 표시 (입력 중일 때)
    if (!_isSubmitted && normalizedQuery.isNotEmpty) {
      return Container(
        color: surfaceWhite,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            final isBrand = suggestion.type == SuggestionType.brand;
            return ListTile(
              leading: Icon(
                isBrand ? Icons.sell : Icons.search,
                color: isBrand ? primaryBlue : textMuted,
              ),
              title: Text(
                suggestion.displayText,
                style: TextStyle(
                  color: isBrand ? primaryBlue : textDark,
                  fontWeight: isBrand ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: Icon(
                isBrand ? Icons.filter_alt : Icons.north_west,
                size: 16,
                color: isBrand ? primaryBlue : textMuted,
              ),
              onTap: () => _selectSuggestion(suggestion, productService),
            );
          },
        ),
      );
    }

    // 최근 검색어 + 인기 검색어 표시 (검색어 없을 때)
    if (!_isSubmitted && normalizedQuery.isEmpty) {
      // 최근 검색어와 인기 검색어 모두 없으면 빈 화면
      if (_recentSearches.isEmpty && _popularKeywords.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text(
                '검색어를 입력해주세요',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 인기 검색어 섹션
            if (_popularKeywords.isNotEmpty) ...[  
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 20, color: Colors.orange[600]),
                    const SizedBox(width: 6),
                    const Text(
                      '인기 검색어',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _popularKeywords.asMap().entries.map((entry) {
                    final index = entry.key;
                    final keyword = entry.value;
                    return GestureDetector(
                      onTap: () {
                        _controller.text = keyword;
                        _submitQuery(keyword, productService);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: index < 3 ? primaryLight : surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: index < 3 ? primaryBlue : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: index < 3 ? primaryBlue : textMuted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              keyword,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: index < 3 ? primaryBlue : textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // 최근 검색어 섹션
            if (_recentSearches.isNotEmpty) ...[  
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '최근 검색어',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearRecentSearches,
                      style: TextButton.styleFrom(
                        foregroundColor: textMuted,
                        textStyle: const TextStyle(fontSize: 13),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('전체 삭제'),
                    ),
                  ],
                ),
              ),
              ..._recentSearches.map((recent) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _controller.text = recent;
                          _submitQuery(recent, productService);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.history,
                                  size: 18, color: textMuted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  recent,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeRecentSearch(recent),
                      icon:
                          const Icon(Icons.close, size: 18, color: textMuted),
                      splashRadius: 20,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      );
    }

    // 검색 결과 없음
    if (results.isEmpty) {
      final canLoadMore = productService.hasMoreProducts && !_isLoading;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              '검색 결과가 없어요',
              style: TextStyle(
                color: textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canLoadMore) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                  });
                  await productService.loadMoreProducts();
                  if (!mounted) return;
                  setState(() {
                    _isLoading = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: const BorderSide(color: primaryBlue),
                ),
                child: const Text('더 불러오기'),
              ),
            ],
          ],
        ),
      );
    }

    // 검색 결과 그리드
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 검색 결과 개수
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: textMuted, fontWeight: FontWeight.w500),
              children: [
                const TextSpan(text: '검색 결과 '),
                TextSpan(
                  text: '${results.length}',
                  style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '개'),
              ],
            ),
          ),
        ),
        // 상품 그리드 (무한 스크롤 적용)
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              childAspectRatio: 0.52, // 4:5 비율 이미지 + 텍스트 영역
            ),
            itemCount: results.length +
                (productService.hasMoreProducts && results.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              // 마지막 아이템: 로딩 인디케이터
              if (index >= results.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                  ),
                );
              }
              return _buildProductGridCard(context, results[index], productService);
            },
          ),
        ),
      ],
    );
  }

  /// 상품 카드 (Stitch 그리드 스타일)
  Widget _buildProductGridCard(
    BuildContext context,
    Product product,
    ProductService productService,
  ) {
    final isLiked = productService.isLiked(product.id);
    final isSoldOut = product.status == ProductStatus.soldOut ||
        product.status == ProductStatus.hidden;
    final isReserved = product.status == ProductStatus.reserved;

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
            // 이미지 영역 (4:5 비율)
            Expanded(
              child: Stack(
                children: [
                  // 상품 이미지
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
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
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        final currentUser = context.read<UserService>().currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그인이 필요합니다.')),
                          );
                          return;
                        }
                        productService.toggleLike(product.id, currentUser.uid);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isLiked ? Colors.redAccent : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  // 예약중 오버레이
                  if (isReserved)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
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
                                  border: Border.all(color: Colors.white, width: 2),
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
            const SizedBox(height: 12),
            // 상품 정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상품명 (검색어 하이라이트)
                  _buildHighlightedTitle(product.title),
                  const SizedBox(height: 4),
                  // 가격
                  Text(
                    _formatPrice(product.price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 검색어 하이라이트가 적용된 상품명
  Widget _buildHighlightedTitle(String title) {
    final query = _query.trim().toLowerCase();
    
    if (query.isEmpty) {
      return Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textDark,
          height: 1.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerTitle = title.toLowerCase();
    final matchIndex = lowerTitle.indexOf(query);
    
    if (matchIndex == -1) {
      return Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textDark,
          height: 1.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final before = title.substring(0, matchIndex);
    final match = title.substring(matchIndex, matchIndex + query.length);
    final after = title.substring(matchIndex + query.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textDark,
          height: 1.3,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  /// 필터 바텀시트 표시
  void _showFilterBottomSheet(BuildContext context, ProductService productService) async {
    // 대분류가 '전체'면 필터 사용 불가
    if (_selectedCategory == '전체') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택하면 필터를 사용할 수 있습니다.')),
      );
      return;
    }
    
    // 소분류가 '전체'면 필터 사용 불가
    if (_selectedSubCategory == '전체' && _subCategories.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 분류를 선택하면 필터를 사용할 수 있습니다.')),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        initialSpecs: _filterSpecs,
      ),
    );

    if (result != null) {
      setState(() {
        _filterSpecs = result;
      });
      _performSearch(productService);
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
  static const Color textMuted = Color(0xFF637688);

  late final Map<String, dynamic> _selectedSpecs;
  
  // 가격 필터 컨트롤러
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSpecs = Map.from(widget.initialSpecs);
    
    // 기존 가격 필터값 로드
    final priceFilter = widget.initialSpecs['price'] as Map<String, dynamic>?;
    if (priceFilter != null) {
      _minPriceController.text = priceFilter['min'] ?? '';
      _maxPriceController.text = priceFilter['max'] ?? '';
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
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
                      color: primaryBlue,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 가격 필터 (최상단 배치)
                  _buildPriceFilter(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildTradeLocationFilter(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  // 동적 속성 필터
                  DynamicAttributeForm(
                    category: widget.category,
                    subCategory: widget.subCategory,
                    selectedSpecs: _selectedSpecs,
                    isFilterMode: true,
                    onSpecChanged: (key, value) {
                      setState(() {
                        _selectedSpecs[key] = value;
                      });
                    },
                  ),
                ],
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
                onPressed: () {
                  // 범위 필터 검증 (min > max 체크)
                  final validationError = _validateRangeFilters();
                  if (validationError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(validationError),
                        backgroundColor: Colors.red[600],
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, _selectedSpecs);
                },
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

  void _resetFilters() {
    setState(() {
      _selectedSpecs.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  /// 범위 필터 검증 (min > max 체크)
  /// 오류가 있으면 오류 메시지 반환, 없으면 null
  String? _validateRangeFilters() {
    // 가격 필터 검증
    final priceFilter = _selectedSpecs['price'] as Map<String, dynamic>?;
    if (priceFilter != null) {
      final minStr = priceFilter['min'] as String?;
      final maxStr = priceFilter['max'] as String?;
      
      if (minStr != null && minStr.isNotEmpty && maxStr != null && maxStr.isNotEmpty) {
        final minPrice = int.tryParse(minStr) ?? 0;
        final maxPrice = int.tryParse(maxStr) ?? 0;
        if (minPrice > maxPrice) {
          return '가격의 최소값이 최대값보다 큽니다';
        }
      }
    }
    
    // 길이/기타 범위 필터 검증
    for (final entry in _selectedSpecs.entries) {
      if (entry.key == 'price' || entry.key == 'tradeLocationKeys') {
        continue; // 가격/직거래 장소는 위에서 처리
      }
      
      final value = entry.value;
      if (value is Map) {
        final minStr = value['min'] as String?;
        final maxStr = value['max'] as String?;
        
        if (minStr != null && minStr.isNotEmpty && maxStr != null && maxStr.isNotEmpty) {
          final minNum = double.tryParse(minStr.replaceAll(RegExp(r'[^0-9.]'), ''));
          final maxNum = double.tryParse(maxStr.replaceAll(RegExp(r'[^0-9.]'), ''));
          
          if (minNum != null && maxNum != null && minNum > maxNum) {
            // 필터 이름 추출 시도 (예: length_ski -> 길이)
            return '범위 필터의 최소값이 최대값보다 큽니다';
          }
        }
      }
    }
    
    return null;
  }

  Widget _buildTradeLocationFilter() {
    final selected = List<String>.from(
      (_selectedSpecs['tradeLocationKeys'] as List?) ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              '직거래 장소',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '리조트는 최대 2개까지 선택할 수 있습니다.',
          style: TextStyle(
            fontSize: 12,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '리조트',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 10),
        _buildLocationChips(
          options: TradeLocationConstants.resorts,
          prefix: 'resort',
          selectedKeys: selected,
        ),
      ],
    );
  }

  Widget _buildLocationChips({
    required List<String> options,
    required String prefix,
    required List<String> selectedKeys,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final key = '$prefix:${option.trim()}';
        final isSelected = selectedKeys.contains(key);
        return GestureDetector(
          onTap: () {
            final updated = List<String>.from(selectedKeys);
            if (isSelected) {
              updated.remove(key);
            } else {
              if (updated.length >= 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('직거래 장소는 최대 2개까지 선택할 수 있어요.')),
                );
                return;
              }
              updated.add(key);
            }
            setState(() {
              if (updated.isEmpty) {
                _selectedSpecs.remove('tradeLocationKeys');
              } else {
                _selectedSpecs['tradeLocationKeys'] = updated;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryBlue : Colors.grey[300]!,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: isSelected ? Colors.white : textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 가격 필터 위젯
  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_money, size: 20, color: primaryBlue),
            const SizedBox(width: 8),
            const Text(
              '가격 범위',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // 최소 가격
            Expanded(
              child: TextField(
                controller: _minPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '최소',
                  prefixText: '₩ ',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandSeparatorFormatter(),
                ],   
                onChanged: (value) {
                  final priceMap = Map<String, String>.from(
                    (_selectedSpecs['price'] as Map<String, dynamic>?) ?? {},
                  );
                  // 쉼표 제거 후 저장
                  priceMap['min'] = value.replaceAll(',', '');
                  setState(() {
                    _selectedSpecs['price'] = priceMap;
                  });
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('~', style: TextStyle(fontSize: 18, color: textMuted)),
            ),
            // 최대 가격
            Expanded(
              child: TextField(
                controller: _maxPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '최대',
                  prefixText: '₩ ',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandSeparatorFormatter(),
                ],
                onChanged: (value) {
                  final priceMap = Map<String, String>.from(
                    (_selectedSpecs['price'] as Map<String, dynamic>?) ?? {},
                  );
                  // 쉼표 제거 후 저장
                  priceMap['max'] = value.replaceAll(',', '');
                  setState(() {
                    _selectedSpecs['price'] = priceMap;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 천 단위 쉼표 포맷터
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 숫자만 추출
    final numericString = newValue.text.replaceAll(',', '');
    if (numericString.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // 천 단위 콤마 추가
    final number = int.tryParse(numericString);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatWithComma(number);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithComma(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
