import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/design_system.dart';
import 'providers/auth_provider.dart';
import 'providers/todo_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/admin/admin_layout.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable offline persistence
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => TodoProvider()),
        ],
        child: const MotodoApp(),
      ),
    );
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Failed', 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                Text(
                  error, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)
                ),
                const SizedBox(height: 24),
                const Text(
                  "Please run 'flutterfire configure' in your terminal to generate the correct firebase_options.dart file.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MotodoApp extends StatelessWidget {
  const MotodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Motodo B2B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.priority5,
          background: AppColors.background,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const AdminLayout() : const LoginScreen();
        },
      ),
    );
  }
}
