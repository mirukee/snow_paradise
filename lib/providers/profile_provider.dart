import 'package:image_picker/image_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/user_service.dart' as profile_service;
import '../utils/image_compressor.dart';

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
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isDefaultImage = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  XFile? get selectedImage => _selectedImage;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  bool get isDefaultImage => _isDefaultImage;

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

  Future<void> selectImage(XFile? file) async {
    _selectedImage = file;
    _isDefaultImage = false; // 새 이미지 선택 시 기본 이미지가 아님
    if (file != null) {
      // 이미지 압축 및 JPEG 변환 (HEIC 지원)
      _selectedImageBytes = await ImageCompressor.compressImage(file);
    } else {
      _selectedImageBytes = null;
    }
    notifyListeners();
  }

  void setDefaultImage() {
    _selectedImage = null;
    _selectedImageBytes = null;
    _isDefaultImage = true; // 기본 이미지로 설정
    notifyListeners();
  }

  Future<bool> saveProfile({
    required String nickname,
    List<String>? styleTags,
    String? bio,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return false;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final updatedUser = await _userService.updateProfile(
        uid,
        nickname,
        _selectedImage,
        imageBytes: _selectedImageBytes,
        styleTags: styleTags,
        bio: bio,
        deleteImage: _isDefaultImage, // 기본 이미지 상태면 삭제 요청
      );
      
      if (updatedUser != null) {
        _user = updatedUser;
        _selectedImage = null;
        _selectedImageBytes = null;
        _isDefaultImage = false;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Profile update failed: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
