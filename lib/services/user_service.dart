import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_model.dart';
import '../utils/storage_uploader.dart';

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
    File? imageFile,
  ) async {
    if (uid.isEmpty) {
      return null;
    }

    final trimmedNickname = nickname.trim();
    String? profileImageUrl;
    if (imageFile != null) {
      final ref = _storage.ref().child('user_profiles/$uid');
      await uploadFileFromPath(ref, imageFile.path);
      profileImageUrl = await ref.getDownloadURL();
    }

    final updateData = <String, dynamic>{
      'nickname': trimmedNickname,
    };
    if (profileImageUrl != null) {
      updateData['profileImageUrl'] = profileImageUrl;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));

    return getUser(uid);
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
}
