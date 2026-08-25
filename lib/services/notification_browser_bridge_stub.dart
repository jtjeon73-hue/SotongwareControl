import 'notification_browser_bridge_types.dart';

NotificationBrowserBridge createNotificationBrowserBridge() =>
    const _UnsupportedNotificationBrowserBridge();

class _UnsupportedNotificationBrowserBridge
    implements NotificationBrowserBridge {
  const _UnsupportedNotificationBrowserBridge();

  @override
  BrowserPushCapabilities capabilities() => const BrowserPushCapabilities(
    notificationSupported: false,
    serviceWorkerSupported: false,
    secureContext: false,
    permission: 'unsupported',
  );

  @override
  Future<String> requestPermission() async => 'unsupported';

  @override
  Future<void> waitForServiceWorkerReady() async {
    throw UnsupportedError('Web Push service worker is unavailable.');
  }
}
