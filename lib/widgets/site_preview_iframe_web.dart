import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web iframe that loads the real Preview URL at the widget's laid-out size
/// so the site's responsive CSS/MediaQuery sees a mobile viewport.
class SitePreviewIFrame extends StatelessWidget {
  SitePreviewIFrame({super.key, required this.url})
    : _viewType = 'site-preview-iframe-${url.hashCode}-${_seq++}';

  final String url;
  final String _viewType;

  static int _seq = 0;

  /// Opens a real browser window sized like a phone (~390×844).
  static Future<bool> openMobileSizedWindow(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final features =
        'width=390,height=844,menubar=no,toolbar=no,location=yes,'
        'status=no,resizable=yes,scrollbars=yes';
    final opened = web.window.open(trimmed, 'site_mobile_preview', features);
    return opened != null;
  }

  @override
  Widget build(BuildContext context) {
    // Register once per unique viewType for this widget instance.
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('title', '모바일 Preview')
        ..setAttribute('allow', 'fullscreen')
        ..referrerPolicy = 'no-referrer-when-downgrade';
      return iframe;
    });

    return HtmlElementView(viewType: _viewType);
  }
}
