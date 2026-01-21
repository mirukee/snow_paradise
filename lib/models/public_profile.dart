class PublicProfile {
  final String uid;
  final String nickname;
  final String? profileImageUrl;

  const PublicProfile({
    required this.uid,
    required this.nickname,
    this.profileImageUrl,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json, {String? docId}) {
    final rawProfileImage = json['profileImageUrl']?.toString().trim();
    final resolvedProfileImage =
        rawProfileImage == null || rawProfileImage.isEmpty
            ? null
            : rawProfileImage;
    return PublicProfile(
      uid: json['uid']?.toString().trim().isNotEmpty == true
          ? json['uid'].toString().trim()
          : (docId ?? ''),
      nickname: json['nickname']?.toString() ?? '',
      profileImageUrl: resolvedProfileImage,
    );
  }
}
