import 'package:cloud_firestore/cloud_firestore.dart';

/// 알림 타입
enum NotificationType {
  chat,      // 채팅 메시지
  like,      // 찜하기
  system,    // 시스템 알림
  marketing, // 마케팅 알림
}

/// 알림 모델
class NotificationModel {
  final String id;
  final String userId;        // 알림 수신자 UID
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data; // 추가 데이터 (chatId, productId 등)
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
  });

  /// Firestore 문서에서 생성
  factory NotificationModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final typeStr = json['type'] as String? ?? 'system';
    NotificationType type;
    switch (typeStr) {
      case 'chat':
        type = NotificationType.chat;
        break;
      case 'like':
        type = NotificationType.like;
        break;
      case 'marketing':
        type = NotificationType.marketing;
        break;
      default:
        type = NotificationType.system;
    }

    DateTime createdAt;
    final createdAtField = json['createdAt'];
    if (createdAtField is Timestamp) {
      createdAt = createdAtField.toDate();
    } else if (createdAtField is DateTime) {
      createdAt = createdAtField;
    } else {
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: docId ?? json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: type,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      createdAt: createdAt,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Firestore에 저장할 Map 생성
  Map<String, dynamic> toJson() {
    String typeStr;
    switch (type) {
      case NotificationType.chat:
        typeStr = 'chat';
        break;
      case NotificationType.like:
        typeStr = 'like';
        break;
      case NotificationType.marketing:
        typeStr = 'marketing';
        break;
      case NotificationType.system:
        typeStr = 'system';
        break;
    }

    return {
      'id': id,
      'userId': userId,
      'type': typeStr,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  /// 읽음 처리된 복사본 생성
  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      data: data,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
