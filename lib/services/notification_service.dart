import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../screens/chat_detail_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드/종료 상태에서 메시지를 받을 때 Firebase 초기화가 필요합니다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _navigatorKey = navigatorKey;

  static const String defaultChannelId = 'snow_paradise_default';
  static const String defaultChannelName = '기본 알림';
  static const String defaultChannelDescription = 'Snow Paradise 기본 알림 채널';

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  GlobalKey<NavigatorState>? _navigatorKey;

  bool _localNotificationsReady = false;
  OverlayEntry? _foregroundEntry;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void updateNavigatorKey(GlobalKey<NavigatorState>? navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (_isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    return settings;
  }

  Future<void> setForegroundPresentationOptions() async {
    if (kIsWeb) {
      return;
    }
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> initializeLocalNotifications() async {
    if (kIsWeb || _localNotificationsReady) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    if (_isAndroid) {
      const channel = AndroidNotificationChannel(
        defaultChannelId,
        defaultChannelName,
        description: defaultChannelDescription,
        importance: Importance.high,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
    }

    _localNotificationsReady = true;
  }

  Future<String?> getToken({String? vapidKey}) async {
    if (kIsWeb && (vapidKey == null || vapidKey.isEmpty)) {
      // Web은 VAPID 키가 없으면 토큰을 받을 수 없습니다.
      return null;
    }
    return _messaging.getToken(vapidKey: vapidKey);
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  void handleMessageNavigation(RemoteMessage message) {
    final chatId = _extractChatId(message.data);
    if (chatId == null) {
      return;
    }
    _pushChatRoute(chatId);
  }

  void showForegroundSnackBar(RemoteMessage message) {
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) {
      return;
    }

    _foregroundEntry?.remove();
    final title = message.notification?.title ?? '새 메시지';
    final body = message.notification?.body ?? '새 채팅이 도착했어요.';

    final entry = OverlayEntry(
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6FF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2200AEEF),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00AEEF).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF0077A7),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF005D7D),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0A4F67),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _foregroundEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
      if (_foregroundEntry == entry) {
        _foregroundEntry = null;
      }
    });
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb || !_isAndroid) {
      // iOS는 foreground 표시 옵션으로 노출하고, Web은 별도 처리합니다.
      return;
    }

    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await initializeLocalNotifications();

    final androidDetails = AndroidNotificationDetails(
      defaultChannelId,
      defaultChannelName,
      channelDescription: defaultChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: notification.android?.smallIcon,
    );

    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = message.data.isEmpty ? null : jsonEncode(message.data);
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  String? _extractChatId(Map<String, dynamic> data) {
    final rawChatId = data['chatId'] ?? data['roomId'];
    final chatId = rawChatId?.toString().trim();
    if (chatId == null || chatId.isEmpty) {
      return null;
    }
    return chatId;
  }

  void _pushChatRoute(String chatId) {
    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      // 네비게이터가 준비되기 전이면 첫 프레임 이후에 재시도합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushChatRoute(chatId);
      });
      return;
    }

    navigatorState.push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(chatId: chatId),
      ),
    );
  }
}
