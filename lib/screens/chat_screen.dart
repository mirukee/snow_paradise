import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../models/product.dart';
import '../models/public_profile.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../services/chat_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart' as safety_service;
import 'detail_screen.dart';

enum _ChatMenuAction { report, block, leave }

/// 채팅방 화면
/// Stitch 디자인 기반 - 상품 정보 바, 메시지 버블, 입력 영역
class ChatScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatScreen({
    super.key,
    required this.room,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 색상 상수
  static const Color primaryBlue = Color(0xFF3E97EA);
  static const Color textDark = Color(0xFF111518);
  static const Color textGrey = Color(0xFF637688);
  static const Color backgroundChat = Color(0xFFF6F7F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFF1F5F9);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 30;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastMessageDoc;
  final List<ChatMessage> _olderMessages = [];
  String? _activeRoomId;
  Timer? _markAsReadDebounce;

  Future<String?> _promptReportReason(BuildContext context) async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
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

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _markAsReadDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMore || _isFetchingMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isFetchingMore || !_hasMore) {
      return;
    }
    final roomId = _activeRoomId;
    if (roomId == null || roomId.isEmpty) {
      return;
    }
    if (_lastMessageDoc == null) {
      return;
    }

    setState(() {
      _isFetchingMore = true;
    });

    try {
      final page = await context.read<ChatService>().getMessagesPage(
            roomId,
            lastDoc: _lastMessageDoc,
            limit: _pageSize,
          );
      if (!mounted) return;
      if (page.messages.isNotEmpty) {
        _appendOlderMessages(page.messages);
      }
      _lastMessageDoc = page.lastDoc;
      _hasMore = page.hasMore;
    } catch (_) {
      _hasMore = false;
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
        });
      }
    }
  }

  String _messageKey(ChatMessage message) {
    if (message.id.isNotEmpty) {
      return message.id;
    }
    return '${message.senderId}|${message.createdAt.millisecondsSinceEpoch}|${message.text}';
  }

  void _appendOlderMessages(List<ChatMessage> messages) {
    final existingKeys =
        _olderMessages.map(_messageKey).toSet();
    for (final message in messages) {
      final key = _messageKey(message);
      if (!existingKeys.add(key)) {
        continue;
      }
      _olderMessages.add(message);
    }
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> latestMessages,
    List<ChatMessage> olderMessages,
  ) {
    final merged = <String, ChatMessage>{};
    for (final message in olderMessages) {
      merged[_messageKey(message)] = message;
    }
    for (final message in latestMessages) {
      merged[_messageKey(message)] = message;
    }
    final values = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  void _markLatestAsReadIfNeeded({
    required List<ChatMessage> messages,
    required String? currentUserId,
    required String? roomId,
    required Timestamp? lastReadAt,
    required int? unreadCount,
    required bool isSeller,
    required bool isBuyer,
  }) {
    if (messages.isEmpty) {
      return;
    }
    if (roomId == null || roomId.isEmpty) {
      return;
    }
    final latestMessage = messages.first;
    final isFromOther = latestMessage.senderId != currentUserId;
    if (!isFromOther) {
      return;
    }
    final hasUnread = unreadCount != null && unreadCount > 0;
    final hasNewerThanLastReadAt = lastReadAt == null ||
        lastReadAt.compareTo(latestMessage.createdAt) < 0;
    if (!hasUnread && !hasNewerThanLastReadAt) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleMarkAsRead(
        roomId,
        isSeller: isSeller,
        isBuyer: isBuyer,
      );
    });
  }

  Future<void> _sendMessage(ChatRoom room) async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final currentUser = context.read<UserService>().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    try {
      await context.read<ChatService>().sendMessage(room, text);
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지 전송에 실패했어요.')),
      );
    }
  }

  String _formatPrice(int price) {
    final buffer = StringBuffer();
    final priceString = price.toString();
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(priceString[i]);
    }
    buffer.write('원');
    return buffer.toString();
  }

  String _formatMessageTime(Timestamp timestamp) {
    final time = timestamp.toDate();
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour <= 12 ? hour : hour - 12;
    return '$period $displayHour:$minute';
  }

  String _formatDateSeparator(DateTime date) {
    final weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${date.year}년 ${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}';
  }

  String _resolveOtherName(
    String? currentUserId, {
    PublicProfile? userModel,
  }) {
    final nickname = userModel?.nickname.trim();
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    final isSeller =
        currentUserId != null && widget.room.sellerId == currentUserId;
    final name = isSeller ? widget.room.buyerName : widget.room.sellerName;
    return name.isNotEmpty ? name : '상대방';
  }

  String? _resolveOtherUserId(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
    final isSeller = widget.room.sellerId == currentUserId;
    return isSeller ? widget.room.buyerId : widget.room.sellerId;
  }

  Timestamp? _resolveMyLastReadAt(ChatRoom? room, String? currentUserId) {
    if (room == null || currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
    final isSeller = room.sellerId == currentUserId;
    return isSeller ? room.lastReadAtSeller : room.lastReadAtBuyer;
  }

  Timestamp? _resolveOtherLastReadAt(ChatRoom? room, String? currentUserId) {
    if (room == null || currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
    final isSeller = room.sellerId == currentUserId;
    return isSeller ? room.lastReadAtBuyer : room.lastReadAtSeller;
  }

  int? _resolveMyUnreadCount(ChatRoom? room, String? currentUserId) {
    if (room == null || currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
    final isSeller = room.sellerId == currentUserId;
    return isSeller ? room.unreadCountSeller : room.unreadCountBuyer;
  }

  void _scheduleMarkAsRead(
    String roomId, {
    required bool isSeller,
    required bool isBuyer,
  }) {
    _markAsReadDebounce?.cancel();
    _markAsReadDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<ChatService>().markAsRead(
            roomId,
            isSeller: isSeller,
            isBuyer: isBuyer,
          );
    });
  }

  ImageProvider _resolveProfileImage(PublicProfile? profile) {
    final profileImageUrl = profile?.profileImageUrl?.trim();
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return NetworkImage(profileImageUrl);
    }
    return const AssetImage('assets/images/user_default.png');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserService>().currentUser?.uid;
    final otherUserId = _resolveOtherUserId(currentUserId);
    final roomId = widget.room.roomId;
    final chatService = context.read<ChatService>();
    final productService = context.watch<ProductService>();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: otherUserId == null || otherUserId.isEmpty
          ? Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
          : FirebaseFirestore.instance
              .collection('public_profiles')
              .doc(otherUserId)
              .snapshots(),
      builder: (context, userSnapshot) {
        final data = userSnapshot.data?.data();
        final otherUser = data == null
            ? null
            : PublicProfile.fromJson(data, docId: otherUserId);
        final otherName =
            _resolveOtherName(currentUserId, userModel: otherUser);
        final avatarImage = _resolveProfileImage(otherUser);

        return StreamBuilder<ChatRoom?>(
          stream: roomId == null || roomId.isEmpty
              ? Stream<ChatRoom?>.value(widget.room)
              : chatService.watchChatRoom(roomId),
          builder: (context, roomSnapshot) {
            final room = roomSnapshot.data ?? widget.room;
            final product = productService.getProductById(room.productId);
            final isHiddenForViewer = product?.status == ProductStatus.hidden &&
                currentUserId != null &&
                room.sellerId != currentUserId;

            return Scaffold(
              backgroundColor: backgroundChat,
              body: SafeArea(
                child: Column(
                  children: [
                    // 헤더
                    _buildHeader(
                      context,
                      otherName,
                      currentUserId,
                      otherUserId,
                    ),
                    // 상품 정보 바
                    _buildProductInfoBar(product, isHiddenForViewer),
                    // 메시지 영역
                    Expanded(
                      child: _buildMessageArea(
                        context,
                        roomId,
                        currentUserId,
                        avatarImage,
                        room,
                      ),
                    ),
                    // 입력 영역
                    _buildInputArea(room),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 헤더 - 뒤로가기, 상대방 이름, 더보기 메뉴
  Widget _buildHeader(
    BuildContext context,
    String otherName,
    String? currentUserId,
    String? otherUserId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: surfaceLight,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            // 뒤로가기 버튼
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: textDark,
                size: 22,
              ),
            ),
            // 상대방 이름
            Expanded(
              child: Text(
                otherName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            // 더보기 메뉴
            PopupMenuButton<_ChatMenuAction>(
              icon: const Icon(
                Icons.more_horiz,
                color: textDark,
                size: 24,
              ),
              onSelected: (action) =>
                  _handleMenuAction(action, currentUserId, otherUserId),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ChatMenuAction.report,
                  child: Text('신고하기'),
                ),
                PopupMenuItem(
                  value: _ChatMenuAction.block,
                  child: Text('차단하기'),
                ),
                PopupMenuItem(
                  value: _ChatMenuAction.leave,
                  child: Text('채팅방 나가기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 메뉴 액션 처리
  Future<void> _handleMenuAction(
    _ChatMenuAction action,
    String? currentUserId,
    String? otherUserId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final roomId = widget.room.roomId;
    final chatService = context.read<ChatService>();
    final navigator = Navigator.of(context);

    if (currentUserId == null || currentUserId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    if (otherUserId == null || otherUserId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('상대방 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    if (action == _ChatMenuAction.report) {
      final reason = await _promptReportReason(context);
      if (reason == null) return;
      try {
        final targetRoomId = roomId ?? '';
        if (targetRoomId.isEmpty) {
          throw StateError('채팅방 정보를 찾을 수 없습니다.');
        }
        await ReportService().reportItem(
          reporterUid: currentUserId,
          targetUid: otherUserId,
          targetContentId: targetRoomId,
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
      return;
    }

    if (action == _ChatMenuAction.block) {
      final confirm = await _confirmAction(
        context,
        title: '사용자 차단',
        message: '이 사용자를 차단하시겠어요?',
        confirmLabel: '차단',
      );
      if (!confirm) return;
      try {
        await safety_service.UserService().blockUser(
          currentUid: currentUserId,
          targetUid: otherUserId,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('사용자를 차단했어요.')),
        );
        if (!mounted) return;
        navigator.pop();
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('차단에 실패했어요.')),
        );
      }
      return;
    }

    if (action == _ChatMenuAction.leave) {
      final confirm = await _confirmAction(
        context,
        title: '채팅방 나가기',
        message: '이 채팅방을 나가시겠어요?',
        confirmLabel: '나가기',
      );
      if (!confirm) return;
      try {
        final targetRoomId = roomId ?? '';
        if (targetRoomId.isEmpty) {
          throw StateError('채팅방 정보를 찾을 수 없습니다.');
        }
        await chatService.leaveChatRoom(targetRoomId);
        messenger.showSnackBar(
          const SnackBar(content: Text('채팅방을 나갔어요.')),
        );
        if (!mounted) return;
        navigator.pop();
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('채팅방 나가기에 실패했어요.')),
        );
      }
    }
  }

  /// 상품 정보 바
  Widget _buildProductInfoBar(Product? product, bool isHiddenForViewer) {
    return GestureDetector(
      onTap: () {
        // 상품이 있고 숨김 처리되지 않은 경우에만 상세 페이지로 이동
        if (product != null && !isHiddenForViewer) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailScreen(product: product),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isHiddenForViewer
            ? Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '숨김 처리된 상품입니다.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textGrey,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  // 상품 이미지
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: widget.room.productImageUrl.isNotEmpty
                          ? Image.network(
                              widget.room.productImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 상품 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.productTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatPrice(widget.room.productPrice),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 상태 배지
                  if (product != null) _buildStatusBadge(product.status),
                ],
              ),
      ),
    );
  }

  /// 상태 배지
  Widget _buildStatusBadge(ProductStatus status) {
    final Color backgroundColor;
    final Color textColor;

    switch (status) {
      case ProductStatus.forSale:
        backgroundColor = primaryBlue.withValues(alpha: 0.1);
        textColor = primaryBlue;
        break;
      case ProductStatus.reserved:
        backgroundColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        break;
      case ProductStatus.soldOut:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[600]!;
        break;
      case ProductStatus.hidden:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[600]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  /// 메시지 영역
  Widget _buildMessageArea(
    BuildContext context,
    String? roomId,
    String? currentUserId,
    ImageProvider avatarImage,
    ChatRoom? room,
  ) {
    if (roomId != null && roomId.isNotEmpty) {
      _activeRoomId = roomId;
    }
    return StreamBuilder<MessagePage>(
      stream: roomId == null || roomId.isEmpty
          ? Stream<MessagePage>.empty()
          : context
              .read<ChatService>()
              .watchLatestMessages(roomId, limit: _pageSize),
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
              '메시지를 불러오지 못했어요.',
              style: TextStyle(color: textGrey),
            ),
          );
        }

        final page = snapshot.data;
        final latestMessages = page?.messages ?? [];
        if (_lastMessageDoc == null && page != null) {
          _lastMessageDoc = page.lastDoc;
          _hasMore = page.hasMore;
        }

        final messages = _mergeMessages(latestMessages, _olderMessages);
        final myLastReadAt = _resolveMyLastReadAt(room, currentUserId);
        final otherLastReadAt = _resolveOtherLastReadAt(room, currentUserId);
        final myUnreadCount = _resolveMyUnreadCount(room, currentUserId);
        final isSeller =
            room != null && currentUserId != null && room.sellerId == currentUserId;
        final isBuyer =
            room != null && currentUserId != null && room.buyerId == currentUserId;
        _markLatestAsReadIfNeeded(
          messages: messages,
          currentUserId: currentUserId,
          roomId: roomId,
          lastReadAt: myLastReadAt,
          unreadCount: myUnreadCount,
          isSeller: isSeller,
          isBuyer: isBuyer,
        );

        if (messages.isEmpty) {
          return const Center(
            child: Text(
              '아직 대화가 없습니다.\n메시지를 보내 대화를 시작해보세요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textGrey,
                fontSize: 14,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == currentUserId;
            final isLatestMessage = index == 0;
            final showReadIndicator = isMe &&
                isLatestMessage &&
                otherLastReadAt != null &&
                otherLastReadAt.compareTo(message.createdAt) >= 0;

            // 날짜 구분선 표시 여부 확인
            final showDateSeparator = _shouldShowDateSeparator(
              messages,
              index,
            );

            return Column(
              children: [
                if (showDateSeparator)
                  _buildDateSeparator(message.createdAt.toDate()),
                isMe
                    ? _buildSentMessage(
                        message,
                        showReadIndicator: showReadIndicator,
                      )
                    : _buildReceivedMessage(message, avatarImage),
              ],
            );
          },
        );
      },
    );
  }

  /// 날짜 구분선 표시 여부
  bool _shouldShowDateSeparator(List<ChatMessage> messages, int index) {
    if (index == messages.length - 1) return true;

    final currentDate = messages[index].createdAt.toDate();
    final previousDate = messages[index + 1].createdAt.toDate();

    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }

  /// 날짜 구분선
  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300]?.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatDateSeparator(date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textGrey,
            ),
          ),
        ),
      ),
    );
  }

  /// 받은 메시지 (왼쪽)
  Widget _buildReceivedMessage(ChatMessage message, ImageProvider avatarImage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 프로필 이미지
          Container(
            width: 36,
            height: 36,
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
                  child: const Icon(Icons.person, size: 20, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 메시지 버블
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: textDark,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _formatMessageTime(message.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: textGrey,
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

  /// 보낸 메시지 (오른쪽)
  Widget _buildSentMessage(
    ChatMessage message, {
    required bool showReadIndicator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showReadIndicator)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text(
                            '읽음',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      Text(
                        _formatMessageTime(message.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 입력 영역
  Widget _buildInputArea(ChatRoom room) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      decoration: const BoxDecoration(
        color: surfaceLight,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 첨부 버튼
          IconButton(
            onPressed: () {
              // TODO: 이미지 첨부 기능
            },
            icon: const Icon(
              Icons.add_circle_outline,
              color: textGrey,
              size: 28,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // 텍스트 입력 필드
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _controller,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: TextStyle(
                    color: textGrey,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: textDark,
                ),
                onSubmitted: (_) => _sendMessage(room),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 전송 버튼
          GestureDetector(
            onTap: () => _sendMessage(room),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
