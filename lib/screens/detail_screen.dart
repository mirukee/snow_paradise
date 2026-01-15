import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [추가] Provider 패키지
import '../models/product.dart';
import '../providers/product_service.dart'; // [추가] ProductService
import '../providers/user_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart' as safety_service;
import '../services/chat_service.dart';
import 'edit_product_screen.dart';
import 'chat_screen.dart';
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

  Color _statusColor(BuildContext context, ProductStatus status) {
    switch (status) {
      case ProductStatus.forSale:
        return Theme.of(context).colorScheme.primary;
      case ProductStatus.reserved:
        return Colors.green;
      case ProductStatus.soldOut:
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
          Icon(Icons.chat_bubble_outline, size: 16, color: chatColor),
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
    final isLiked = productService.isLiked(currentProduct.id);
    final hasEngagement =
        currentProduct.likeCount > 0 || currentProduct.chatCount > 0;
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
        actions: isOwner
            ? []
            : [
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
                ),
              ],
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
                  if (hasEngagement) const SizedBox(height: 12),
                  if (hasEngagement)
                    _buildEngagementRow(context, currentProduct),
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
                  displayStatus == ProductStatus.soldOut,
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
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
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
          child: OutlinedButton(
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
              } catch (_) {
                if (context.mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('채팅방 생성에 실패했어요.')),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: isSoldOut
                    ? Colors.grey.shade300
                    : Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
              foregroundColor: isSoldOut
                  ? Colors.grey.shade500
                  : Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
