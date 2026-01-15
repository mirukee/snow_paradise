import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/user_service.dart' as profile_service;

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    FirebaseAuth? auth,
    profile_service.UserService? userService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userService = userService ?? profile_service.UserService();

  final FirebaseAuth _auth;
  final profile_service.UserService _userService;

  UserModel? _user;
  bool _isLoading = false;
  bool _isSaving = false;
  File? _selectedImage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  File? get selectedImage => _selectedImage;

  Future<void> loadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _user = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    _user = await _userService.getUser(uid);
    _isLoading = false;
    notifyListeners();
  }

  void selectImage(File? file) {
    _selectedImage = file;
    notifyListeners();
  }

  Future<bool> saveProfile(String nickname) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return false;
    }

    _isSaving = true;
    notifyListeners();
    final updatedUser =
        await _userService.updateProfile(uid, nickname, _selectedImage);
    if (updatedUser != null) {
      _user = updatedUser;
    }
    _selectedImage = null;
    _isSaving = false;
    notifyListeners();
    return updatedUser != null;
  }
}
