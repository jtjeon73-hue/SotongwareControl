import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalUrl {
  static Future<bool> open(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ExternalUrl.open failed: $e');
      }
      return false;
    }
  }
}
