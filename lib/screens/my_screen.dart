import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/user_model.dart';
import '../providers/main_tab_provider.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../widgets/product_image.dart';
import 'detail_screen.dart';
import 'like_list_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

const _iceBlue = Color(0xFF00AEEF);
const _deepNavy = Color(0xFF101922);
const _pageBackground = Color(0xFFF6F7F8);
const _surfaceColor = Colors.white;
const _borderLight = Color(0xFFE6ECF2);
const _mutedText = Color(0xFF8A94A6);
const _softBlue = Color(0xFFEEF7FF);
const _tabInactive = Color(0xFF9AA4B2);

enum _SalesTab { selling, completed, hidden }

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  _SalesTab _selectedTab = _SalesTab.selling;
  final GlobalKey _salesSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  Stream<List<Product>> _sellerProductsStream(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return Stream.value(const <Product>[]);
    }
    return FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: trimmedUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromJson(doc.data(), docId: doc.id))
              .toList(),
        );
  }

  Stream<int> _likedCountStream(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return Stream.value(0);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(trimmedUid)
        .collection('likes')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
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

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _selectTab(_SalesTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
    });
  }

  void _openSalesSection({_SalesTab tab = _SalesTab.selling}) {
    if (_selectedTab != tab) {
      setState(() {
        _selectedTab = tab;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _salesSectionKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  Future<void> _handleStatusChange(
    Product product,
    ProductStatus newStatus,
  ) async {
    try {
      await context.read<ProductService>().updateProductStatus(
            product.id,
            newStatus,
          );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(context, '판매 상태 변경에 실패했어요.');
    }
  }

  Future<void> _showStatusChangeSheet(
    BuildContext context,
    Product product,
  ) async {
    final statuses = [
      ProductStatus.forSale,
      ProductStatus.reserved,
      ProductStatus.soldOut,
      ProductStatus.hidden,
    ];

    final selectedStatus = await showModalBottomSheet<ProductStatus>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '판매 상태 변경',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...statuses.map((status) {
                final isSelected = status == product.status;
                return ListTile(
                  title: Text(
                    status.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? _deepNavy : _mutedText,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: _iceBlue)
                      : null,
                  onTap: () => Navigator.pop(context, status),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selectedStatus == null || selectedStatus == product.status) {
      return;
    }

    await _handleStatusChange(product, selectedStatus);
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    Product product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final productService = context.read<ProductService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('상품 삭제'),
        content: const Text('정말 이 상품을 삭제하시겠어요? 삭제 후 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final docId = product.docId?.trim() ?? '';
    if (docId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('상품 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    try {
      await productService.deleteProduct(
            docId,
            product.imageUrl,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('상품이 삭제되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('상품 삭제에 실패했어요.')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserService>().currentUser;
    if (user == null) {
      return _buildGuestView(context);
    }
    return _buildUserView(context, user);
  }

  // ==========================================
  // 1. 로그인 안 했을 때 보이는 화면 (Guest View)
  // ==========================================
  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(fontWeight: FontWeight.bold, color: _deepNavy),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _borderLight),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: _buildSocialButton(
                  context,
                  backgroundColor: Colors.white,
                  borderColor: Colors.grey.shade400,
                  textColor: Colors.black,
                  text: 'Google로 계속하기',
                  logo: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                    width: 20,
                    height: 20,
                  ),
                  elevation: 0,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final user = await context.read<UserService>().loginWithGoogle();
                      if (user == null) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('구글 로그인 완료!')),
                      );
                    } on FirebaseAuthException catch (error) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error.message ?? '로그인에 실패했습니다.')),
                      );
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('로그인에 실패했습니다.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final user =
                        await context.read<UserService>().signInAnonymously();
                    if (user == null) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('게스트 로그인 완료!')),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('게스트 로그인에 실패했습니다.')),
                    );
                  }
                },
                child: Text(
                  '게스트로 체험하기',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _buildSocialButton(
                  context,
                  backgroundColor: const Color(0xFFFEE500),
                  borderColor: Colors.transparent,
                  textColor: Colors.black,
                  text: 'Kakao로 계속하기',
                  logo: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/KakaoTalk_logo.svg/800px-KakaoTalk_logo.svg.png',
                    width: 20,
                    height: 20,
                  ),
                  elevation: 1,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('카카오 로그인은 준비 중입니다.')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _buildSocialButton(
                  context,
                  backgroundColor: Colors.black,
                  borderColor: Colors.transparent,
                  textColor: Colors.white,
                  text: 'Apple로 계속하기',
                  logo: const Icon(Icons.apple, color: Colors.white, size: 20),
                  elevation: 1,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('애플 로그인은 준비 중입니다.')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. 로그인 했을 때 보이는 화면 (User View)
  // ==========================================
  Widget _buildUserView(BuildContext context, User user) {
    final isActiveTab =
        context.watch<MainTabProvider>().currentIndex == 4;
    final userStream = isActiveTab
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
        : Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final userModel = data == null ? null : UserModel.fromJson(data);
        final displayName = userModel?.nickname.isNotEmpty == true
            ? userModel!.nickname
            : (user.displayName ?? user.email ?? '사용자');
        final profileImageUrl = userModel?.profileImageUrl?.trim();
        final ImageProvider avatarImage =
            (profileImageUrl != null && profileImageUrl.isNotEmpty)
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/images/user_default.png');
        return StreamBuilder<List<Product>>(
          stream: isActiveTab
              ? _sellerProductsStream(user.uid)
              : Stream<List<Product>>.empty(),
          builder: (context, productsSnapshot) {
            final userProducts = productsSnapshot.data ?? [];
            final isLoadingProducts =
                productsSnapshot.connectionState == ConnectionState.waiting;
            final sellingProducts = userProducts
                .where(
                  (product) =>
                      product.status == ProductStatus.forSale ||
                      product.status == ProductStatus.reserved,
                )
                .toList();
            final completedProducts = userProducts
                .where((product) => product.status == ProductStatus.soldOut)
                .toList();
            final hiddenProducts = userProducts
                .where((product) => product.status == ProductStatus.hidden)
                .toList();

            final selectedProducts = _selectedTab == _SalesTab.completed
                ? completedProducts
                : _selectedTab == _SalesTab.hidden
                    ? hiddenProducts
                    : sellingProducts;

            return StreamBuilder<int>(
              stream: isActiveTab
                  ? _likedCountStream(user.uid)
                  : Stream<int>.empty(),
              builder: (context, likedSnapshot) {
                final likedCount = likedSnapshot.data ?? 0;
                return Scaffold(
                  backgroundColor: _pageBackground,
                  appBar: AppBar(
                    title: const Text(
                      '마이페이지',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _deepNavy,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    centerTitle: false,
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings, color: _deepNavy),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(height: 1, color: _borderLight),
                    ),
                  ),
                  body: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(
                          context,
                          displayName: displayName,
                          avatarImage: avatarImage,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  context,
                                  icon: Icons.favorite,
                                  label: '관심목록',
                                  count: likedCount,
                                  iconColor: const Color(0xFFE74C3C),
                                  iconBackground: const Color(0xFFFFF1F1),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LikeListScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDashboardCard(
                                  context,
                                  icon: Icons.receipt_long,
                                  label: '판매내역',
                                  count: userProducts.length,
                                  iconColor: _iceBlue,
                                  iconBackground: const Color(0xFFE8F4FF),
                                  onTap: () {
                                    _openSalesSection();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDashboardCard(
                                  context,
                                  icon: Icons.shopping_bag,
                                  label: '구매내역',
                                  count: 0,
                                  iconColor: const Color(0xFFF39C12),
                                  iconBackground:
                                      const Color(0xFFFFF3E0),
                                  onTap: () {
                                    _showSnackBar(
                                      context,
                                      '구매내역은 준비 중입니다.',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSalesSection(
                          context,
                          products: selectedProducts,
                          selectedTab: _selectedTab,
                          sellingCount: sellingProducts.length,
                          completedCount: completedProducts.length,
                          hiddenCount: hiddenProducts.length,
                          isLoading: isLoadingProducts,
                          onTabSelected: _selectTab,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required String displayName,
    required ImageProvider avatarImage,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE2E8F0),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: avatarImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: _borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: _mutedText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _deepNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('프로필 수정'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4B5563),
                        backgroundColor: const Color(0xFFF5F7FA),
                        side: const BorderSide(color: _borderLight),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildMannerCard(context),
        ],
      ),
    );
  }

  Widget _buildMannerCard(BuildContext context) {
    const temperature = 42.5;
    const firstTemperature = 36.5;
    final progress = (temperature / 100).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '매너온도',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _mutedText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Text(
                        '42.5°C',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _iceBlue,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.sentiment_satisfied,
                        color: _iceBlue,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _showSnackBar(context, '매너온도 상세는 준비 중입니다.');
                },
                style: TextButton.styleFrom(
                  foregroundColor: _mutedText,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: const [
                    Text(
                      '자세히 보기',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7CCBFF),
                        _iceBlue,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '첫 온도 ${firstTemperature.toStringAsFixed(1)}°C',
              style: const TextStyle(fontSize: 11, color: _mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required Color iconColor,
    required Color iconBackground,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _deepNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesSection(
    BuildContext context, {
    required List<Product> products,
    required _SalesTab selectedTab,
    required int sellingCount,
    required int completedCount,
    required int hiddenCount,
    required ValueChanged<_SalesTab> onTabSelected,
    bool isLoading = false,
  }) {
    final emptyMessage = selectedTab == _SalesTab.completed
        ? '거래완료 상품이 없습니다.'
        : selectedTab == _SalesTab.hidden
            ? '숨김 상품이 없습니다.'
            : '판매중 상품이 없습니다.';

    return Container(
      key: _salesSectionKey,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      constraints: const BoxConstraints(minHeight: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSalesTabs(
            sellingCount: sellingCount,
            completedCount: completedCount,
            hiddenCount: hiddenCount,
            selectedTab: selectedTab,
            onTabSelected: onTabSelected,
          ),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      emptyMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
            )
          else
            ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: products.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: _borderLight,
              ),
              itemBuilder: (context, index) {
                return _buildSaleItem(context, products[index]);
              },
            ),
          _buildSupportMenu(context),
        ],
      ),
    );
  }

  Widget _buildSalesTabs({
    required int sellingCount,
    required int completedCount,
    required int hiddenCount,
    required _SalesTab selectedTab,
    required ValueChanged<_SalesTab> onTabSelected,
  }) {
    Widget buildTab(String title, int count, _SalesTab tab) {
      final isSelected = selectedTab == tab;
      final textColor = isSelected ? _deepNavy : _tabInactive;
      final weight = isSelected ? FontWeight.w700 : FontWeight.w600;
      return Expanded(
        child: InkWell(
          onTap: () => onTabSelected(tab),
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: weight,
                        color: textColor,
                      ),
                      children: [
                        TextSpan(text: title),
                        if (count > 0)
                          TextSpan(
                            text: ' $count',
                            style: const TextStyle(
                              color: _iceBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _deepNavy,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderLight)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        color: _surfaceColor,
      ),
      child: Row(
        children: [
          buildTab('판매중', sellingCount, _SalesTab.selling),
          buildTab('거래완료', completedCount, _SalesTab.completed),
          buildTab('숨김', hiddenCount, _SalesTab.hidden),
        ],
      ),
    );
  }

  Widget _buildSaleItem(BuildContext context, Product product) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 96,
                  height: 96,
                  color: const Color(0xFFF1F3F6),
                  child: buildProductImage(
                    product,
                    fit: BoxFit.cover,
                    errorIconSize: 20,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _deepNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _confirmDeleteProduct(context, product);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('삭제'),
                            ),
                          ],
                          icon: const Icon(
                            Icons.more_vert,
                            size: 20,
                            color: _mutedText,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(product),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _mutedText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatPrice(product.price),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _deepNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: '끌어올리기',
                            icon: Icons.vertical_align_top,
                            onTap: () {
                              _showSnackBar(context, '끌어올리기는 준비 중입니다.');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            label: '상태변경',
                            onTap: () {
                              _showStatusChangeSheet(context, product);
                            },
                          ),
                        ),
                      ],
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

  Widget _buildActionButton({
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final backgroundColor =
        enabled ? _surfaceColor : const Color(0xFFF1F5F9);
    final borderColor =
        enabled ? const Color(0xFFE1E7EE) : const Color(0xFFE5E7EB);
    final textColor =
        enabled ? const Color(0xFF3B4B5F) : const Color(0xFFB0B8C1);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportMenu(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _pageBackground, width: 8)),
      ),
      child: Column(
        children: [
          _buildSupportItem(
            context,
            title: '자주 묻는 질문',
            onTap: () => _showSnackBar(context, '자주 묻는 질문은 준비 중입니다.'),
          ),
          _buildSupportDivider(),
          _buildSupportItem(
            context,
            title: '고객센터',
            onTap: () => _showSnackBar(context, '고객센터는 준비 중입니다.'),
          ),
          _buildSupportDivider(),
          _buildSupportItem(
            context,
            title: '공지사항',
            onTap: () => _showSnackBar(context, '공지사항은 준비 중입니다.'),
          ),
          _buildSupportDivider(),
          _buildSupportItem(
            context,
            title: '약관 및 정책',
            onTap: () => _showSnackBar(context, '약관 및 정책은 준비 중입니다.'),
          ),
          _buildSupportDivider(),
          _buildSupportItem(
            context,
            title: '설정',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          _buildSupportDivider(),
          _buildSupportItem(
            context,
            title: '로그아웃',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<UserService>().signOut();
                messenger.showSnackBar(
                  const SnackBar(content: Text('로그아웃 되었습니다.')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('로그아웃에 실패했습니다.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportDivider() {
    return const Divider(height: 1, color: _borderLight);
  }

  Widget _buildSupportItem(
    BuildContext context, {
    required String title,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _deepNavy,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _mutedText),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required String text,
    required Widget logo,
    required double elevation,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        elevation: elevation,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: borderColor == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: logo)),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
