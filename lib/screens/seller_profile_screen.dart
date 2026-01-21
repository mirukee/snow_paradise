import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/public_profile.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../widgets/product_image.dart';
import '../widgets/report_dialog.dart';
import 'detail_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.sellerProfileImage,
  });

  final String sellerId;
  final String sellerName;
  final String sellerProfileImage;

  static const _iceBlue = Color(0xFF00AEEF);
  static const _deepNavy = Color(0xFF101922);
  static const _background = Color(0xFFF6F8FA);

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  static const _iceBlue = SellerProfileScreen._iceBlue;
  static const _deepNavy = SellerProfileScreen._deepNavy;
  static const _background = SellerProfileScreen._background;

  late final String _contextKey;
  bool _isAutoFetching = false;

  @override
  void initState() {
    super.initState();
    final sellerId = widget.sellerId.trim();
    final resolvedId = sellerId.isEmpty ? 'unknown' : sellerId;
    _contextKey =
        'seller-$resolvedId-${DateTime.now().microsecondsSinceEpoch}';
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

  List<Product> _sellerProducts(List<Product> products) {
    final trimmedSellerId = widget.sellerId.trim();
    if (trimmedSellerId.isNotEmpty) {
      return products
          .where(
            (product) =>
                product.sellerId == trimmedSellerId &&
                product.status != ProductStatus.hidden,
          )
          .toList();
    }
    final trimmedName = widget.sellerName.trim();
    final trimmedProfile = widget.sellerProfileImage.trim();
    return products
        .where(
          (product) =>
              product.sellerName == trimmedName &&
              product.sellerProfile == trimmedProfile &&
              product.status != ProductStatus.hidden,
        )
        .toList();
  }

  List<String> _buildTags(List<Product> products) {
    final tags = <String>{};
    for (final product in products) {
      final category = product.category.trim();
      if (category.isNotEmpty) {
        tags.add(category);
      }
      final brand = product.brand.trim();
      if (brand.isNotEmpty) {
        tags.add(brand);
      }
    }
    if (tags.isEmpty) {
      return ['판매 물품 ${products.length}개'];
    }
    return tags.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final currentUser = context.watch<UserService>().currentUser;
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
    final products = _sellerProducts(productService.paginatedProducts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tags = _buildTags(products);
    const temperature = 37.5;
    final trimmedSellerId = widget.sellerId.trim();

    Widget buildProfile({
      required String displayName,
      required String profileImageUrl,
    }) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            surfaceTintColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: _deepNavy),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              '판매자 프로필',
              style: TextStyle(
                color: _deepNavy,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.share, color: _deepNavy),
              ),
              IconButton(
                onPressed: () async {
                  if (trimmedSellerId.isEmpty) return;
                  if (currentUser != null &&
                      currentUser.uid == trimmedSellerId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('본인 프로필입니다.')),
                    );
                    return;
                  }
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그인이 필요합니다.')),
                    );
                    return;
                  }

                  // 차단 여부 확인
                  final blockedIds = await context
                      .read<UserService>()
                      .getBlockedUserIds(currentUser.uid);
                  final isBlocked = blockedIds.contains(trimmedSellerId);

                  if (!context.mounted) return;

                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.report_problem_rounded,
                                color: Colors.redAccent),
                            title: const Text('신고하기'),
                            onTap: () {
                              Navigator.pop(context); // Close bottom sheet
                              showDialog(
                                context: context,
                                builder: (context) => ReportDialog(
                                  targetUid: trimmedSellerId,
                                  targetContentId: trimmedSellerId,
                                  reportType: 'user',
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.block_rounded,
                                color: Colors.grey),
                            title: Text(isBlocked ? '차단 해제' : '차단하기'),
                            onTap: () async {
                              Navigator.pop(context); // Close bottom sheet
                              try {
                                if (isBlocked) {
                                  await context
                                      .read<UserService>()
                                      .unblockUser(
                                        currentUid: currentUser.uid,
                                        targetUid: trimmedSellerId,
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text('차단이 해제되었습니다.')),
                                    );
                                  }
                                } else {
                                  await context
                                      .read<UserService>()
                                      .blockUser(
                                        currentUid: currentUser.uid,
                                        targetUid: trimmedSellerId,
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text('사용자를 차단했습니다.')),
                                    );
                                    // 차단 후 뒤로가기
                                    Navigator.pop(context);
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('오류 발생: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.more_vert, color: _deepNavy),
              ),
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _SellerHeader(
                    sellerName: displayName,
                    sellerProfileImage: profileImageUrl,
                    tags: tags,
                    temperature: temperature,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SellerTabBarDelegate(
                    TabBar(
                      labelColor: _deepNavy,
                      unselectedLabelColor: Colors.grey.shade500,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(width: 3, color: _iceBlue),
                        insets: EdgeInsets.symmetric(horizontal: 24),
                      ),
                      tabs: [
                        Tab(text: '판매 물품 (${products.length})'),
                        const Tab(text: '받은 후기 (0)'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _SellerProductGrid(
                  products: products,
                  productService: productService,
                  currentUser: currentUser,
                  formatPrice: _formatPrice,
                  formatTimeAgo: _formatTimeAgo,
                ),
                const _SellerReviewPlaceholder(),
              ],
            ),
          ),
        ),
      );
    }

    if (trimmedSellerId.isEmpty) {
      final fallbackName =
          widget.sellerName.isEmpty ? '판매자' : widget.sellerName;
      return buildProfile(
        displayName: fallbackName,
        profileImageUrl: widget.sellerProfileImage,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_profiles')
          .doc(trimmedSellerId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final userModel = data == null
            ? null
            : PublicProfile.fromJson(data, docId: trimmedSellerId);
        final resolvedName = userModel?.nickname.trim().isNotEmpty == true
            ? userModel!.nickname
            : (widget.sellerName.isEmpty ? '판매자' : widget.sellerName);
        final hasUserDoc = data != null;
        final profileImageUrl = userModel?.profileImageUrl?.trim() ?? '';
        final resolvedProfileImage =
            hasUserDoc ? profileImageUrl : widget.sellerProfileImage;

        return buildProfile(
          displayName: resolvedName,
          profileImageUrl: resolvedProfileImage,
        );
      },
    );
  }

  Future<void> _refreshProducts(ProductService productService) async {
    if (_isAutoFetching) {
      return;
    }
    _isAutoFetching = true;
    final trimmedSellerId = widget.sellerId.trim();
    await productService.fetchProductsPaginated(
      sellerId: trimmedSellerId.isEmpty ? null : trimmedSellerId,
      contextKey: _contextKey,
    );
    _isAutoFetching = false;
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({
    required this.sellerName,
    required this.sellerProfileImage,
    required this.tags,
    required this.temperature,
  });

  final String sellerName;
  final String sellerProfileImage;
  final List<String> tags;
  final double temperature;

  @override
  Widget build(BuildContext context) {
    final hasProfileImage = sellerProfileImage.trim().isNotEmpty;
    final ImageProvider avatarImage = hasProfileImage
        ? NetworkImage(sellerProfileImage)
        : const AssetImage('assets/images/user_default.png');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFFE8F4FA),
                backgroundImage: avatarImage,
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00AEEF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sellerName.isEmpty ? '판매자' : sellerName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF101922),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '지역 정보 없음',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '매너온도',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111518),
                      ),
                    ),
                    Text(
                      '${temperature.toStringAsFixed(1)}°C 😀',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00AEEF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: temperature / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF00AEEF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00AEEF),
                    side: const BorderSide(color: Color(0xFF00AEEF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('매너 칭찬하기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00AEEF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('팔로우'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF00AEEF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: tags.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerProductGrid extends StatelessWidget {
  const _SellerProductGrid({
    required this.products,
    required this.productService,
    required this.currentUser,
    required this.formatPrice,
    required this.formatTimeAgo,
  });

  final List<Product> products;
  final ProductService productService;
  final User? currentUser;
  final String Function(int) formatPrice;
  final String Function(DateTime) formatTimeAgo;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      if (productService.isPaginationLoading) {
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      return const Center(
        child: Text(
          '등록된 판매 물품이 없습니다.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          if (productService.hasMoreProducts &&
              !productService.isPaginationLoading) {
            productService.loadMoreProducts();
          }
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.72,
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
          final product = products[index];
          final isLiked = productService.isLiked(product.id);
          return _SellerProductCard(
            product: product,
            priceText: formatPrice(product.price),
            timeText: formatTimeAgo(product.createdAt),
            isLiked: isLiked,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(product: product),
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
              productService.toggleLike(product.id, currentUser!.uid);
            },
          );
        },
      ),
    );
  }
}

class _SellerProductCard extends StatelessWidget {
  const _SellerProductCard({
    required this.product,
    required this.priceText,
    required this.timeText,
    required this.isLiked,
    required this.onTap,
    required this.onLikeTap,
  });

  final Product product;
  final String priceText;
  final String timeText;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  @override
  Widget build(BuildContext context) {
    final isSoldOut = product.status == ProductStatus.soldOut ||
        product.status == ProductStatus.hidden;
    final isReserved = product.status == ProductStatus.reserved;
    final statusLabel = product.status.label;

    return Opacity(
      opacity: isSoldOut ? 0.7 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          color: const Color(0xFFF1F5F9),
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
                    if (isSoldOut)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.85),
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (isReserved)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '예약중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withOpacity(0.25),
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
                              size: 18,
                              color: isLiked
                                  ? Colors.redAccent
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111518),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101922),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerReviewPlaceholder extends StatelessWidget {
  const _SellerReviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '아직 받은 후기가 없습니다.',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SellerTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SellerTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SellerTabBarDelegate oldDelegate) {
    return false;
  }
}
