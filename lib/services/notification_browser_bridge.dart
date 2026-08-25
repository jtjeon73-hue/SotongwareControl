import 'notification_browser_bridge_stub.dart'
    if (dart.library.js_interop) 'notification_browser_bridge_web.dart'
    as implementation;
import 'notification_browser_bridge_types.dart';

export 'notification_browser_bridge_types.dart';

NotificationBrowserBridge createNotificationBrowserBridge() =>
    implementation.createNotificationBrowserBridge();
