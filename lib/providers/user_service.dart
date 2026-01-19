import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart' as profile_service;
import '../models/user_model.dart';

class UserService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  late final AuthService _authService;
  late final profile_service.UserService _profileService;
  User? _currentUser;
  Future<void>? _googleSignInInit;

  UserService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    AuthService? authService,
    profile_service.UserService? profileService,
  })
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance {
    _authService =
        authService ?? AuthService(auth: _auth, googleSignIn: _googleSignIn);
    _profileService =
        profileService ?? profile_service.UserService(auth: _auth);
    _currentUser = _auth.currentUser;
  }

  User? get currentUser => _currentUser;

  Future<User?> loginWithGoogle() async {
    _currentUser = await _authService.signInWithGoogle();
    notifyListeners();
    return _currentUser;
  }

  Future<User?> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    _currentUser = credential.user;
    notifyListeners();
    return _currentUser;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize();
  }

  Future<void> deleteAccount() async {
    final user = _currentUser ?? _auth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _profileService.deleteAccount();
    _currentUser = null;
    notifyListeners();
  }

  // --- Admin Methods ---

  Future<List<UserModel>> getAllUsers() async {
    return _profileService.getAllUsers();
  }

  Future<void> updateUserBanStatus(String uid, bool isBanned) async {
    await _profileService.updateUserBanStatus(uid, isBanned);
    notifyListeners();
  }

  Future<void> blockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    await _profileService.blockUser(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    notifyListeners();
  }

  Future<void> unblockUser({
    required String currentUid,
    required String targetUid,
  }) async {
    await _profileService.unblockUser(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    notifyListeners();
  }

  Future<Set<String>> getBlockedUserIds(String uid) async {
    return _profileService.getBlockedUserIds(uid);
  }
}
