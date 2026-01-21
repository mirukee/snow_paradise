import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [추가]
import 'firebase_options.dart';
import 'providers/product_service.dart'; // [추가]
import 'providers/main_tab_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/user_service.dart';
import 'screens/main_screen.dart';
import 'package:snow_paradise/services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/brand_service.dart'; // [추가]
import 'utils/route_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final navigatorKey = GlobalKey<NavigatorState>();
  
  // 브랜드 데이터 초기화 서비스
  final brandService = BrandService();
  await brandService.initialize(); // 앱 시작 전 동기화 대기 (필요하면 비동기로 빼도 됨)

  runApp(
    // [핵심] 앱 전체를 ChangeNotifierProvider로 감싸줍니다.
    MultiProvider(
      providers: [
        Provider.value(value: brandService), // 이미 초기화된 인스턴스 주입
        ChangeNotifierProvider(create: (context) => ProductService()),
        ChangeNotifierProvider(create: (context) => MainTabProvider()),
        ChangeNotifierProvider(create: (context) => UserService()),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) =>
              NotificationProvider(navigatorKey: navigatorKey)..initialize(),
        ),
        Provider(create: (_) => ChatService()),
      ],
      child: SnowParadiseApp(navigatorKey: navigatorKey),
    ),
  );
}

class SnowParadiseApp extends StatelessWidget {
  const SnowParadiseApp({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스노우 파라다이스',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00AEEF), // Ice Blue
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
