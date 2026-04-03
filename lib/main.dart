import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/remote_config_service.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'widgets/main_screen.dart';
import 'widgets/ui/ui_constants.dart';
import 'widgets/ui/lagja_loader.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await RemoteConfigService.initialize();
  runApp(const LagjaApp());
}

class LagjaApp extends StatelessWidget {
  const LagjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return MaterialApp(
      title: 'Lagja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: LagjaLoader(message: "Authenticating..."),
            );
          }

          if (snapshot.hasData) {
            return const MainScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

