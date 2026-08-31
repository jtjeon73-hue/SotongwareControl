import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/auth_config.dart';
import '../config/remote_control_env.dart';

/// Runtime admin auth mapping loaded from the control API when dart-define is missing.
class AuthRuntimeConfig {
  AuthRuntimeConfig._();

  static String? _adminAuthEmail;
  static String? _adminUid;
  static String? _displayAdminId;
  static bool _loadAttempted = false;
  static bool _loadOk = false;

  static bool get isLoaded => _loadOk;

  static String get displayAdminId =>
      _displayAdminId ?? AuthConfig.displayAdminId;

  static String get adminAuthEmail =>
      (_adminAuthEmail ?? AuthConfig.adminAuthEmail).trim();

  static String get adminUid => (_adminUid ?? AuthConfig.adminUid).trim();

  static bool get hasAdminEmailConfigured =>
      AuthConfig.hasAdminEmailConfigured || adminAuthEmail.isNotEmpty;

  static bool isAuthorizedUser({required String? uid, required String? email}) {
    final expectedEmail = adminAuthEmail.trim().toLowerCase();
    if (expectedEmail.isEmpty) return false;
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    final emailOk = normalizedEmail == expectedEmail;
    final expectedUid = adminUid.trim();
    if (expectedUid.isEmpty) return emailOk;
    return emailOk && uid == expectedUid;
  }

  static Future<bool> ensureLoaded() async {
    if (AuthConfig.hasAdminEmailConfigured) {
      _loadOk = true;
      return true;
    }
    if (_loadAttempted) return _loadOk;
    _loadAttempted = true;
    try {
      final uri = Uri.parse(
        '${RemoteControlEnv.baseUrl}/api/control/auth-public-config',
      );
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['ok'] != true || decoded['configured'] != true) return false;
      final email = '${decoded['adminAuthEmail'] ?? ''}'.trim();
      final uid = '${decoded['adminUid'] ?? ''}'.trim();
      final displayId = '${decoded['displayAdminId'] ?? ''}'.trim();
      if (email.isEmpty || uid.isEmpty || displayId.isEmpty) return false;
      _adminAuthEmail = email;
      _adminUid = uid;
      _displayAdminId = displayId;
      _loadOk = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Test-only reset.
  static void resetForTest() {
    _adminAuthEmail = null;
    _adminUid = null;
    _displayAdminId = null;
    _loadAttempted = false;
    _loadOk = false;
  }
}
