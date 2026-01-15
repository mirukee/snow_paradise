import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user;
  }

  Future<ChatRoom> getOrCreateChatRoom(
    String productId,
    String sellerId,
    String productTitle,
    String productImageUrl,
    int productPrice,
    String sellerName,
  ) async {
    final user = _requireUser();
    final buyerId = user.uid;
    final buyerName = user.displayName ?? user.email ?? '게스트';

    final querySnapshot = await _firestore
        .collection('chat_rooms')
        .where('productId', isEqualTo: productId)
        .where('participants', arrayContains: buyerId)
        .limit(10)
        .get();

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      if (data['sellerId']?.toString() == sellerId &&
          data['buyerId']?.toString() == buyerId) {
        final updates = <String, dynamic>{
          'productTitle': productTitle,
          'productImageUrl': productImageUrl,
          'productPrice': productPrice,
          'sellerName': sellerName,
          'buyerName': buyerName,
        };
        try {
          await doc.reference.update(updates);
        } catch (_) {
          // 업데이트 실패 시에도 채팅방 진입은 가능해야 합니다.
        }
        return ChatRoom.fromJson({
          ...data,
          ...updates,
          'roomId': doc.id,
        });
      }
    }

    final participants = <String>{buyerId, sellerId}.toList();
    final roomData = <String, dynamic>{
      'productId': productId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'participants': participants,
      'productTitle': productTitle,
      'productImageUrl': productImageUrl,
      'productPrice': productPrice,
      'sellerName': sellerName,
      'buyerName': buyerName,
      'unreadCountBuyer': 0,
      'unreadCountSeller': 0,
      'lastMessage': '',
      'lastMessageTime': Timestamp.now(),
    };
    final roomDoc = await _firestore.collection('chat_rooms').add(roomData);
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('id', isEqualTo: productId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'chatCount': FieldValue.increment(1),
        });
      }
    } catch (_) {
      // 채팅방 생성이 우선이므로 카운트 업데이트 실패는 무시합니다.
    }

    return ChatRoom.fromJson({
      ...roomData,
      'roomId': roomDoc.id,
    });
  }

  Stream<List<ChatRoom>> getChatRooms() {
    final userId = _requireUser().uid;
    final controller = StreamController<List<ChatRoom>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomsSubscription;
    StreamSubscription<Set<String>>? blockedSubscription;
    var latestRooms = <ChatRoom>[];
    var blockedUsers = <String>{};

    void emit() {
      if (controller.isClosed) {
        return;
      }
      final filteredRooms = latestRooms
          .where((room) {
            final otherUserId =
                room.sellerId == userId ? room.buyerId : room.sellerId;
            if (otherUserId.isEmpty) {
              return true;
            }
            return !blockedUsers.contains(otherUserId);
          })
          .toList()
        ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      controller.add(filteredRooms);
    }

    controller.onListen = () {
      roomsSubscription = _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: userId)
          .snapshots()
          .listen((snapshot) {
        latestRooms = snapshot.docs.map((doc) {
          final data = doc.data();
          return ChatRoom.fromJson({
            ...data,
            'roomId': doc.id,
          });
        }).toList();
        emit();
      }, onError: controller.addError);

      blockedSubscription = _blockedUsersStream(userId).listen((ids) {
        blockedUsers = ids;
        emit();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await roomsSubscription?.cancel();
      await blockedSubscription?.cancel();
    };

    return controller.stream;
  }

  Stream<int> getTotalUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    final userId = user.uid;
    return getChatRooms().map((rooms) {
      var total = 0;
      for (final room in rooms) {
        final isSeller = room.sellerId == userId;
        total += isSeller ? room.unreadCountSeller : room.unreadCountBuyer;
      }
      return total;
    });
  }

  Stream<List<ChatMessage>> getMessages(
    String roomId, {
    int limit = 30,
  }) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromJson(doc.data());
      }).toList();
    });
  }

  Future<void> sendMessage(String roomId, String text) async {
    final userId = _requireUser().uid;
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final now = Timestamp.now();
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data() ?? {};
    final sellerId = roomData['sellerId']?.toString();
    final buyerId = roomData['buyerId']?.toString();
    final isSeller = sellerId == userId;
    final isBuyer = buyerId == userId;

    String? targetUnreadField;
    if (isSeller) {
      targetUnreadField = 'unreadCountBuyer';
    } else if (isBuyer) {
      targetUnreadField = 'unreadCountSeller';
    }

    final messageRef = roomRef.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': userId,
      'text': trimmedText,
      'createdAt': now,
      'isRead': false,
    });

    final updates = <String, dynamic>{
      'lastMessage': trimmedText,
      'lastMessageTime': now,
    };
    if (targetUnreadField != null) {
      updates[targetUnreadField] = FieldValue.increment(1);
    }
    batch.update(roomRef, updates);
    await batch.commit();
  }

  Future<void> leaveChatRoom(String roomId) async {
    final userId = _requireUser().uid;
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      throw StateError('채팅방 정보를 찾을 수 없습니다.');
    }

    await _firestore.collection('chat_rooms').doc(trimmedRoomId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> markAsRead(String roomId) async {
    final userId = _requireUser().uid;
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data();
    if (roomData == null) {
      return;
    }

    final sellerId = roomData['sellerId']?.toString();
    final buyerId = roomData['buyerId']?.toString();
    String? unreadField;
    if (sellerId == userId) {
      unreadField = 'unreadCountSeller';
    } else if (buyerId == userId) {
      unreadField = 'unreadCountBuyer';
    }

    final updates = <String, dynamic>{};
    if (unreadField != null) {
      updates[unreadField] = 0;
    }
    if (updates.isNotEmpty) {
      await roomRef.update(updates);
    }

    final unreadSnapshot = await roomRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadSnapshot.docs.isEmpty) {
      return;
    }

    var batch = _firestore.batch();
    var pending = 0;
    Future<void> commitBatch() async {
      if (pending == 0) {
        return;
      }
      await batch.commit();
      batch = _firestore.batch();
      pending = 0;
    }

    for (final doc in unreadSnapshot.docs) {
      final senderId = doc.data()['senderId']?.toString();
      if (senderId == null || senderId == userId) {
        continue;
      }
      batch.update(doc.reference, {'isRead': true});
      pending += 1;
      if (pending >= 450) {
        await commitBatch();
      }
    }
    await commitBatch();
  }

  Stream<Set<String>> _blockedUsersStream(String uid) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return Stream.value(<String>{});
    }
    return _firestore
        .collection('users')
        .doc(trimmedUid)
        .collection('blocked_users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    });
  }
}
