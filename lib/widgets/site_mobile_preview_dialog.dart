import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/control_theme.dart';
import 'site_preview_iframe.dart';

/// Desktop STEP15 helper: show Preview inside a ~390×844 phone frame.
Future<void> showSiteMobilePreviewDialog(
  BuildContext context, {
  required String previewUrl,
}) async {
  final url = previewUrl.trim();
  if (url.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 920),
          child: _SiteMobilePreviewBody(url: url),
        ),
      );
    },
  );
}

class _SiteMobilePreviewBody extends StatelessWidget {
  const _SiteMobilePreviewBody({required this.url});

  final String url;

  static const double phoneW = 390;
  static const double phoneH = 844;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('모바일 확인용 URL을 복사했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '모바일 Preview · 390×844',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(
                key: const Key('site_mobile_preview_close'),
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Text(
            '데스크톱에서 모바일 레이아웃만 확인합니다. 사이트 responsive는 그대로 사용됩니다. '
            '실제 휴대폰 확인은 QR 또는 URL 복사를 이용하세요.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: ControlColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final phone = _PhoneFrame(
                  width: phoneW,
                  height: phoneH,
                  child: SitePreviewIFrame(url: url),
                );

                // Keep a true 390 CSS-px iframe so responsive CSS matches mobile.
                // Avoid scaling platform views with FittedBox/Transform.
                final frame = SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: phone,
                  ),
                );

                final panel = _SidePanel(
                  url: url,
                  onCopy: () => _copy(context),
                  onOpenSizedWindow: () async {
                    final ok = await SitePreviewIFrame.openMobileSizedWindow(
                      url,
                    );
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '팝업이 차단되었을 수 있습니다. QR/URL 복사를 이용해 주세요.',
                          ),
                        ),
                      );
                    }
                  },
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: Center(child: frame)),
                      const SizedBox(width: 16),
                      SizedBox(width: 220, child: panel),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(child: Center(child: frame)),
                    const SizedBox(height: 10),
                    panel,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width + 16,
      height: height + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2430),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF3A4654), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: Colors.white,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.url,
    required this.onCopy,
    required this.onOpenSizedWindow,
  });

  final String url;
  final VoidCallback onCopy;
  final VoidCallback onOpenSizedWindow;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '실제 휴대폰에서 열기',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ControlColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: url,
                  size: 168,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1B2430),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1B2430),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('site_mobile_preview_copy'),
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('URL 복사'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('site_mobile_preview_popup'),
            onPressed: onOpenSizedWindow,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('390×844 창으로 열기'),
          ),
          const SizedBox(height: 10),
          SelectableText(
            url,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: ControlColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
