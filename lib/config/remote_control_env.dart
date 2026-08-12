/// Remote Agent Control (Backend V1) environment & thresholds.
library;

class RemoteControlEnv {
  RemoteControlEnv._();

  /// Override: `--dart-define=REMOTE_CONTROL_BASE_URL=http://127.0.0.1:5001/...`
  static const baseUrlFromDefine = String.fromEnvironment(
    'REMOTE_CONTROL_BASE_URL',
  );

  /// Production Hosting (rewrite `/api/**` → `api` function).
  static const productionBaseUrl = 'https://sotongware-control.web.app';

  /// Functions emulator example (path still `/api/control/...` on `api` function).
  static const emulatorFunctionsBaseUrl =
      'http://127.0.0.1:5001/sotongware-control/us-central1/api';

  static const useEmulatorFromDefine = bool.fromEnvironment(
    'REMOTE_CONTROL_USE_EMULATOR',
    defaultValue: false,
  );

  /// Runtime override for tests / local toggles (null = use defines).
  static String? overrideBaseUrl;
  static bool? overrideUseEmulator;

  static bool get useEmulator =>
      overrideUseEmulator ?? useEmulatorFromDefine;

  static String get baseUrl {
    final o = overrideBaseUrl?.trim();
    if (o != null && o.isNotEmpty) return o.replaceAll(RegExp(r'/$'), '');
    final d = baseUrlFromDefine.trim();
    if (d.isNotEmpty) return d.replaceAll(RegExp(r'/$'), '');
    if (useEmulator) {
      return emulatorFunctionsBaseUrl.replaceAll(RegExp(r'/$'), '');
    }
    return productionBaseUrl;
  }

  /// Agent online if lastHeartbeatAt within this many seconds.
  static const onlineThresholdSeconds = 90;

  static const approveStageEnabled = false;
  static const requestRevisionEnabled = false;
}
