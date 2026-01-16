import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/chat_model.dart';
import '../models/product.dart';
import '../models/user_model.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../services/chat_service.dart';
import '../services/report_service.dart';
import '../services/user_service.dart' as safety_service;

enum _ChatMenuAction { report, block, leave }

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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 30;
  int _messageLimit = 30;
  bool _isFetchingMore = false;
  bool _hasMore = true;

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

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomId = widget.room.roomId;
      if (roomId == null || roomId.isEmpty) {
        return;
      }
      context.read<ChatService>().markAsRead(roomId);
    });
  }

  @override
  void dispose() {
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
      _isFetchingMore = true;
      setState(() {
        _messageLimit += _pageSize;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        _isFetchingMore = false;
      });
    }
  }

  void _markLatestAsReadIfNeeded({
    required AsyncSnapshot<List<ChatMessage>> snapshot,
    required List<ChatMessage> messages,
    required String? currentUserId,
    required String? roomId,
  }) {
    if (!snapshot.hasData || messages.isEmpty) {
      return;
    }
    if (roomId == null || roomId.isEmpty) {
      return;
    }
    final latestMessage = messages.first;
    final isFromOther = latestMessage.senderId != currentUserId;
    if (!isFromOther || latestMessage.isRead) {
      return;
    }

    // 빌드 도중 상태 변경을 피하기 위해 프레임 이후에 읽음 처리를 수행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatService>().markAsRead(roomId);
    });
  }

  Future<void> _sendMessage() async {
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
      final roomId = widget.room.roomId;
      if (roomId == null || roomId.isEmpty) {
        throw StateError('채팅방 정보를 찾을 수 없습니다.');
      }
      await context.read<ChatService>().sendMessage(roomId, text);
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지 전송에 실패했어요.')),
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

  String _formatMessageTime(Timestamp timestamp) {
    return DateFormat('HH:mm').format(timestamp.toDate());
  }

  String _resolveOtherName(
    String? currentUserId, {
    UserModel? userModel,
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

  ImageProvider _resolveProfileImage(UserModel? userModel) {
    final profileImageUrl = userModel?.profileImageUrl?.trim();
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return NetworkImage(profileImageUrl);
    }
    return const AssetImage('assets/images/user_default.png');
  }

  Widget _buildStatusBadge(BuildContext context, ProductStatus? status) {
    final theme = Theme.of(context);
    final label = status?.label ?? '상태 확인중';
    final Color color;
    if (status == ProductStatus.forSale) {
      color = theme.colorScheme.primary;
    } else if (status == ProductStatus.reserved) {
      color = Colors.green;
    } else if (status == ProductStatus.soldOut) {
      color = Colors.grey;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserService>().currentUser?.uid;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final otherUserId = _resolveOtherUserId(currentUserId);
    final roomId = widget.room.roomId;
    final productService = context.watch<ProductService>();
    final product = productService.getProductById(widget.room.productId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: otherUserId == null || otherUserId.isEmpty
          ? Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
          : FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .snapshots(),
      builder: (context, userSnapshot) {
        final data = userSnapshot.data?.data();
        final otherUser = data == null ? null : UserModel.fromJson(data);
        final otherName =
            _resolveOtherName(currentUserId, userModel: otherUser);
        final avatarImage = _resolveProfileImage(otherUser);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              otherName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            actions: [
              PopupMenuButton<_ChatMenuAction>(
                onSelected: (action) async {
                  final messenger = ScaffoldMessenger.of(context);
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
                    if (reason == null) {
                      return;
                    }
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
                    if (!confirm) {
                      return;
                    }
                    try {
                      await safety_service.UserService().blockUser(
                        currentUid: currentUserId,
                        targetUid: otherUserId,
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
                    return;
                  }

                  if (action == _ChatMenuAction.leave) {
                    final confirm = await _confirmAction(
                      context,
                      title: '채팅방 나가기',
                      message: '이 채팅방을 나가시겠어요?',
                      confirmLabel: '나가기',
                    );
                    if (!confirm) {
                      return;
                    }
                    try {
                      final targetRoomId = roomId ?? '';
                      if (targetRoomId.isEmpty) {
                        throw StateError('채팅방 정보를 찾을 수 없습니다.');
                      }
                      await context
                          .read<ChatService>()
                          .leaveChatRoom(targetRoomId);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('채팅방을 나갔어요.')),
                      );
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('채팅방 나가기에 실패했어요.')),
                      );
                    }
                  }
                },
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
          body: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.room.productImageUrl.isNotEmpty
                          ? Image.network(
                              widget.room.productImageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.room.productTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatPrice(widget.room.productPrice),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(context, product?.status),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: roomId == null || roomId.isEmpty
                      ? Stream<List<ChatMessage>>.empty()
                      : context
                          .read<ChatService>()
                          .getMessages(roomId, limit: _messageLimit),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('메시지를 불러오지 못했어요.'),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    _markLatestAsReadIfNeeded(
                      snapshot: snapshot,
                      messages: messages,
                      currentUserId: currentUserId,
                      roomId: roomId,
                    );
                    _hasMore = messages.length >= _messageLimit;
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          '아직 대화가 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUserId;

                        final timeText =
                            _formatMessageTime(message.createdAt);

                        if (isMe) {
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius:
                                        BorderRadius.circular(12).copyWith(
                                      bottomRight: const Radius.circular(0),
                                    ),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!message.isRead)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin:
                                            const EdgeInsets.only(right: 4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFC107),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Text(
                                      timeText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: avatarImage,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    otherName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius:
                                          BorderRadius.circular(12).copyWith(
                                        bottomLeft: const Radius.circular(0),
                                      ),
                                    ),
                                    child: Text(
                                      message.text,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 8,
                  bottom: 30,
                  top: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: '메시지 보내기',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send, color: primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}