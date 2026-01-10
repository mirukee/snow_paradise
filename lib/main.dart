import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const SnowParadiseApp());
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
