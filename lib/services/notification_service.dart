import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

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
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  static const String defaultChannelId = 'snow_paradise_default';
  static const String defaultChannelName = '기본 알림';
  static const String defaultChannelDescription = 'Snow Paradise 기본 알림 채널';

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _localNotificationsReady = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
}
