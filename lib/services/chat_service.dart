import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

    QuerySnapshot<Map<String, dynamic>> querySnapshot;
    try {
      querySnapshot = await _firestore
          .collection('chat_rooms')
          .where('productId', isEqualTo: productId)
          .where('participants', arrayContains: buyerId)
          .limit(10)
          .get();
    } catch (error, stackTrace) {
      debugPrint('채팅방 조회 실패: $error');
      debugPrint('$stackTrace');
      rethrow;
    }

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
      'lastReadAtBuyer': Timestamp.now(),
      'lastReadAtSeller': Timestamp.fromMillisecondsSinceEpoch(0),
      'isFirstMessageSent': false, // 첫 메시지 전송 시 true로 변경되며 chatCount 증가
    };
    try {
      final roomDoc = await _firestore.collection('chat_rooms').add(roomData);
      // chatCount 증가는 sendMessage에서 첫 메시지 전송 시 처리됨
      return ChatRoom.fromJson({
        ...roomData,
        'roomId': roomDoc.id,
      });
    } catch (error, stackTrace) {
      debugPrint('채팅방 생성 실패: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Stream<List<ChatRoom>> getChatRooms({int? limit}) {
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
      Query<Map<String, dynamic>> query = _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true);
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }
      roomsSubscription = query.snapshots().listen((snapshot) {
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
    return _firestore.collection('users').doc(user.uid).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        final rawTotal = data?['unreadTotal'];
        if (rawTotal is num) {
          return rawTotal.toInt();
        }
        return int.tryParse(rawTotal?.toString() ?? '') ?? 0;
      },
    );
  }

  Stream<MessagePage> watchLatestMessages(
    String roomId, {
    int limit = 30,
  }) {
    final query = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.data(), docId: doc.id))
          .toList();
      final lastDoc =
          snapshot.docs.isEmpty ? null : snapshot.docs.last;
      return MessagePage(
        messages: messages,
        lastDoc: lastDoc,
        hasMore: snapshot.docs.length >= limit,
      );
    });
  }

  Future<MessagePage> getMessagesPage(
    String roomId, {
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    final messages = snapshot.docs
        .map((doc) => ChatMessage.fromJson(doc.data(), docId: doc.id))
        .toList();
    final nextDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    return MessagePage(
      messages: messages,
      lastDoc: nextDoc,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  Future<ChatRoom?> getChatRoomById(String roomId) async {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      return null;
    }

    final snapshot =
        await _firestore.collection('chat_rooms').doc(trimmedRoomId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    final participantsRaw = data['participants'];
    final participants = participantsRaw is Iterable
        ? participantsRaw.map((e) => e.toString()).toSet()
        : <String>{};
    final sellerId = data['sellerId']?.toString() ?? '';
    final buyerId = data['buyerId']?.toString() ?? '';
    final isParticipant = participants.contains(userId) ||
        sellerId == userId ||
        buyerId == userId;
    if (!isParticipant) {
      return null;
    }

    return ChatRoom.fromJson({
      ...data,
      'roomId': snapshot.id,
    });
  }

  Stream<ChatRoom?> watchChatRoom(String roomId) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('chat_rooms')
        .doc(trimmedRoomId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return ChatRoom.fromJson({
        ...data,
        'roomId': snapshot.id,
      });
    });
  }

  Future<void> sendMessage(ChatRoom room, String text) async {
    final userId = _requireUser().uid;
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final roomId = room.roomId?.trim() ?? '';
    if (roomId.isEmpty) {
      return;
    }

    final now = Timestamp.now();
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final isSeller = room.sellerId == userId;
    final isBuyer = room.buyerId == userId;
    if (!isSeller && !isBuyer) {
      return;
    }

    String? targetUnreadField;
    if (isSeller) {
      targetUnreadField = 'unreadCountBuyer';
    } else if (isBuyer) {
      targetUnreadField = 'unreadCountSeller';
    }
    String? senderLastReadField;
    if (isSeller) {
      senderLastReadField = 'lastReadAtSeller';
    } else if (isBuyer) {
      senderLastReadField = 'lastReadAtBuyer';
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
    if (senderLastReadField != null) {
      updates[senderLastReadField] = now;
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

  Future<void> markAsRead(
    String roomId, {
    required bool isSeller,
    required bool isBuyer,
  }) async {
    _requireUser();
    if (!isSeller && !isBuyer) {
      return;
    }
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final now = Timestamp.now();
    final updates = <String, dynamic>{};
    if (isSeller) {
      updates['unreadCountSeller'] = 0;
      updates['lastReadAtSeller'] = now;
    }
    if (isBuyer) {
      updates['unreadCountBuyer'] = 0;
      updates['lastReadAtBuyer'] = now;
    }
    if (updates.isNotEmpty) {
      await roomRef.update(updates);
    }
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
