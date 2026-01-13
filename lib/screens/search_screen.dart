import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
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
      _suggestions = productService.getSearchSuggestions(value);
      _results = [];
    });
  }

  void _submitQuery(String value, ProductService productService) {
    final trimmedQuery = value.trim();
    // 검색 버튼/엔터 입력 시 결과 리스트 갱신
    setState(() {
      _query = trimmedQuery;
      _isSubmitted = true;
      _suggestions = [];
      _results = productService.searchProducts(trimmedQuery);
    });
  }

  void _selectSuggestion(String suggestion, ProductService productService) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _submitQuery(suggestion, productService);
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
      body: normalizedQuery.isEmpty
          ? const Center(
              child: Text(
                '스키, 보드, 의류 등 검색어를 입력해보세요',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : !_isSubmitted
              ? ListView.separated(
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
                )
              : _results.isEmpty
                  ? const Center(
                      child: Text(
                        '검색 결과가 없어요',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
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
                    ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    ProductService productService,
  ) {
    final isLiked = productService.isLiked(product.id);

    return Material(
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
                  child: buildProductImage(
                    product,
                    fit: BoxFit.cover,
                    errorIconSize: 28,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
              IconButton(
                onPressed: () => productService.toggleLike(product.id),
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
