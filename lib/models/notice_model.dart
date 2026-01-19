import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  const NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NoticeModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final createdAtValue = json['createdAt'];
    DateTime createdAt;
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return NoticeModel(
      id: id ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}
