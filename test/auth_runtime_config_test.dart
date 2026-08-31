import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/config/auth_config.dart';
import 'package:sotong_ware_control/services/auth_runtime_config.dart';

void main() {
  tearDown(AuthRuntimeConfig.resetForTest);

  test('AuthRuntimeConfig falls back to compile-time values when loaded', () {
    AuthRuntimeConfig.resetForTest();
    expect(AuthRuntimeConfig.displayAdminId, AuthConfig.displayAdminId);
    expect(AuthRuntimeConfig.hasAdminEmailConfigured, isFalse);
  });
}
