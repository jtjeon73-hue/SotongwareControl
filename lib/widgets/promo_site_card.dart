import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/promo_site_link.dart';
import '../state/control_scope.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';

class PromoSiteCard extends StatelessWidget {
  const PromoSiteCard({super.key, required this.site, this.compact = false});

  final PromoSiteLink site;
  final bool compact;

  Color get _visibilityColor {
    switch (site.visibility) {
      case SiteVisibility.private:
        return ControlColors.teal;
      case SiteVisibility.publicPlanned:
        return ControlColors.accentWarm;
      case SiteVisibility.publicLive:
        return ControlColors.sandBeige;
    }
  }

  IconData get _visibilityIcon {
    switch (site.visibility) {
      case SiteVisibility.private:
        return Icons.lock_outline;
      case SiteVisibility.publicPlanned:
      case SiteVisibility.publicLive:
        return Icons.public_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ControlScope.of(context);
    final url = state.promoUrlFor(site.id);
    final hasUrl = url.isNotEmpty;
    final color = _visibilityColor;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_visibilityIcon, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        site.visibility.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (site.isBusinessHub) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ControlColors.sandBeige.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '사업 총괄',
                      style: TextStyle(
                        fontSize: 9,
                        color: ControlColors.sandBeige,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (site.isBusinessHub) ...[
              Text(
                site.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: compact ? 15 : 16),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              site.repoName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: compact ? 13 : 14,
                color: site.isBusinessHub ? ControlColors.textSecondary : null,
              ),
            ),
            if (!site.isBusinessHub) ...[
              const SizedBox(height: 4),
              Text(
                site.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ControlColors.textSecondary,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
            if (site.isBusinessHub && !compact) ...[
              const SizedBox(height: 10),
              _InfoRow(
                label: '내부 연결',
                value: site.internalConnectionStatus ?? '—',
                highlight: true,
              ),
            ],
            if (!compact) ...[
              const SizedBox(height: 6),
              _InfoRow(label: '현재 상태', value: site.productionStatus),
              _InfoRow(label: '다음 확인', value: site.nextTask, highlight: true),
              if (!site.isBusinessHub)
                _InfoRow(label: '목적', value: site.purpose),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                site.productionStatus,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
            if (site.isBusinessHub) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(
                    label: hasUrl ? '연결 URL 등록됨' : 'URL 미등록',
                    color: hasUrl
                        ? ControlColors.teal
                        : ControlColors.textMuted,
                  ),
                  const _StatusChip(
                    label: 'GitHub Pages 배포 확인 필요',
                    color: ControlColors.accentWarm,
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  '404 발생 시 해당 promo 저장소 Settings → Pages → main / docs 설정 확인',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    color: ControlColors.textMuted,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ControlColors.slate.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ControlColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    hasUrl ? Icons.link : Icons.link_off_outlined,
                    size: 14,
                    color: hasUrl
                        ? ControlColors.teal
                        : ControlColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasUrl ? url : 'GitHub Pages URL: 준비 중',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: hasUrl
                            ? ControlColors.teal
                            : ControlColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasUrl)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      tooltip: 'URL 복사',
                      onPressed: () => _copyUrl(context, url),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasUrl)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openSite(context, url),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('사이트 열기'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ControlColors.teal,
                        foregroundColor: ControlColors.deepNavy,
                        textStyle: const TextStyle(fontSize: 12),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (hasUrl) const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () =>
                      _editUrl(context, site.id, state.promoUrlFor(site.id)),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: Text(hasUrl ? 'URL 수정' : 'URL 등록'),
                  style: TextButton.styleFrom(
                    foregroundColor: ControlColors.teal,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSite(BuildContext context, String url) async {
    final ok = await ExternalUrl.open(url);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사이트를 열 수 없습니다. URL을 확인해 주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL이 복사되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editUrl(
    BuildContext context,
    String siteId,
    String currentUrl,
  ) async {
    final controller = TextEditingController(text: currentUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ControlColors.cardBg,
        title: const Text('GitHub Pages URL 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '예: https://username.github.io/SotongAutomationPromo/',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: '비우면 기본 URL 또는 "준비 중"',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && context.mounted) {
      await ControlScope.of(context).setPromoUrl(siteId, result);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: highlight ? ControlColors.teal : null,
                fontWeight: highlight ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
