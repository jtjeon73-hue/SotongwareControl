import 'package:flutter/material.dart';

import '../theme/control_theme.dart';
import '../utils/external_url.dart';

enum ResultLinkStyle { primary, outlined, tonal }

class ResultLinkButton extends StatelessWidget {
  const ResultLinkButton({
    super.key,
    required this.url,
    required this.label,
    this.icon = Icons.rocket_launch_rounded,
    this.style = ResultLinkStyle.primary,
    this.fullWidth = true,
    this.onOpenFailed,
  });

  const ResultLinkButton.explore({
    super.key,
    required this.url,
    required this.label,
    this.style = ResultLinkStyle.primary,
    this.fullWidth = true,
    this.onOpenFailed,
  }) : icon = Icons.travel_explore_rounded;

  const ResultLinkButton.pages({
    super.key,
    required this.url,
    required this.label,
    this.style = ResultLinkStyle.outlined,
    this.fullWidth = true,
    this.onOpenFailed,
  }) : icon = Icons.public_rounded;

  final String url;
  final String label;
  final IconData icon;
  final ResultLinkStyle style;
  final bool fullWidth;
  final VoidCallback? onOpenFailed;

  bool get _hasUrl => url.trim().isNotEmpty;

  Future<void> _open(BuildContext context) async {
    if (!_hasUrl) return;
    final ok = await ExternalUrl.open(url);
    if (!context.mounted) return;
    if (!ok) {
      onOpenFailed?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label — URL을 열 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = switch (style) {
      ResultLinkStyle.primary => FilledButton.icon(
        onPressed: _hasUrl ? () => _open(context) : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: ControlColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ControlColors.slate,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      ResultLinkStyle.outlined => OutlinedButton.icon(
        onPressed: _hasUrl ? () => _open(context) : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: ControlColors.teal,
          side: BorderSide(color: ControlColors.teal.withValues(alpha: 0.45)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      ResultLinkStyle.tonal => FilledButton.tonalIcon(
        onPressed: _hasUrl ? () => _open(context) : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: ControlColors.tealSoft,
          foregroundColor: ControlColors.teal,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
