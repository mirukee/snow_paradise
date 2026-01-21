import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart' as profile_service;

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    NotificationService? notificationService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    profile_service.UserService? userService,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _notificationService = notificationService ??
            NotificationService(navigatorKey: navigatorKey),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _userService = userService ?? profile_service.UserService() {
    if (navigatorKey != null) {
      _notificationService.updateNavigatorKey(navigatorKey);
    }
    _lastUserId = _auth.currentUser?.uid;
    _authSubscription = _auth.authStateChanges().listen(_handleAuthChanged);
  }

  final NotificationService _notificationService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final profile_service.UserService _userService;

  bool _isInitialized = false;
  NotificationSettings? _permissionSettings;
  String? _fcmToken;
  RemoteMessage? _lastMessage;
  String? _lastUserId;
  
  // 알림 히스토리 리스트
  List<NotificationModel> _notifications = [];
  bool _isLoadingNotifications = false;
  int _unreadCount = 0;
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSubscription;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<User?>? _authSubscription;

  bool get isInitialized => _isInitialized;
  NotificationSettings? get permissionSettings => _permissionSettings;
  String? get fcmToken => _fcmToken;
  RemoteMessage? get lastMessage => _lastMessage;
  
  // 알림 관련 getter
  List<NotificationModel> get notifications => _notifications;
  bool get isLoadingNotifications => _isLoadingNotifications;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

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

    // [개선] 이미 로그인된 사용자가 있다면 FCM 토큰 명시적 동기화
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final token = await _notificationService.getToken();
      await _syncToken(token);
      // 알림 히스토리 구독도 시작
      startListeningNotifications();
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _lastMessage = message;
    
    // Firestore에 알림 저장
    await _saveNotificationToFirestore(message);
    
    notifyListeners();
    _notificationService.showForegroundSnackBar(message);
  }

  void _handleMessageOpened(RemoteMessage message) {
    _lastMessage = message;
    notifyListeners();
    _notificationService.handleMessageNavigation(message);
  }
  
  /// FCM 메시지를 Firestore에 저장
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    // 알림 타입 결정
    NotificationType type = NotificationType.system;
    if (message.data.containsKey('chatId') || message.data.containsKey('roomId')) {
      type = NotificationType.chat;
    } else if (message.data.containsKey('productId') && message.data.containsKey('likeAction')) {
      type = NotificationType.like;
    }
    
    final notification = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      type: type,
      title: message.notification?.title ?? '새 알림',
      body: message.notification?.body ?? '',
      data: message.data,
      createdAt: DateTime.now(),
      isRead: false,
    );
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());
    } catch (e) {
      debugPrint('알림 저장 실패: $e');
    }
  }
  
  /// 알림 히스토리 실시간 구독 시작
  void startListeningNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    _notificationsSubscription?.cancel();
    _isLoadingNotifications = true;
    notifyListeners();
    
    _notificationsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50) // 최근 50개만
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs
          .map((doc) => NotificationModel.fromJson(doc.data(), docId: doc.id))
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _isLoadingNotifications = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('알림 로드 실패: $e');
      _isLoadingNotifications = false;
      notifyListeners();
    });
  }
  
  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('알림 읽음 처리 실패: $e');
    }
  }
  
  /// 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    final unreadNotifications = _notifications.where((n) => !n.isRead).toList();
    if (unreadNotifications.isEmpty) return;
    
    final batch = _firestore.batch();
    for (final notification in unreadNotifications) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id);
      batch.update(ref, {'isRead': true});
    }
    
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('전체 읽음 처리 실패: $e');
    }
  }
  
  /// 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('알림 삭제 실패: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    if (_notifications.isEmpty) return;

    final chunks = _splitIntoChunks(_notifications, 450);
    for (final chunk in chunks) {
      final batch = _firestore.batch();
      for (final notification in chunk) {
        final ref = _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notification.id);
        batch.delete(ref);
      }

      try {
        await batch.commit();
      } catch (e) {
        debugPrint('전체 알림 삭제 실패: $e');
      }
    }
  }

  List<List<T>> _splitIntoChunks<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.skip(i).take(chunkSize).toList());
    }
    return chunks;
  }

  Future<void> _syncToken(String? token) async {
    if (token == null || token.isEmpty) {
      debugPrint('FCM token is null/empty; skip Firestore sync.');
      return;
    }
    debugPrint('현재 FCM token: $token');
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
      _notificationsSubscription?.cancel();
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    _lastUserId = user.uid;

    final token = await _notificationService.getToken();
    await _syncToken(token);
    
    // 로그인 시 알림 구독 시작
    startListeningNotifications();
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _authSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
