import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_auth_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snow Paradise Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
      ),
      home: Consumer<AdminAuthProvider>(
        builder: (context, authProvider, _) {
          if (!authProvider.isLoggedIn) {
            return const AdminLoginScreen();
          }
          return const AdminDashboardScreen();
        },
      ),
    );
  }
}
