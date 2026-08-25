class BrowserPushCapabilities {
  const BrowserPushCapabilities({
    required this.notificationSupported,
    required this.serviceWorkerSupported,
    required this.secureContext,
    required this.permission,
  });

  final bool notificationSupported;
  final bool serviceWorkerSupported;
  final bool secureContext;
  final String permission;

  bool get supported =>
      notificationSupported && serviceWorkerSupported && secureContext;
}

abstract interface class NotificationBrowserBridge {
  BrowserPushCapabilities capabilities();

  /// Must be invoked directly from the user's click callback. Implementations
  /// may not perform another asynchronous operation before calling the browser
  /// Notification.requestPermission API.
  Future<String> requestPermission();

  Future<void> waitForServiceWorkerReady();
}
