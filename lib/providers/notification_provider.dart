import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/user_service.dart' as profile_service;

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    NotificationService? notificationService,
    FirebaseAuth? auth,
    profile_service.UserService? userService,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _notificationService = notificationService ??
            NotificationService(navigatorKey: navigatorKey),
        _auth = auth ?? FirebaseAuth.instance,
        _userService = userService ?? profile_service.UserService() {
    if (navigatorKey != null) {
      _notificationService.updateNavigatorKey(navigatorKey);
    }
    _lastUserId = _auth.currentUser?.uid;
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChanged);
  }

  final NotificationService _notificationService;
  final FirebaseAuth _auth;
  final profile_service.UserService _userService;

  bool _isInitialized = false;
  NotificationSettings? _permissionSettings;
  String? _fcmToken;
  RemoteMessage? _lastMessage;
  String? _lastUserId;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<User?>? _authSubscription;

  bool get isInitialized => _isInitialized;
  NotificationSettings? get permissionSettings => _permissionSettings;
  String? get fcmToken => _fcmToken;
  RemoteMessage? get lastMessage => _lastMessage;

  bool get _isFcmSupportedPlatform {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (!_isFcmSupportedPlatform) {
      // 데스크톱 등 미지원 플랫폼에서는 초기화를 건너뜁니다.
      _isInitialized = true;
      notifyListeners();
      return;
    }

    await _notificationService.initializeLocalNotifications();
    await _notificationService.setForegroundPresentationOptions();
    _permissionSettings = await _notificationService.requestPermission();
    notifyListeners();

    _foregroundMessageSubscription =
        _notificationService.onMessage.listen(_handleForegroundMessage);
    _messageOpenedSubscription =
        _notificationService.onMessageOpenedApp.listen(_handleMessageOpened);

    final initialMessage = await _notificationService.getInitialMessage();
    if (initialMessage != null) {
      _lastMessage = initialMessage;
      _notificationService.handleMessageNavigation(initialMessage);
    }

    _tokenRefreshSubscription =
        _notificationService.onTokenRefresh.listen(_syncToken);

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _lastMessage = message;
    notifyListeners();
    _notificationService.showForegroundSnackBar(message);
    await _notificationService.showForegroundNotification(message);
  }

  void _handleMessageOpened(RemoteMessage message) {
    _lastMessage = message;
    notifyListeners();
    _notificationService.handleMessageNavigation(message);
  }

  Future<void> _syncToken(String? token) async {
    if (token == null || token.isEmpty) {
      debugPrint('FCM token is null/empty; skip Firestore sync.');
      return;
    }
    _fcmToken = token;
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No signed-in user; skip FCM token sync.');
      return;
    }

    debugPrint('Sync FCM token for uid=${user.uid}.');
    await _userService.updateFcmToken(uid: user.uid, token: token);
  }

  Future<void> _handleAuthChanged(User? user) async {
    debugPrint('Auth state changed. uid=${user?.uid ?? "null"}');
    final previousUid = _lastUserId;
    if (user == null) {
      if (previousUid != null && _fcmToken != null) {
        await _userService.removeFcmToken(
          uid: previousUid,
          token: _fcmToken!,
        );
      }
      _lastUserId = null;
      return;
    }

    _lastUserId = user.uid;

    final token = await _notificationService.getToken();
    await _syncToken(token);
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
