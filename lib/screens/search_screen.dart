import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import 'detail_screen.dart';
import '../widgets/product_image.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  bool _isSubmitted = false;
  bool _isLoading = false;
  String _selectedCategory = '전체';
  final List<String> _categories = [
    '전체',
    '스노우보드',
    '스키',
    '의류',
    '보호구',
    '기타',
  ];
  List<String> _suggestions = [];
  List<Product> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value, ProductService productService) {
    // 입력 중에는 자동완성만 갱신
    setState(() {
      _query = value;
      _isSubmitted = false;
      _isLoading = false;
      _suggestions = productService.getSearchSuggestions(value);
      _results = [];
    });
  }

  void _submitQuery(String value, ProductService productService) {
    final trimmedQuery = value.trim();
    setState(() {
      _query = trimmedQuery;
    });
    if (trimmedQuery.isEmpty && _selectedCategory == '전체') {
      setState(() {
        _isSubmitted = false;
        _suggestions = [];
        _results = [];
      });
      return;
    }
    _performSearch(productService);
  }

  void _selectSuggestion(String suggestion, ProductService productService) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _submitQuery(suggestion, productService);
  }

  Future<void> _performSearch(ProductService productService) async {
    setState(() {
      _isSubmitted = true;
      _isLoading = true;
      _suggestions = [];
    });

    try {
      final results = await productService.searchProducts(
        _query,
        _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색에 실패했습니다.')),
      );
      setState(() {
        _results = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectCategory(String category, ProductService productService) {
    setState(() {
      _selectedCategory = category;
    });

    final trimmedQuery = _query.trim();
    if (trimmedQuery.isEmpty && _selectedCategory == '전체') {
      setState(() {
        _isSubmitted = false;
        _isLoading = false;
        _results = [];
      });
      return;
    }
    _performSearch(productService);
  }

  String _formatPrice(int price) {
    final priceString = price.toString();
    final buffer = StringBuffer('₩ ');
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(priceString[i]);
    }
    buffer.write('원');
    return buffer.toString();
  }

  Widget _buildStatusBadge(ProductStatus status) {
    if (status == ProductStatus.forSale) {
      return const SizedBox.shrink();
    }
    final color = status == ProductStatus.reserved ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEngagementRow(BuildContext context, Product product) {
    final items = <Widget>[];
    final chatColor = Theme.of(context).colorScheme.primary;

    if (product.likeCount > 0) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(
              '${product.likeCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    if (product.chatCount > 0) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(width: 8));
      }
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 14, color: chatColor),
            const SizedBox(width: 4),
            Text(
              '${product.chatCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final normalizedQuery = _query.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (value) => _handleQueryChanged(value, productService),
          onSubmitted: (value) => _submitQuery(value, productService),
          decoration: const InputDecoration(
            hintText: '브랜드, 모델명, 사이즈 등 검색',
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(productService),
          const Divider(height: 1),
          Expanded(
            child: _buildSearchBody(
              productService,
              normalizedQuery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(ProductService productService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (_) => _selectCategory(category, productService),
                selectedColor: Colors.black,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? Colors.black : Colors.grey[300]!,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBody(
    ProductService productService,
    String normalizedQuery,
  ) {
    if (!_isSubmitted &&
        normalizedQuery.isEmpty &&
        _selectedCategory == '전체') {
      return const Center(
        child: Text(
          '스키, 보드, 의류 등 검색어를 입력해보세요',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (!_isSubmitted && normalizedQuery.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            leading: const Icon(Icons.search, color: Colors.grey),
            title: Text(suggestion),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () => _selectSuggestion(
              suggestion,
              productService,
            ),
          );
        },
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없어요',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _results[index];
        return _buildProductCard(
          context,
          product,
          productService,
        );
      },
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    ProductService productService,
  ) {
    final isLiked = productService.isLiked(product.id);
    final isSoldOut = product.status == ProductStatus.soldOut;
    final hasEngagement = product.likeCount > 0 || product.chatCount > 0;

    return Opacity(
      opacity: isSoldOut ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(product: product),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 86,
                    height: 86,
                    color: Colors.grey.shade200,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: buildProductImage(
                            product,
                            fit: BoxFit.cover,
                            errorIconSize: 28,
                            loadingWidget: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        if (product.status != ProductStatus.forSale)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: _buildStatusBadge(product.status),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              final currentUser =
                                  context.read<UserService>().currentUser;
                              if (currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('로그인이 필요합니다.'),
                                  ),
                                );
                                return;
                              }
                              productService.toggleLike(
                                product.id,
                                currentUser.uid,
                              );
                            },
                            icon: Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatPrice(product.price),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (hasEngagement) const SizedBox(height: 6),
                      if (hasEngagement)
                        _buildEngagementRow(context, product),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
