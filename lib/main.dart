// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/landing_page.dart';
import 'screens/parent/parent_dashboard.dart';
import 'screens/parent/ai_activity_generator.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/llg/llg_dashboard.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // If .env fails to load, fallback gracefully
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'LittleLumin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF4A90D9),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        routes: {
          '/landing': (context) => const LandingPageWidget(),
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/parent-dashboard': (context) => const ParentDashboard(),
          '/admin-dashboard': (context) => const AdminDashboard(),
          '/llg-dashboard': (context) => const LLGDashboard(),
          '/ai-generator': (context) => const AIActivityGeneratorScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    if (user == null) {
      return const LandingPageWidget();
    }

    return FutureBuilder<String?>(
      future: authService.getUserRole(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data ?? 'parent';

        switch (role) {
          case 'admin':
            return const AdminDashboard();
          case 'llg':
            return const LLGDashboard();
          case 'llg_pending':
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Your account is pending verification',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait for admin approval.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          case 'rejected':
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Your application was rejected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please contact support for more information.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          case 'parent':
          default:
            return const ParentDashboard();
        }
      },
    );
  }
}