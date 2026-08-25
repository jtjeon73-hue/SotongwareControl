import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'notification_browser_bridge_types.dart';

NotificationBrowserBridge createNotificationBrowserBridge() =>
    const _WebNotificationBrowserBridge();

class _WebNotificationBrowserBridge implements NotificationBrowserBridge {
  const _WebNotificationBrowserBridge();

  @override
  BrowserPushCapabilities capabilities() {
    final notificationSupported = globalContext
        .hasProperty('Notification'.toJS)
        .toDart;
    final serviceWorkerSupported = (web.window.navigator as JSObject)
        .hasProperty('serviceWorker'.toJS)
        .toDart;
    var permission = 'unsupported';
    if (notificationSupported) {
      try {
        permission = web.Notification.permission;
      } catch (_) {
        permission = 'unsupported';
      }
    }
    return BrowserPushCapabilities(
      notificationSupported: notificationSupported,
      serviceWorkerSupported: serviceWorkerSupported,
      secureContext: web.window.isSecureContext,
      permission: permission,
    );
  }

  @override
  Future<String> requestPermission() async {
    // Keep this browser call as the first operation. Chrome requires it to be
    // reached while the Flutter button's user-activation context is alive.
    final permissionPromise = web.Notification.requestPermission();
    return (await permissionPromise.toDart).toDart;
  }

  @override
  Future<void> waitForServiceWorkerReady() async {
    await web.window.navigator.serviceWorker.ready.toDart.timeout(
      const Duration(seconds: 12),
    );
  }
}
