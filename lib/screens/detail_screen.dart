import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [추가] Provider 패키지
import '../models/product.dart';
import '../providers/product_service.dart'; // [추가] ProductService
import '../providers/user_service.dart';
import 'edit_product_screen.dart';
import '../widgets/product_image.dart';

class DetailScreen extends StatelessWidget {
  final Product product;

  const DetailScreen({
    super.key,
    required this.product,
  });

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
    // [추가] Provider를 통해 찜 상태 실시간 감지
    final productService = context.watch<ProductService>();
    final currentUser = context.watch<UserService>().currentUser;
    final currentProduct = productService.getProductById(product.id) ?? product;
    final isLiked = productService.isLiked(currentProduct.id);
    final currentUserId = currentUser?.uid;
    final currentUserName = currentUser?.displayName ?? currentUser?.email ?? '';
    final currentUserPhoto = currentUser?.photoURL ?? '';
    final isOwner = currentUser != null &&
        (currentProduct.sellerId.isNotEmpty
            ? currentProduct.sellerId == currentUserId
            : currentProduct.sellerName == currentUserName &&
                currentProduct.sellerProfile == currentUserPhoto);

    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 상세'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지 (크게)
            Container(
              width: double.infinity,
              height: 400,
              color: Colors.grey.shade200,
              child: buildProductImage(
                currentProduct,
                fit: BoxFit.cover,
                errorIconSize: 80,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            // 상품 정보 섹션
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 판매자 프로필
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: currentProduct.sellerProfile.isNotEmpty
                            ? NetworkImage(currentProduct.sellerProfile)
                            : null,
                        child: currentProduct.sellerProfile.isEmpty
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProduct.sellerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '판매자',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 제목과 가격
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProduct.brand,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentProduct.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 가격
                  Text(
                    _formatPrice(currentProduct.price),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 구분선
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 24),
                  // 스펙 정보
                  const Text(
                    '상품 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 상태
                  _buildInfoRow(
                    context,
                    '상태',
                    currentProduct.condition,
                    currentProduct.condition == '거의 새것' ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  // 사이즈
                  _buildInfoRow(context, '사이즈', currentProduct.size, null),
                  const SizedBox(height: 12),
                  // 연식
                  _buildInfoRow(context, '연식', currentProduct.year, null),
                  const SizedBox(height: 12),
                  // 브랜드
                  _buildInfoRow(context, '브랜드', currentProduct.brand, null),
                  const SizedBox(height: 24),
                  // 구분선
                  Divider(color: Colors.grey.shade300, thickness: 1),
                  const SizedBox(height: 24),
                  // 상세 설명
                  const Text(
                    '상세 설명',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentProduct.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 100), // 하단 버튼 공간
                ],
              ),
            ),
          ],
        ),
      ),
      // 하단 고정 버튼
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isOwner
              ? _buildOwnerActions(context, currentProduct)
              : _buildBuyerActions(
                  context,
                  currentProduct,
                  productService,
                  isLiked,
                ),
        ),
      ),
    );
  }

  Widget _buildOwnerActions(BuildContext context, Product product) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProductScreen(product: product),
                ),
              );
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('수정 완료!')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '수정하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('상품 삭제'),
                  content: const Text('정말 삭제하시겠어요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        '삭제',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<ProductService>().removeProduct(product.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('삭제 완료!')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('삭제에 실패했습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              '삭제하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerActions(
    BuildContext context,
    Product product,
    ProductService productService,
    bool isLiked,
  ) {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: () {
              productService.toggleLike(product.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isLiked ? '관심 목록에서 제거했어요.' : '관심 목록에 추가했어요!'),
                  duration: const Duration(milliseconds: 1000),
                ),
              );
            },
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('채팅하기 기능은 준비 중입니다.')),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '채팅하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('구매하기 기능은 준비 중입니다.')),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              '구매하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    Color? valueColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
