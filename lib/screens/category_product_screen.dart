import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import 'detail_screen.dart';
import '../widgets/product_image.dart';

class CategoryProductScreen extends StatelessWidget {
  final String category;

  const CategoryProductScreen({super.key, required this.category});

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
    final products = productService.getByCategory(category);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          category,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: products.isEmpty
          ? const Center(
              child: Text(
                '등록된 상품이 없어요',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(context, product, productService);
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
    final isSoldOut = product.status == ProductStatus.soldOut ||
        product.status == ProductStatus.hidden;
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
