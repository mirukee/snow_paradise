import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../widgets/product_card.dart';
import 'detail_screen.dart';
import 'search_screen.dart';

const _secondaryColor = Color(0xFF101922);

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _formatPrice(int price) {
    final priceString = price.toString();
    final buffer = StringBuffer('');
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(priceString[i]);
    }
    buffer.write('원');
    return buffer.toString();
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '방금 전';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}.$month.$day';
  }

  String _buildSubtitle(Product product) {
    final category = product.category.trim();
    final timeAgo = _formatTimeAgo(product.createdAt);
    if (category.isEmpty) {
      return timeAgo;
    }
    return '$category • $timeAgo';
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final products = productService.productList;
    final currentUser = context.watch<UserService>().currentUser;
    final topPadding = MediaQuery.of(context).padding.top;
    const headerContentHeight = 124.0;
    final headerHeight = topPadding + headerContentHeight;
    final screenWidth = MediaQuery.of(context).size.width;
    final categoryCardWidth = (screenWidth - 32 - 12) / 2;
    const categoryCardHeight = 140.0;

    final categories = [
      const _CategoryItem(
        title: '스키',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDGXCBIT71l6t3sL4c2gn6uXyzELL1nGh38plSoolG4CtCw7932mRj10nYBCJdlmiL5SU9xYYXjEtqU5EcVceCUH_KpyYfJIvC1Jw5awFwiNNeckN_qTb1EojGV_udjPsi5cGQKJ4lJNMSmiX1JNsFFfbO-32-RnI4yTSqXp_7Qw9xPu7_r9vlyGc5LhIa6khZJyrHDP8yy4gVAUade_vZyhnliLHQkOnSnNJTnHX2GbTFHySS75mCu-B5i2DbYqez0rpxM7t96DS3m',
      ),
      const _CategoryItem(
        title: '스노우보드',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBjrqa2RXzuWYtD-qjEijlOUeOYQG3kYLNohPRKrv0injxhJ1D6XSmE8GkvYDeAgWIMoJ-qVEJpIHoeqrvxyazId-Jke-8W6K3kGXc0MDsLZaO6WjRiL9N8h1v5rFVipKlazlQnhgjy1OivFfjJKZ3CGN5HgkaIv3idUZiQmYc-CrVqMzNqiTp3Q748nprAsK9XqnOyZa_R1tZYMsbReDRxgB1X3mo1nac6zGeLynVS1eQ2srEL8CsHJ4N2H3kZcU9uzlEtY75rlz8a',
      ),
      const _CategoryItem(
        title: '의류',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCbgANMCfc7wR_NYEa9w6tZt_Z-avm23VyGZXe1h5upJ-94DiBbc8e_hVAYkMTDvZycda8wJtLGRpk9TaBrQEi3ZvYtqf15izgBmIKcvBg9rqNC2arzKi0IFX50sq-szHK6RQBNVlkfgElsrKKD6eAqjxt0RtfBXfTN5W0VZYxR5JoiEdVnJJD0r4MRA642s3pzsO35odWiak0FEZlwrWv_GL8MJhOdU9F4Mc_o0RcDvFkDoB171FYJ4BZD5dCOtqSYzB4ehvDZJrWC',
      ),
      const _CategoryItem(
        title: '장비/기타',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCbggLa1k9qusrt2hjLyyvTyGH6eA3ZawF7HVXPlssp-3w8yS4H1RCKKDypAUdwErDYliYPmyYSpZM3hj7Oonaipq3okW4HENocEm5drbw2_WlkFTFh_kEMJEV2dKOZqlwr5e1dqFBBQiZ_0Zs_DJTvWMtG9Sp79iUq3T5yfZpeweOuS-1WdjXdCwti1KpuMvOIwIuZDiM4LB1zB96TvjfKM5ButAjpFcWI9HLhpPZw33tPJvKTWXVlb2bQK146FDlJZg_KZJ_MEdIn',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomeHeaderDelegate(
              height: headerHeight,
              topPadding: topPadding,
              onSearchTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              },
              onNotificationTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('알림 기능은 준비 중입니다.')),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '카테고리',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _secondaryColor,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: categoryCardHeight,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  return SizedBox(
                    width: categoryCardWidth,
                    height: categoryCardHeight,
                    child: _CategoryCard(
                      item: item,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.title} 카테고리 (준비 중)'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    '방금 올라온 상품',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('더보기는 준비 중입니다.')),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[500],
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '더보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (products.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: Text(
                    '상품이 없습니다',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    final isLiked = productService.isLiked(product.id);
                    return ProductCard(
                      product: product,
                      priceText: _formatPrice(product.price),
                      subtitle: _buildSubtitle(product),
                      isLiked: isLiked,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetailScreen(product: product),
                          ),
                        );
                      },
                      onLikeTap: () {
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('로그인이 필요합니다.')),
                          );
                          return;
                        }
                        productService.toggleLike(product.id, currentUser.uid);
                      },
                    );
                  },
                  childCount: products.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeHeaderDelegate({
    required this.height,
    required this.topPadding,
    required this.onSearchTap,
    required this.onNotificationTap,
  });

  final double height;
  final double topPadding;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          if (overlapsContent)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, topPadding + 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: (MediaQuery.of(context).size.width - 24) * 0.42,
                      height: 36,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              '스노우 파라다이스',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _secondaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onNotificationTap,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.notifications,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onSearchTap,
                child: Ink(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search, color: Colors.grey[500], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '브랜드, 장비, 매물 검색...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.topPadding != topPadding;
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.title,
    required this.imageUrl,
  });

  final String title;
  final String imageUrl;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.item,
    required this.onTap,
  });

  final _CategoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            image: DecorationImage(
              image: NetworkImage(item.imageUrl),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
