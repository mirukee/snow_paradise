import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AdminAuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> login(String password) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      _errorMessage = '비밀번호를 입력해주세요.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _errorMessage = '관리자 계정으로 먼저 로그인해주세요.';
        return false;
      }

      final callable = _functions.httpsCallable('verifyAdminPassword');
      final result = await callable.call({'password': trimmed});
      final data = result.data;
      final success = data is Map && data['success'] == true;
      if (!success) {
        _errorMessage = '비밀번호가 올바르지 않습니다.';
        return false;
      }

      await user.getIdToken(true);
      _isLoggedIn = true;
      notifyListeners();
      return true;
    } on FirebaseFunctionsException catch (error) {
      _errorMessage = _resolveFunctionErrorMessage(error);
      debugPrint('Admin login error: ${error.code} ${error.message}');
      return false;
    } catch (error) {
      _errorMessage = '관리자 로그인에 실패했습니다.';
      debugPrint('Admin login error: $error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _isLoggedIn = false;
    _errorMessage = null;
    notifyListeners();
  }

  String _resolveFunctionErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return '관리자 계정으로 먼저 로그인해주세요.';
      case 'permission-denied':
        return '비밀번호가 올바르지 않습니다.';
      case 'not-found':
        return '관리자 설정을 찾을 수 없습니다.';
      case 'invalid-argument':
        return '비밀번호를 확인해주세요.';
      default:
        return '관리자 로그인에 실패했습니다.';
    }
  }
}
