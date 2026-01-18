import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../models/product.dart';
import '../models/user_model.dart';
import '../providers/product_service.dart';
import '../providers/user_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
      return '${difference.inDays}일 전';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}.$month.$day';
  }

  String _resolveOtherName(
    ChatRoom room,
    String? currentUserId, {
    UserModel? userModel,
  }) {
    final nickname = userModel?.nickname.trim();
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

  ImageProvider _resolveProfileImage(UserModel? userModel) {
    final profileImageUrl = userModel?.profileImageUrl?.trim();
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return NetworkImage(profileImageUrl);
    }
    return const AssetImage('assets/images/user_default.png');
  }

  Widget _buildUnreadBadge(int count) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    final displayCount = count > 99 ? '99+' : count.toString();
    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.red,
      child: Text(
        displayCount,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserService>().currentUser;
    final currentUserId = currentUser?.uid;
    final chatService = context.read<ChatService>();
    final productService = context.watch<ProductService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '채팅',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: currentUser == null
          ? const Center(
              child: Text(
                '채팅을 보려면 로그인이 필요합니다.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : StreamBuilder<List<ChatRoom>>(
              stream: chatService.getChatRooms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('채팅 목록을 불러오지 못했어요.'),
                  );
                }

                final rooms = snapshot.data ?? [];
                if (rooms.isEmpty) {
                  return const Center(
                    child: Text(
                      '아직 시작한 채팅이 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final lastMessage = room.lastMessage.isEmpty
                        ? '대화를 시작해 보세요.'
                        : room.lastMessage;
                    final roomId = room.roomId ?? '';
                    final isSeller =
                        currentUserId != null && room.sellerId == currentUserId;
                    final unreadCount = isSeller
                        ? room.unreadCountSeller
                        : room.unreadCountBuyer;
                    final otherUserId = _resolveOtherUserId(room, currentUserId);
                    final product = productService.getProductById(room.productId);
                    final isHiddenForViewer =
                        product?.status == ProductStatus.hidden &&
                            currentUserId != null &&
                            room.sellerId != currentUserId;

                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: otherUserId == null || otherUserId.isEmpty
                          ? Stream<
                                  DocumentSnapshot<Map<String, dynamic>>>.empty()
                          : FirebaseFirestore.instance
                              .collection('users')
                              .doc(otherUserId)
                              .snapshots(),
                      builder: (context, userSnapshot) {
                        final data = userSnapshot.data?.data();
                        final userModel =
                            data == null ? null : UserModel.fromJson(data);
                        final otherName = _resolveOtherName(
                          room,
                          currentUserId,
                          userModel: userModel,
                        );
                        final avatarImage = _resolveProfileImage(userModel);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: avatarImage,
                          ),
                          title: Text(
                            otherName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatLastTime(room.lastMessageTime),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildUnreadBadge(unreadCount),
                                ],
                              ),
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: isHiddenForViewer
                                    ? Container(
                                        width: 50,
                                        height: 50,
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
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                              ),
                            ],
                          ),
                          onTap: roomId.isEmpty
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        room: room,
                                      ),
                                    ),
                                  );
                                },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
