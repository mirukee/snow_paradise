import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
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
      createdAt: createdAt,
    );
  }
}
