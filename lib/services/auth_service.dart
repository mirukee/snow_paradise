import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  Future<void>? _googleSignInInit;

  Future<User?> signInWithGoogle() async {
    UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      await _ensureGoogleSignInInitialized();
      try {
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final authCredential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(authCredential);
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled ||
            error.code == GoogleSignInExceptionCode.interrupted) {
          return null;
        }
        rethrow;
      }
    }

    final user = credential.user;
    if (user == null) {
      return null;
    }

    await _ensureUserDocument(user);
    return user;
  }

  Future<void> _ensureUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      return;
    }

    final nickname =
        user.displayName ?? user.email?.split('@').first ?? '사용자';
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      nickname: nickname,
      profileImageUrl: null,
      createdAt: DateTime.now(),
    );
    await docRef.set(userModel.toJson());
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize();
  }
}
