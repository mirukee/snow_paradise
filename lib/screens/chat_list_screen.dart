import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../models/product.dart';
import '../models/public_profile.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'notification_screen.dart';

/// 채팅 목록 화면
/// Stitch 디자인 기반 - 프로필 이미지, 메시지, 상품 썸네일 표시
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color textGrey = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFF1F5F9);

  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 30;
  int _roomLimit = 30;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  Stream<List<ChatRoom>>? _roomsStream;
  String? _roomsStreamUserId;
  int _roomsStreamLimit = 0;

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
    if (!_scrollController.hasClients || !_hasMore || _isFetchingMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _isFetchingMore = true;
      setState(() {
        _roomLimit += _pageSize;
        final chatService = context.read<ChatService>();
        _roomsStream = chatService.getChatRooms(limit: _roomLimit);
        _roomsStreamLimit = _roomLimit;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        _isFetchingMore = false;
      });
    }
  }

  String _formatLastTime(Timestamp timestamp) {
    final time = timestamp.toDate();
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
      if (difference.inDays == 1) {
        return '어제';
      }
      return '${difference.inDays}일 전';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}.$month.$day';
  }

  String _resolveOtherName(
    ChatRoom room,
    String? currentUserId, {
    PublicProfile? profile,
  }) {
    final nickname = profile?.nickname.trim();
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    final isSeller = currentUserId != null && room.sellerId == currentUserId;
    final otherName = isSeller ? room.buyerName : room.sellerName;
    if (otherName.isNotEmpty) {
      return otherName;
    }
    return isSeller ? '구매자' : '판매자';
  }

  String? _resolveOtherUserId(ChatRoom room, String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
    final isSeller = room.sellerId == currentUserId;
    return isSeller ? room.buyerId : room.sellerId;
  }

  ImageProvider _resolveProfileImage(PublicProfile? profile) {
    final profileImageUrl = profile?.profileImageUrl?.trim();
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return NetworkImage(profileImageUrl);
    }
    return const AssetImage('assets/images/user_default.png');
  }

  void _syncRoomsStream(
    ChatService chatService,
    String? currentUserId,
  ) {
    if (currentUserId == null || currentUserId.isEmpty) {
      _roomsStream = null;
      _roomsStreamUserId = null;
      _roomsStreamLimit = 0;
      return;
    }
    if (_roomsStream == null ||
        _roomsStreamUserId != currentUserId ||
        _roomsStreamLimit != _roomLimit) {
      _roomsStreamUserId = currentUserId;
      _roomsStreamLimit = _roomLimit;
      _roomsStream = chatService.getChatRooms(limit: _roomLimit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserService>().currentUser;
    final currentUserId = currentUser?.uid;
    final chatService = context.read<ChatService>();
    final productService = context.watch<ProductService>();
    _syncRoomsStream(chatService, currentUserId);

    return Scaffold(
      backgroundColor: surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(context),
            // 채팅 목록
            Expanded(
              child: currentUser == null
                  ? _buildLoginRequired()
                  : _buildChatList(
                      context,
                      _roomsStream,
                      productService,
                      currentUserId,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 헤더 - "채팅" 타이틀 + 검색/알림 아이콘
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: backgroundLight,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '채팅',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navyDark,
              letterSpacing: -0.3,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: 채팅 검색 기능
                },
                icon: const Icon(
                  Icons.search,
                  color: textGrey,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: textGrey,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 로그인 필요 상태
  Widget _buildLoginRequired() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: textGrey,
          ),
          SizedBox(height: 16),
          Text(
            '채팅을 보려면 로그인이 필요합니다.',
            style: TextStyle(
              fontSize: 15,
              color: textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 채팅 목록 스트림
  Widget _buildChatList(
    BuildContext context,
    Stream<List<ChatRoom>>? roomsStream,
    ProductService productService,
    String? currentUserId,
  ) {
    if (roomsStream == null) {
      return _buildLoginRequired();
    }
    return StreamBuilder<List<ChatRoom>>(
      stream: roomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryBlue,
            ),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              '채팅 목록을 불러오지 못했어요.',
              style: TextStyle(color: textGrey),
            ),
          );
        }

        final rooms = snapshot.data ?? [];
        _hasMore = rooms.length >= _roomLimit;
        if (rooms.isEmpty) {
          return _buildEmptyState();
        }

        return Container(
          color: backgroundLight,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return _buildChatItem(
                context,
                room,
                productService,
                currentUserId,
              );
            },
          ),
        );
      },
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: textGrey,
          ),
          SizedBox(height: 16),
          Text(
            '아직 시작한 채팅이 없습니다.',
            style: TextStyle(
              fontSize: 15,
              color: textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 채팅 아이템 UI
  Widget _buildChatItem(
    BuildContext context,
    ChatRoom room,
    ProductService productService,
    String? currentUserId,
  ) {
    final lastMessage =
        room.lastMessage.isEmpty ? '대화를 시작해 보세요.' : room.lastMessage;
    final roomId = room.roomId ?? '';
    final isSeller = currentUserId != null && room.sellerId == currentUserId;
    final unreadCount =
        isSeller ? room.unreadCountSeller : room.unreadCountBuyer;
    final otherUserId = _resolveOtherUserId(room, currentUserId);
    final product = productService.getProductById(room.productId);
    final isHiddenForViewer = product?.status == ProductStatus.hidden &&
        currentUserId != null &&
        room.sellerId != currentUserId;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: otherUserId == null || otherUserId.isEmpty
          ? Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
          : FirebaseFirestore.instance
              .collection('public_profiles')
              .doc(otherUserId)
              .snapshots(),
      builder: (context, userSnapshot) {
        final data = userSnapshot.data?.data();
        final profile = data == null
            ? null
            : PublicProfile.fromJson(data, docId: otherUserId);
        final otherName = _resolveOtherName(
          room,
          currentUserId,
          profile: profile,
        );
        final avatarImage = _resolveProfileImage(profile);

        return InkWell(
          onTap: roomId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(room: room),
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                // 프로필 이미지
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: ClipOval(
                    child: Image(
                      image: avatarImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.person,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 메시지 내용
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름 + 시간
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: navyDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatLastTime(room.lastMessageTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: textGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 마지막 메시지 + 읽지 않은 수
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: unreadCount > 0
                                    ? const Color(0xFF1E293B)
                                    : textGrey,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 상품 정보
                      Row(
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            size: 14,
                            color: textGrey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              room.productTitle.isNotEmpty
                                  ? room.productTitle
                                  : '상품 정보 없음',
                              style: const TextStyle(
                                fontSize: 12,
                                color: textGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 상품 썸네일
                _buildProductThumbnail(room, isHiddenForViewer),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 상품 썸네일
  Widget _buildProductThumbnail(ChatRoom room, bool isHiddenForViewer) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: isHiddenForViewer
            ? Container(
                color: Colors.grey[200],
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.grey,
                  size: 20,
                ),
              )
            : room.productImageUrl.isNotEmpty
                ? Image.network(
                    room.productImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
      ),
    );
  }
}
