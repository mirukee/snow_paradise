import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/product_service.dart';
import 'providers/user_service.dart';
import 'providers/profile_provider.dart';
import 'providers/admin_auth_provider.dart';
import 'screens/admin/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserService()),
        ChangeNotifierProvider(create: (context) => ProductService(isAdmin: true)),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => AdminAuthProvider()),
      ],
      child: const AdminApp(),
    ),
  );
}
