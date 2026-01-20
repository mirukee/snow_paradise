import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../widgets/product_card.dart';
import 'category_product_screen.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import 'notification_screen.dart';
import '../providers/main_tab_provider.dart';

const _secondaryColor = Color(0xFF101922);
const _iceBlue = Color(0xFF00AEEF);
const _iceBlueSoft = Color(0xFFE2F0FD);
const _mutedText = Color(0xFF8A94A6);

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const _homeQueryKey = 'home';
  final ScrollController _scrollController = ScrollController();
  bool _isAutoFetching = false;

  @override
  void initState() {
    super.initState();
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
    final currentIndex = context.watch<MainTabProvider>().currentIndex;
    final isActiveTab = currentIndex == 0;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (isActiveTab &&
        isCurrentRoute &&
        productService.activeQueryKey != _homeQueryKey &&
        !productService.isPaginationLoading &&
        !_isAutoFetching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureHomeProducts(context.read<ProductService>());
      });
    }
    final products = productService.paginatedProducts;
    final currentUser = context.watch<UserService>().currentUser;
    final topPadding = MediaQuery.of(context).padding.top;
    const headerContentHeight = 140.0;
    final headerHeight = topPadding + headerContentHeight;
    final screenWidth = MediaQuery.of(context).size.width;
    final categoryChipWidth = (screenWidth - 32 - 12) / 2;

    final categories = [
      const _CategoryItem(
        title: '스키',
        icon: Icons.downhill_skiing,
        isActive: true,
      ),
      const _CategoryItem(
        title: '스노우보드',
        icon: Icons.snowboarding,
      ),
      const _CategoryItem(
        title: '의류',
        icon: Icons.checkroom,
      ),
      const _CategoryItem(
        title: '장비/보호대',
        icon: Icons.health_and_safety,
      ),
      const _CategoryItem(
        title: '시즌권',
        icon: Icons.card_membership,
      ),
      const _CategoryItem(
        title: '시즌방',
        icon: Icons.home,
      ),
      const _CategoryItem(
        title: '강습',
        icon: Icons.school,
      ),
      const _CategoryItem(
        title: '기타',
        icon: Icons.more_horiz,
      ),
    ];

    final banners = [
      const _HeroBanner(
        label: '커뮤니티 마켓',
        title: '중고 장비 판매하기',
        subtitle: '동네 스노우보더와 빠른 거래',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBjrqa2RXzuWYtD-qjEijlOUeOYQG3kYLNohPRKrv0injxhJ1D6XSmE8GkvYDeAgWIMoJ-qVEJpIHoeqrvxyazId-Jke-8W6K3kGXc0MDsLZaO6WjRiL9N8h1v5rFVipKlazlQnhgjy1OivFfjJKZ3CGN5HgkaIv3idUZiQmYc-CrVqMzNqiTp3Q748nprAsK9XqnOyZa_R1tZYMsbReDRxgB1X3mo1nac6zGeLynVS1eQ2srEL8CsHJ4N2H3kZcU9uzlEtY75rlz8a',
      ),
      const _HeroBanner(
        label: '트렌딩',
        title: '빈티지 레어템',
        subtitle: '컬렉터의 유니크한 스타일',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDGXCBIT71l6t3sL4c2gn6uXyzELL1nGh38plSoolG4CtCw7932mRj10nYBCJdlmiL5SU9xYYXjEtqU5EcVceCUH_KpyYfJIvC1Jw5awFwiNNeckN_qTb1EojGV_udjPsi5cGQKJ4lJNMSmiX1JNsFFfbO-32-RnI4yTSqXp_7Qw9xPu7_r9vlyGc5LhIa6khZJyrHDP8yy4gVAUade_vZyhnliLHQkOnSnNJTnHX2GbTFHySS75mCu-B5i2DbYqez0rpxM7t96DS3m',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScreen(),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: banners.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: screenWidth * 0.85,
                    child: _HeroBannerCard(banner: banners[index]),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    '카테고리 둘러보기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      context.read<MainTabProvider>().setIndex(1); // 쇼핑 탭으로 이동
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: _iceBlue,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '전체보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  return SizedBox(
                    width: categoryChipWidth,
                    child: _CategoryChip(
                      item: item,
                      onTap: () {
                        // 카테고리 상품 목록 화면으로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryProductScreen(
                              category: item.title,
                            ),
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
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '신규 매물',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (products.isEmpty && productService.isPaginationLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (products.isEmpty)
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
                    if (index >= products.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
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
                  childCount: products.length +
                      (productService.hasMoreProducts ? 1 : 0),
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _ensureHomeProducts(ProductService productService) {
    if (_isAutoFetching) return;
    _isAutoFetching = true;
    productService
        .fetchProductsPaginated(contextKey: _homeQueryKey)
        .whenComplete(() {
      _isAutoFetching = false;
    });
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
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
            padding: EdgeInsets.fromLTRB(12, topPadding + 10, 12, 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 로고 - 중앙 정렬
                      Image.asset(
                        'assets/images/logo.png',
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                      // 알림 버튼 - 오른쪽 끝
                      Positioned(
                        right: 0,
                        child: _HeaderIconButton(
                          icon: Icons.notifications,
                          onTap: onNotificationTap,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onSearchTap,
                    child: Ink(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _iceBlueSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD7E6F5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 14),
                          Icon(Icons.search, color: _mutedText, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '브랜드, 장비, 매물 검색...',
                              style: TextStyle(
                                fontSize: 15,
                                color: _mutedText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    required this.icon,
    this.isActive = false,
  });

  final String title;
  final IconData icon;
  final bool isActive;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.item,
    required this.onTap,
  });

  final _CategoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = item.isActive;
    final backgroundColor = isActive ? _iceBlueSoft : Colors.white;
    final borderColor = isActive ? const Color(0xFFD7E6F5) : const Color(0xFFE5E7EB);
    final textColor = isActive ? _secondaryColor : const Color(0xFF3B4657);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 18, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner {
  const _HeroBanner({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String label;
  final String title;
  final String subtitle;
  final String imageUrl;
}

class _HeroBannerCard extends StatelessWidget {
  const _HeroBannerCard({required this.banner});

  final _HeroBanner banner;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _iceBlueSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    banner.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _secondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  banner.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  banner.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(icon, size: 20, color: _secondaryColor),
          ),
        ),
      ),
    );
  }
}
