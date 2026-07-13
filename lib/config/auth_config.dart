import 'package:flutter/foundation.dart';

/// 관리자 인증 설정 (비밀번호는 절대 포함하지 않음)
class AuthConfig {
  AuthConfig._();

  /// 로그인 화면에 표시·입력받는 관리자 아이디
  static const displayAdminId = 'sotongware';

  /// Firebase Auth에 등록된 관리자 이메일
  /// 빌드 시: --dart-define=SOTONG_ADMIN_AUTH_EMAIL=...
  static const adminAuthEmail = String.fromEnvironment(
    'SOTONG_ADMIN_AUTH_EMAIL',
  );

  /// 허용 관리자 UID (비어 있으면 이메일만으로 검증)
  /// 빌드 시: --dart-define=SOTONG_ADMIN_UID=...
  static const adminUid = String.fromEnvironment('SOTONG_ADMIN_UID');

  static bool get hasAdminEmailConfigured => adminAuthEmail.trim().isNotEmpty;

  static bool isAuthorizedUser({required String? uid, required String? email}) {
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    final expectedEmail = adminAuthEmail.trim().toLowerCase();
    if (expectedEmail.isEmpty) return false;

    final emailOk = normalizedEmail == expectedEmail;
    if (adminUid.trim().isEmpty) return emailOk;
    return emailOk && uid == adminUid.trim();
  }

  static void debugLogAuthFailure(Object error) {
    if (kDebugMode) {
      debugPrint('[Auth] failure: $error');
    }
  }
}
