import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; 
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';


class UserService {
  UserService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Future<UserModel?> getUser(String uid) async {
    if (uid.isEmpty) {
      return null;
    }
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return UserModel.fromJson(data);
  }

  Future<UserModel?> updateProfile(
    String uid,
    String nickname,
    XFile? imageFile, {
    Uint8List? imageBytes, // 압축된 이미지 바이트 선택적 전달
    List<String>? styleTags,
    String? bio,
    bool deleteImage = false,
  }) async {
    if (uid.isEmpty) {
      return null;
    }

    final trimmedNickname = nickname.trim();
    String? profileImageUrl;
    if (imageFile != null) {
      final ref = _storage.ref().child('user_profiles/$uid');
      
      final Uint8List dataToUpload;
      if (imageBytes != null) {
        dataToUpload = imageBytes;
      } else {
        // 바이트가 전달되지 않았으면 직접 변환 (혹은 ImageCompressor 사용 가능하지만 의존성 최소화)
        dataToUpload = await imageFile.readAsBytes();
      }
      
      // 메타데이터 제거 (HEIC 등 다양한 포맷 지원)
      await ref.putData(dataToUpload); 
      profileImageUrl = await ref.getDownloadURL();
    }

    final updateData = <String, dynamic>{
      'nickname': trimmedNickname,
    };
    
    if (deleteImage) {
      updateData['profileImageUrl'] = null; // 이미지 삭제
    } else if (profileImageUrl != null) {
      updateData['profileImageUrl'] = profileImageUrl;
    }
    
    if (styleTags != null) {
      updateData['styleTags'] = styleTags;
    }
    if (bio != null) {
      updateData['bio'] = bio.trim();
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));

    return getUser(uid);
  }

  /// FCM 토큰 저장 (멀티 디바이스 지원 - 최대 2개 토큰 유지)
  static const int _maxFcmTokens = 2;

  Future<void> updateFcmToken({
    required String uid,
    required String token,
  }) async {
    final trimmedUid = uid.trim();
    final trimmedToken = token.trim();
    if (trimmedUid.isEmpty || trimmedToken.isEmpty) {
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(trimmedUid).get();
      final existingData = userDoc.data() ?? {};
      final existingTokens = List<String>.from(existingData['fcmTokens'] ?? []);

      // 이미 존재하는 토큰이면 맨 뒤로 이동 (최신으로 갱신)
      if (existingTokens.contains(trimmedToken)) {
        existingTokens.remove(trimmedToken);
      }
      existingTokens.add(trimmedToken);

      // 최대 3개 초과 시 가장 오래된 토큰 제거
      while (existingTokens.length > _maxFcmTokens) {
        existingTokens.removeAt(0);
      }

      await _firestore.collection('users').doc(trimmedUid).set({
        'fcmTokens': existingTokens,
        'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM token saved for uid=$trimmedUid (total: ${existingTokens.length})');
    } catch (error) {
      debugPrint('Failed to save FCM token for uid=$trimmedUid: $error');
      rethrow;
    }
  }

  Future<void> removeFcmToken({
    required String uid,
    required String token,
  }) async {
    final trimmedUid = uid.trim();
    final trimmedToken = token.trim();
    if (trimmedUid.isEmpty || trimmedToken.isEmpty) {
      return;
    }

    await _firestore.collection('users').doc(trimmedUid).set({
      'fcmTokens': FieldValue.arrayRemove([trimmedToken]),
      'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> blockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    final trimmedCurrentUid = currentUid.trim();
    final trimmedTargetUid = targetUid.trim();
    if (trimmedCurrentUid.isEmpty || trimmedTargetUid.isEmpty) {
      throw StateError('차단할 사용자를 찾을 수 없습니다.');
    }
    if (trimmedCurrentUid == trimmedTargetUid) {
      throw StateError('자기 자신은 차단할 수 없습니다.');
    }

    await _firestore
        .collection('users')
        .doc(trimmedCurrentUid)
        .collection('blocked_users')
        .doc(trimmedTargetUid)
        .set({
      'targetUid': trimmedTargetUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    final trimmedCurrentUid = currentUid.trim();
    final trimmedTargetUid = targetUid.trim();

    if (trimmedCurrentUid.isEmpty || trimmedTargetUid.isEmpty) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(trimmedCurrentUid)
        .collection('blocked_users')
        .doc(trimmedTargetUid)
        .delete();
  }

  Stream<Set<String>> blockedUserIdsStream(String uid) {
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

  Future<Set<String>> getBlockedUserIds(String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return <String>{};
    }
    final snapshot = await _firestore
        .collection('users')
        .doc(trimmedUid)
        .collection('blocked_users')
        .get();
    return snapshot.docs
        .map((doc) => doc.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> deleteAccount({
    AuthCredential? credential,
    bool deleteProducts = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    if (credential != null) {
      await user.reauthenticateWithCredential(credential);
    }

    final uid = user.uid.trim();
    if (uid.isEmpty) {
      throw StateError('회원 정보를 찾을 수 없습니다.');
    }

    await _firestore.collection('users').doc(uid).delete();

    if (deleteProducts) {
      await _deleteProductsBySeller(uid);
    }

    await user.delete();
  }

  Future<void> _deleteProductsBySeller(String uid) async {
    final snapshot = await _firestore
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    var batch = _firestore.batch();
    var pending = 0;

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      pending += 1;
      if (pending >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        pending = 0;
      }
    }

    if (pending > 0) {
      await batch.commit();
    }
  }
  Future<List<UserModel>> getAllUsers({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    // 관리자 기능: 모든 사용자 목록 조회
    // 실제로는 isAdmin 체크를 여기서도 한번 더 하는게 좋지만,
    // Firestore Security Rules에서 막는 것이 원칙입니다.
    var query = _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList();
  }

  Future<void> updateUserBanStatus(String uid, bool isBanned) async {
    // 관리자 기능: 사용자 정지 또는 정지 해제
    // Security Rules에서 관리자만 쓰기가능하도록 설정 필요
    if (uid.isEmpty) return;

    await _firestore.collection('users').doc(uid).set({
      'isBanned': isBanned,
    }, SetOptions(merge: true));
  }
}
