import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kumpas/presentation/screens/auth/welcome_screen.dart';
import 'package:kumpas/presentation/screens/main_app_shell.dart';
import 'package:kumpas/services/auth_service.dart';
import 'package:kumpas/theme/app_theme.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainAppShell();
        }
        return const WelcomeScreen();
      },
    );
  }
}
