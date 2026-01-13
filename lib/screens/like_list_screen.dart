import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import 'detail_screen.dart';
import '../widgets/product_image.dart';

class LikeListScreen extends StatelessWidget {
  const LikeListScreen({super.key});

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
    final likedProducts = productService.likedProducts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('관심목록'),
        elevation: 0,
      ),
      body: likedProducts.isEmpty
          ? _EmptyState(primaryColor: Theme.of(context).colorScheme.primary)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: likedProducts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = likedProducts[index];
                return _LikeListItem(
                  product: product,
                  priceText: _formatPrice(product.price),
                );
              },
            ),
    );
  }
}

class _LikeListItem extends StatelessWidget {
  final Product product;
  final String priceText;

  const _LikeListItem({
    required this.product,
    required this.priceText,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 76,
                  height: 76,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.brand,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _ConditionBadge(condition: product.condition),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                      priceText,
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
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  context.read<ProductService>().toggleLike(product.id);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('관심 목록에서 제거했어요.'),
                      duration: Duration(milliseconds: 900),
                    ),
                  );
                },
                icon: const Icon(Icons.favorite, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  final String condition;

  const _ConditionBadge({required this.condition});

  @override
  Widget build(BuildContext context) {
    final badgeColor = condition == '거의 새것' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        condition,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color primaryColor;

  const _EmptyState({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              '아직 관심 상품이 없어요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '마음에 드는 상품을 찜해보세요.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
