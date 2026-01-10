import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [추가]
import 'providers/product_service.dart'; // [추가]
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    // [핵심] 앱 전체를 ChangeNotifierProvider로 감싸줍니다.
    ChangeNotifierProvider(
      create: (context) => ProductService(),
      child: const SnowParadiseApp(),
    ),
  );
}

class SnowParadiseApp extends StatelessWidget {
  const SnowParadiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스노우 파라다이스',
      debugShowCheckedModeBanner: false,
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
