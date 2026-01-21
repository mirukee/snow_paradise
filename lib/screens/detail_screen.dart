import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [추가] Provider 패키지
import '../models/product.dart';
import '../models/public_profile.dart';
import '../providers/product_service.dart'; // [추가] ProductService
import '../providers/user_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart' as safety_service;
import '../services/chat_service.dart';
import 'edit_product_screen.dart';
import 'chat_screen.dart';
import 'seller_profile_screen.dart';
import '../widgets/product_image.dart';

enum _DetailMenuAction { report, block }

class DetailScreen extends StatefulWidget {
  final Product product;

  const DetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ProductStatus? _overrideStatus;
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  /// 전체화면 이미지 뷰어 열기
  void _openFullScreenImage(BuildContext context, Product product, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrls: product.imageUrls.isNotEmpty ? product.imageUrls : [product.imageUrl],
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<String?> _promptReportReason(BuildContext context) async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('신고 사유'),
          content: TextField(
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '신고 사유를 입력해 주세요.',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                reason = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: reason.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, reason.trim()),
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmBlockUser(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 차단'),
        content: const Text('이 사용자를 차단하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '차단',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleReport(
    BuildContext context, {
    required Product product,
    required String reporterUid,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (product.sellerId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('신고 대상을 찾을 수 없습니다.')),
      );
      return;
    }

    final reason = await _promptReportReason(context);
    if (reason == null) {
      return;
    }

    try {
      await ReportService().reportItem(
        reporterUid: reporterUid,
        targetUid: product.sellerId,
        targetContentId: product.id,
        reason: reason,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('신고가 접수되었습니다.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('신고에 실패했어요.')),
      );
    }
  }

  Future<void> _handleBlock(
    BuildContext context, {
    required Product product,
    required String currentUserId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (product.sellerId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('차단 대상을 찾을 수 없습니다.')),
      );
      return;
    }

    final confirm = await _confirmBlockUser(context);
    if (!confirm) {
      return;
    }

    try {
      await safety_service.UserService().blockUser(
        currentUid: currentUserId,
        targetUid: product.sellerId,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('사용자를 차단했어요.')),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('차단에 실패했어요.')),
      );
    }
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

  String _formatTradeLocation(String tradeLocationKey) {
    final trimmed = tradeLocationKey.trim();
    if (trimmed.isEmpty) {
      return '거래 장소 미정';
    }
    if (trimmed.startsWith('city:')) {
      return trimmed.replaceFirst('city:', '');
    }
    if (trimmed.startsWith('resort:')) {
      return trimmed.replaceFirst('resort:', '');
    }
    return trimmed;
  }

  Color _statusColor(BuildContext context, ProductStatus status) {
    switch (status) {
      case ProductStatus.forSale:
        return Theme.of(context).colorScheme.primary;
      case ProductStatus.reserved:
        return Colors.green;
      case ProductStatus.soldOut:
        return Colors.grey;
      case ProductStatus.hidden:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(BuildContext context, ProductStatus status) {
    final color = _statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEngagementRow(BuildContext context, Product product) {
    final hasLike = product.likeCount > 0;
    final hasChat = product.chatCount > 0;
    if (!hasLike && !hasChat) {
      return const SizedBox.shrink();
    }
    final chatColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        if (hasLike) ...[
          const Icon(Icons.favorite, size: 16, color: Colors.redAccent),
          const SizedBox(width: 6),
          Text(
            '${product.likeCount}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
        if (hasLike && hasChat) const SizedBox(width: 12),
        if (hasChat) ...[
          Icon(Icons.forum_rounded, size: 16, color: chatColor),
          const SizedBox(width: 6),
          Text(
            '${product.chatCount}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleStatusChange(
    Product product,
    ProductStatus newStatus,
  ) async {
    final previousStatus = _overrideStatus ?? product.status;
    setState(() {
      _overrideStatus = newStatus;
    });

    try {
      await context.read<ProductService>().updateProductStatus(
            product.id,
            newStatus,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _overrideStatus = previousStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('판매 상태 변경에 실패했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // [추가] Provider를 통해 찜 상태 실시간 감지
    final productService = context.watch<ProductService>();
    final currentUser = context.watch<UserService>().currentUser;
    final currentProduct =
        productService.getProductById(widget.product.id) ?? widget.product;
    final displayStatus = _overrideStatus ?? currentProduct.status;
    final tradeLocationText =
        _formatTradeLocation(currentProduct.tradeLocationKey);
    final isLiked = productService.isLiked(currentProduct.id);
    final hasEngagement =
        currentProduct.likeCount > 0 || currentProduct.chatCount > 0;
    final sellerId = currentProduct.sellerId.trim();
    final fallbackSellerName = currentProduct.sellerName.trim().isNotEmpty
        ? currentProduct.sellerName.trim()
        : '판매자';
    final fallbackSellerProfile = currentProduct.sellerProfile.trim();
    final currentUserId = currentUser?.uid;
    final currentUserName = currentUser?.displayName ?? currentUser?.email ?? '';
    final currentUserPhoto = currentUser?.photoURL ?? '';
    final isOwner = currentUser != null &&
        (currentProduct.sellerId.isNotEmpty
            ? currentProduct.sellerId == currentUserId
            : currentProduct.sellerName == currentUserName &&
                currentProduct.sellerProfile == currentUserPhoto);

    const iceBlue = Color(0xFF00AEEF);
    const textDark = Color(0xFF111518);
    const softBorder = Color(0xFFE3EEF8);
    const softSurface = Color(0xFFF5F8FC);

    if (displayStatus == ProductStatus.hidden && !isOwner) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            '상품 보기',
            style: TextStyle(fontWeight: FontWeight.bold, color: textDark),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            '숨김 처리된 상품입니다.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    // 다중 이미지 슬라이더
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: currentProduct.imageUrls.isEmpty
                          ? GestureDetector(
                              onTap: () => _openFullScreenImage(context, currentProduct, 0),
                              child: buildProductImage(
                                currentProduct,
                                fit: BoxFit.cover,
                                errorIconSize: 80,
                                loadingWidget: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            )
                          : PageView.builder(
                              controller: _imagePageController,
                              itemCount: currentProduct.imageUrls.length,
                              onPageChanged: (index) {
                                setState(() => _currentImageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _openFullScreenImage(context, currentProduct, index),
                                  child: Image.network(
                                    currentProduct.imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 80,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    // 이미지 인디케이터 (2개 이상일 때만 표시)
                    if (currentProduct.imageUrls.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              currentProduct.imageUrls.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: index == _currentImageIndex ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index == _currentImageIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Gradient 오버레이 - IgnorePointer로 터치 통과
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.white,
                              ],
                              stops: const [0, 0.25, 0.7, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentProduct.brand.isNotEmpty)
                        Text(
                          currentProduct.brand,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: iceBlue,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        currentProduct.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatPrice(currentProduct.price),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: iceBlue,
                        ),
                      ),
                      if (hasEngagement) const SizedBox(height: 12),
                      if (hasEngagement)
                        _buildEngagementRow(context, currentProduct),
                      const SizedBox(height: 20),
                      Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: softBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: sellerId.isEmpty
                            ? InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  if (currentProduct.sellerName.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('판매자 정보를 찾을 수 없어요.'),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SellerProfileScreen(
                                        sellerId: currentProduct.sellerId,
                                        sellerName: fallbackSellerName,
                                        sellerProfileImage: fallbackSellerProfile,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage:
                                            fallbackSellerProfile.isNotEmpty
                                                ? NetworkImage(
                                                    fallbackSellerProfile,
                                                  )
                                                : const AssetImage(
                                                    'assets/images/user_default.png',
                                                  ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fallbackSellerName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: textDark,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
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
                                      _buildStatusChip(context, displayStatus),
                                    ],
                                  ),
                                ),
                              )
                            : StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('public_profiles')
                                    .doc(sellerId)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final data = snapshot.data?.data();
                                  final userModel = data == null
                                      ? null
                                      : PublicProfile.fromJson(
                                          data,
                                          docId: sellerId,
                                        );
                                  final resolvedName =
                                      userModel?.nickname.trim().isNotEmpty == true
                                          ? userModel!.nickname
                                          : fallbackSellerName;
                                  final userProfileImage =
                                      userModel?.profileImageUrl?.trim() ?? '';
                                  final resolvedProfileImage =
                                      data == null ? '' : userProfileImage;
                                  final ImageProvider avatarImage =
                                      resolvedProfileImage.isNotEmpty
                                          ? NetworkImage(resolvedProfileImage)
                                          : const AssetImage(
                                              'assets/images/user_default.png',
                                            );

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      if (currentProduct.sellerName.trim().isEmpty &&
                                          currentProduct.sellerId.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('판매자 정보를 찾을 수 없어요.'),
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SellerProfileScreen(
                                            sellerId: currentProduct.sellerId,
                                            sellerName: resolvedName,
                                            sellerProfileImage: resolvedProfileImage,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.grey.shade200,
                                            backgroundImage: avatarImage,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  resolvedName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
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
                                          _buildStatusChip(context, displayStatus),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '제품 상세',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (currentProduct.size.isNotEmpty)
                            _buildDetailChip('길이: ${currentProduct.size}'),
                          if (currentProduct.condition.isNotEmpty)
                            _buildDetailChip('상태: ${currentProduct.condition}'),
                          if (currentProduct.year.isNotEmpty)
                            _buildDetailChip('연식: ${currentProduct.year}'),
                          if (currentProduct.brand.isNotEmpty)
                            _buildDetailChip('브랜드: ${currentProduct.brand}'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '제품 설명',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentProduct.description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF3F5263),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '거래 희망 장소',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: softSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: softBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              tradeLocationText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _buildGlassIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    if (!isOwner)
                      PopupMenuButton<_DetailMenuAction>(
                        onSelected: (action) {
                          if (currentUserId == null || currentUserId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('로그인이 필요합니다.')),
                            );
                            return;
                          }
                          if (action == _DetailMenuAction.report) {
                            _handleReport(
                              context,
                              product: currentProduct,
                              reporterUid: currentUserId,
                            );
                          } else if (action == _DetailMenuAction.block) {
                            _handleBlock(
                              context,
                              product: currentProduct,
                              currentUserId: currentUserId,
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _DetailMenuAction.report,
                            child: Text('이 게시글 신고하기'),
                          ),
                          PopupMenuItem(
                            value: _DetailMenuAction.block,
                            child: Text('이 사용자 차단하기'),
                          ),
                        ],
                        child: _buildGlassIcon(icon: Icons.more_vert),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // 하단 고정 버튼
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: isOwner
              ? _buildOwnerActions(
                  context,
                  currentProduct,
                  displayStatus,
                )
              : _buildBuyerActions(
                  context,
                  currentProduct,
                  productService,
                  isLiked,
                  displayStatus == ProductStatus.soldOut ||
                      displayStatus == ProductStatus.hidden,
                ),
        ),
      ),
    );
  }

  Widget _buildOwnerActions(
    BuildContext context,
    Product product,
    ProductStatus displayStatus,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              '판매 상태',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            _buildStatusChip(context, displayStatus),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProductStatus>(
                  value: displayStatus,
                  items: ProductStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  onChanged: (status) {
                    if (status == null || status == displayStatus) return;
                    _handleStatusChange(product, status);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
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
                    final docId = product.docId;
                    if (docId == null || docId.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('삭제에 실패했습니다.')),
                      );
                      return;
                    }
                    await context
                        .read<ProductService>()
                        .deleteProduct(docId, product.imageUrl);
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
        ),
      ],
    );
  }

  Widget _buildBuyerActions(
    BuildContext context,
    Product product,
    ProductService productService,
    bool isLiked,
    bool isSoldOut,
  ) {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: () {
              final currentUser = context.read<UserService>().currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그인이 필요합니다.')),
                );
                return;
              }
              productService.toggleLike(product.id, currentUser.uid);
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
          child: ElevatedButton(
            onPressed: isSoldOut
                ? null
                : () async {
              final currentUser = context.read<UserService>().currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그인이 필요합니다.')),
                );
                return;
              }
              if (product.sellerId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('판매자 정보를 찾을 수 없어요.')),
                );
                return;
              }

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                final room = await context.read<ChatService>().getOrCreateChatRoom(
                  product.id,
                  product.sellerId,
                  product.title,
                  product.imageUrl,
                  product.price,
                  product.sellerName,
                );
                if (context.mounted) {
                  navigator.pop();
                }
                if (!context.mounted) return;
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      room: room,
                    ),
                  ),
                );
              } catch (error, stackTrace) {
                debugPrint('채팅방 생성 실패: $error');
                debugPrint('$stackTrace');
                if (context.mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('채팅방 생성에 실패했어요.')),
                  );
                  }
                }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor:
                  isSoldOut ? Colors.grey.shade200 : const Color(0xFF00AEEF),
              foregroundColor:
                  isSoldOut ? Colors.grey.shade600 : const Color(0xFF101922),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isSoldOut ? '거래가 완료된 상품입니다' : '채팅하기',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EEF8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3F5263),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: _buildGlassIcon(icon: icon),
    );
  }

  Widget _buildGlassIcon({required IconData icon}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );
  }
}

/// 전체화면 이미지 뷰어
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 이미지 슬라이더
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              if (url.isEmpty) {
                return const Center(
                  child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                );
              }
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey,
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // 닫기 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          // 페이지 인디케이터
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
