import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/auth_config.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../theme/control_theme.dart';
import '../widgets/sotong_brand_icon.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.authenticatedBuilder,
  });

  final AuthClient authService;
  final WidgetBuilder authenticatedBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.connectionState == ConnectionState.waiting
            ? authService.currentUser
            : snapshot.data;

        // 세션이 아직 없으면 로그인 화면 (무한 로딩 방지)
        if (user == null) {
          return LoginScreen(authService: authService);
        }

        final authorized = AuthConfig.isAuthorizedUser(
          uid: user.uid,
          email: user.email,
        );
        if (!authorized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            authService.signOut();
          });
          return LoginScreen(authService: authService);
        }

        return authenticatedBuilder(context);
      },
    );
  }
}

/// Firebase 초기화 직후 잠깐 사용하는 로딩 화면 (main에서 필요 시)
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ControlColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SotongBrandIcon(size: 72),
            SizedBox(height: 20),
            CircularProgressIndicator(color: ControlColors.teal),
            SizedBox(height: 12),
            Text(
              '소통총관제 준비 중…',
              style: TextStyle(color: ControlColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
