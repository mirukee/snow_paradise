import 'package:cloud_firestore/cloud_firestore.dart';

Timestamp _timestampFrom(dynamic value) {
  if (value is Timestamp) {
    return value;
  }
  if (value is DateTime) {
    return Timestamp.fromDate(value);
  }
  return Timestamp.fromMillisecondsSinceEpoch(0);
}

class ChatRoom {
  final String? roomId;
  final String productId;
  final String sellerId;
  final String buyerId;
  final List<String> participants;
  final String productTitle;
  final String productImageUrl;
  final int productPrice;
  final String sellerName;
  final String buyerName;
  final int unreadCountBuyer;
  final int unreadCountSeller;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final Timestamp lastReadAtBuyer;
  final Timestamp lastReadAtSeller;

  ChatRoom({
    this.roomId,
    required this.productId,
    required this.sellerId,
    required this.buyerId,
    required this.participants,
    required this.productTitle,
    required this.productImageUrl,
    required this.productPrice,
    required this.sellerName,
    required this.buyerName,
    required this.unreadCountBuyer,
    required this.unreadCountSeller,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastReadAtBuyer,
    required this.lastReadAtSeller,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    return ChatRoom(
      roomId: json['roomId']?.toString(),
      productId: json['productId']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? '',
      buyerId: json['buyerId']?.toString() ?? '',
      participants: rawParticipants is Iterable
          ? rawParticipants.map((e) => e.toString()).toList()
          : <String>[],
      productTitle: json['productTitle']?.toString() ?? '',
      productImageUrl: json['productImageUrl']?.toString() ?? '',
      productPrice: json['productPrice'] is num
          ? (json['productPrice'] as num).toInt()
          : int.tryParse(json['productPrice']?.toString() ?? '') ?? 0,
      sellerName: json['sellerName']?.toString() ?? '',
      buyerName: json['buyerName']?.toString() ?? '',
      unreadCountBuyer: json['unreadCountBuyer'] is num
          ? (json['unreadCountBuyer'] as num).toInt()
          : int.tryParse(json['unreadCountBuyer']?.toString() ?? '') ?? 0,
      unreadCountSeller: json['unreadCountSeller'] is num
          ? (json['unreadCountSeller'] as num).toInt()
          : int.tryParse(json['unreadCountSeller']?.toString() ?? '') ?? 0,
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: _timestampFrom(json['lastMessageTime']),
      lastReadAtBuyer: _timestampFrom(json['lastReadAtBuyer']),
      lastReadAtSeller: _timestampFrom(json['lastReadAtSeller']),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'productId': productId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'participants': participants,
      'productTitle': productTitle,
      'productImageUrl': productImageUrl,
      'productPrice': productPrice,
      'sellerName': sellerName,
      'buyerName': buyerName,
      'unreadCountBuyer': unreadCountBuyer,
      'unreadCountSeller': unreadCountSeller,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastReadAtBuyer': lastReadAtBuyer,
      'lastReadAtSeller': lastReadAtSeller,
    };

    if (roomId != null && roomId!.isNotEmpty) {
      data['roomId'] = roomId;
    }

    return data;
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final Timestamp createdAt;
  final bool isRead;

  ChatMessage({
    this.id = '',
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isRead,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? docId,
  }) {
    final rawIsRead = json['isRead'];
    return ChatMessage(
      id: docId ?? json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: _timestampFrom(json['createdAt']),
      isRead: rawIsRead is bool
          ? rawIsRead
          : rawIsRead?.toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'text': text,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }
}

class MessagePage {
  final List<ChatMessage> messages;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  const MessagePage({
    required this.messages,
    required this.lastDoc,
    required this.hasMore,
  });
}
