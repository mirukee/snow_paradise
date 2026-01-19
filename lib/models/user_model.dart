import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final List<String> styleTags; // 스타일 태그
  final String bio; // 한 줄 소개
  final DateTime createdAt;

  final bool isAdmin; // 관리자 여부
  final bool isBanned; // 정지 여부 (관리자에 의한 제재)

  const UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    this.styleTags = const [],
    this.bio = '',
    required this.createdAt,
    this.isAdmin = false,
    this.isBanned = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'styleTags': styleTags,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAdmin': isAdmin,
      'isBanned': isBanned,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAt'];
    DateTime createdAt;
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is String) {
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    } else if (createdAtValue is num) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue.toInt());
    } else {
      createdAt = DateTime.now();
    }

    final profileImageValue = json['profileImageUrl']?.toString();
    final normalizedProfileImage =
        (profileImageValue == null || profileImageValue.isEmpty)
            ? null
            : profileImageValue;

    return UserModel(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      profileImageUrl: normalizedProfileImage,
      styleTags: (json['styleTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      bio: json['bio']?.toString() ?? '',
      createdAt: createdAt,
      isAdmin: json['isAdmin'] == true,
      isBanned: json['isBanned'] == true,
    );
  }
}
