import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sotong_ware_control/app.dart';
import 'package:sotong_ware_control/config/auth_config.dart';
import 'package:sotong_ware_control/screens/login_screen.dart';
import 'package:sotong_ware_control/services/auth_service.dart';
import 'package:sotong_ware_control/state/control_scope.dart';
import 'package:sotong_ware_control/state/control_state.dart';
import 'package:sotong_ware_control/widgets/auth_gate.dart';
import 'package:sotong_ware_control/widgets/sotong_brand_icon.dart';

class _FakeAuthClient implements AuthClient {
  _FakeAuthClient();

  User? user;
  AuthFailureReason? nextFailure;
  int signInCalls = 0;
  final _controller = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => user;

  @override
  bool get isAuthorized =>
      user != null &&
      AuthConfig.isAuthorizedUser(uid: user!.uid, email: user!.email);

  @override
  Future<void> setPersistence({required bool keepSignedIn}) async {}

  @override
  Future<AuthResult> signIn({
    required String adminId,
    required String password,
    required bool keepSignedIn,
  }) async {
    signInCalls += 1;
    final id = adminId.trim();
    if (id.isEmpty) {
      return const AuthResult.failure(AuthFailureReason.emptyId);
    }
    if (password.isEmpty) {
      return const AuthResult.failure(AuthFailureReason.emptyPassword);
    }
    if (id != AuthConfig.displayAdminId) {
      return const AuthResult.failure(AuthFailureReason.invalidId);
    }
    if (nextFailure != null) {
      return AuthResult.failure(nextFailure!);
    }
    return const AuthResult.success();
  }

  @override
  Future<void> signOut() async {
    user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AuthConfig rejects empty email configuration', () {
    expect(AuthConfig.hasAdminEmailConfigured, isFalse);
    expect(AuthConfig.isAuthorizedUser(uid: 'x', email: 'a@b.c'), isFalse);
  });

  testWidgets('Logout state shows login screen only', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FakeAuthClient();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: auth,
          authenticatedBuilder: (_) => const Scaffold(body: Text('MAIN')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('관리자 로그인'), findsOneWidget);
    expect(find.text('MAIN'), findsNothing);
    expect(find.text('전체 사업 현황'), findsNothing);
    expect(find.byType(SotongBrandIcon), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty credentials and invalid id are blocked', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FakeAuthClient();
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.textContaining('입력해 주세요'), findsOneWidget);
    expect(auth.signInCalls, 1);

    await tester.enterText(find.byType(TextField).at(0), 'wrong-id');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.text('아이디 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
    expect(find.textContaining('등록되지 않은'), findsNothing);
  });

  testWidgets('Password visibility toggle works', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FakeAuthClient();
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid credentials show generic message', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = _FakeAuthClient()
      ..nextFailure = AuthFailureReason.invalidCredentials;
    addTearDown(auth.dispose);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'sotongware');
    await tester.enterText(find.byType(TextField).at(1), 'x');
    await tester.ensureVisible(find.text('로그인'));
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.text('아이디 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('Authenticated shell shows control menus', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controlState = ControlState();
    await controlState.initialize();
    final auth = _FakeAuthClient();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ControlScope(
        notifier: controlState,
        child: MaterialApp(home: ControlCenterShell(authService: auth)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('전체 사업 현황'), findsWidgets);
    expect(find.text('학습 대시보드'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('소통24워크'), findsWidgets);
    expect(find.text('데이터 관리'), findsWidgets);
    expect(find.text('관리자 로그인'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Authenticated shell fits mobile width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controlState = ControlState();
    await controlState.initialize();
    final auth = _FakeAuthClient();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ControlScope(
        notifier: controlState,
        child: MaterialApp(home: ControlCenterShell(authService: auth)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('로그아웃'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
