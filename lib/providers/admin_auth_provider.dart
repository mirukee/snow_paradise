import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AdminAuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> login(String password) async {
    if (password.isEmpty) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('admin').doc('settings').get();
      
      if (!doc.exists) {
        // If doc doesn't exist, we might want to handle it (e.g., auto-create or fail)
        // For security, if it doesn't exist, we can't log in.
        // Or for MVP, if it doesn't exist, maybe allow default or fail?
        // User said they will set it up. So we assume it exists or fail.
        debugPrint('Admin settings document not found.');
        return false;
      }

      final correctPassword = doc.data()?['password'] as String?;
      
      if (correctPassword == password) {
        _isLoggedIn = true;
        notifyListeners();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Admin login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
