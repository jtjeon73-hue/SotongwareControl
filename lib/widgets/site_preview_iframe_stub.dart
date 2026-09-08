import 'package:flutter/material.dart';

import '../theme/control_theme.dart';

/// Non-web fallback — no iframe platform view.
class SitePreviewIFrame extends StatelessWidget {
  const SitePreviewIFrame({super.key, required this.url});

  final String url;

  static Future<bool> openMobileSizedWindow(String url) async => false;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ControlColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '이 환경에서는 인앱 모바일 프레임을 표시할 수 없습니다.\n'
            'QR 코드 또는 URL 복사로 휴대폰에서 열어 주세요.\n\n$url',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ControlColors.textSecondary,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
