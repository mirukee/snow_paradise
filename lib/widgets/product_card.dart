import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.priceText,
    required this.subtitle,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
  });

  final Product product;
  final String priceText;
  final String subtitle;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  @override
  Widget build(BuildContext context) {
    const secondaryColor = Color(0xFF101922);
    const mutedText = Color(0xFF8A94A6);
    final isSoldOut = product.status == ProductStatus.soldOut;
    final hasStatus = product.status != ProductStatus.forSale;

    return Opacity(
      opacity: isSoldOut ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Container(
                          color: Colors.grey.shade100,
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
                    if (hasStatus)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _StatusBadge(label: product.status.label),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white.withOpacity(0.85),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onLikeTap,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color:
                                  isLiked ? Colors.redAccent : Colors.grey[500],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: secondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101922).withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
