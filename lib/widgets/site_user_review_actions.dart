import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/design_system/design_system_catalog.dart';
import '../models/sotong24_remote_models.dart';
import '../services/design_system/design_system_service.dart';
import '../theme/control_theme.dart';
import 'design_system/design_profile_option_card.dart';
import 'site_mobile_preview_dialog.dart';

/// Structured STEP15 site review decision payload for STEP16 revision.
class SiteReviewDecisionPayload {
  const SiteReviewDecisionPayload({
    required this.reviewDecision,
    required this.reviewComment,
    this.selectedDesignDirection = '',
    this.designProfileCode = '',
    this.designSystemVersion = DesignSystemCatalog.kVersion,
    this.reviewedRevision = 'r1',
  });

  final String reviewDecision;
  final String reviewComment;
  final String selectedDesignDirection;
  final String designProfileCode;
  final String designSystemVersion;
  final String reviewedRevision;

  /// Wire format consumed by Agent / STEP16 prompts.
  String toRevisionMessage() {
    final buf = StringBuffer()
      ..writeln('[reviewDecision=$reviewDecision]')
      ..writeln('[reviewedRevision=$reviewedRevision]')
      ..writeln('[siteRevisionContract=1]');
    if (selectedDesignDirection.trim().isNotEmpty) {
      buf.writeln('[selectedDesignDirection=$selectedDesignDirection]');
    }
    if (designProfileCode.trim().isNotEmpty) {
      buf.writeln('[designProfileCode=$designProfileCode]');
      buf.writeln('[designSource=revision_change]');
      buf.writeln('[designSystemVersion=$designSystemVersion]');
    }
    if (reviewComment.trim().isNotEmpty) {
      buf.writeln(reviewComment.trim());
    }
    return buf.toString().trim();
  }

  /// Extract structured tags from a revision message (Control ↔ Agent contract).
  static ({
    String reviewDecision,
    String selectedDesignDirection,
    String designProfileCode,
    String reviewedRevision,
  })
  parseTags(String message) {
    String field(String name) {
      final m = RegExp(
        '\\[$name=([^\\]]*)\\]',
        multiLine: true,
      ).firstMatch(message);
      return (m?.group(1) ?? '').trim();
    }

    return (
      reviewDecision: field('reviewDecision'),
      selectedDesignDirection: field('selectedDesignDirection'),
      designProfileCode: field('designProfileCode'),
      reviewedRevision: field('reviewedRevision'),
    );
  }
}

/// Legacy free-form directions (still accepted for older revision messages).
const kSiteDesignDirections = <(String, String)>[
  ('keep_current_partial_edit', '현재 디자인 유지 + 일부 수정'),
  ('more_professional_industrial', '더 전문적인 산업형'),
  ('more_modern_tech', '더 현대적인 테크형'),
  ('more_friendly_service', '더 친근한 서비스형'),
  ('more_premium', '더 고급스러운 프리미엄형'),
  ('custom_request', '직접 요청'),
];

/// Design System v1 profile picks for post-result design change.
const kDesignSystemProfileOptions = <(String, String, String)>[
  // code, label, legacy selectedDesignDirection
  ('A', 'A · SotongWare Standard', 'keep_current_partial_edit'),
  ('B', 'B · Premium Technology', 'more_professional_industrial'),
  ('C', 'C · Friendly Modern', 'more_friendly_service'),
  ('D', 'D · Minimal Professional', 'more_premium'),
  ('E', 'E · Dynamic Content', 'more_modern_tech'),
];

Future<void> openSiteReviewUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// User review panel for site STEP15 — shown above stall recovery actions.
class SiteUserReviewActions extends StatelessWidget {
  const SiteUserReviewActions({
    super.key,
    required this.project,
    required this.stage,
    required this.busy,
    required this.onApprove,
    required this.onChangesRequested,
    required this.onDesignChange,
    required this.onHold,
  });

  final Sotong24RemoteProject project;
  final Sotong24RemoteStage stage;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onChangesRequested;
  final VoidCallback onDesignChange;
  final VoidCallback onHold;

  /// Hosting review channel only — never Storage artifact downloadUrl.
  String? get _openUrl => stage.openableSiteReviewPreviewUrl;

  @override
  Widget build(BuildContext context) {
    final url = _openUrl;
    // Prefer stage.revision (synced site review rev). Do not inflate via
    // project.finalRevision when stage revision is already set.
    final rev = stage.revision > 0 ? stage.revision : project.finalRevision;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '사용자 검토 · r$rev',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 4),
          if (stage.isOnHold) ...[
            Container(
              key: const Key('site_review_hold_status'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ControlColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ControlColors.teal.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                '사용자 보류 · 결과는 보존되며 STEP16은 시작되지 않습니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: ControlColors.teal,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else if (stage.isDesignChangeRequested) ...[
            Container(
              key: const Key('site_review_design_change_status'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ControlColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ControlColors.teal.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                stage.selectedDesignDirection.trim().isEmpty
                    ? '디자인 변경 요청됨 · Agent가 STEP16/r${rev + 1}로 반영할 때까지 대기합니다.'
                    : '디자인 변경 요청됨 (${stage.selectedDesignDirection}) · '
                          'Agent가 STEP16/r${rev + 1}로 반영할 때까지 대기합니다.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: ControlColors.teal,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            const Text(
              'STEP15 검토 준비 완료. 결과를 확인한 뒤 승인·보완·디자인 변경·보류를 선택하세요. '
              '이 승인은 외부 공개(STEP18) 승인이 아닙니다.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: ControlColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (url != null) ...[
            FilledButton.icon(
              key: const Key('site_review_open'),
              onPressed: busy ? null : () => openSiteReviewUrl(url),
              icon: const Icon(Icons.open_in_new),
              label: const Text('결과 사이트 열기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('site_review_mobile'),
              onPressed: busy
                  ? null
                  : () => showSiteMobilePreviewDialog(context, previewUrl: url),
              icon: const Icon(Icons.phone_iphone),
              label: const Text('모바일에서 보기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('site_review_copy'),
              onPressed: busy
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('검토 URL을 복사했습니다.')),
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
              label: const Text('URL 복사'),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              '검토 URL이 아직 등록되지 않았습니다. Agent가 Preview를 올리면 여기에 표시됩니다.',
              style: TextStyle(color: ControlColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: const Key('site_review_approve'),
            onPressed: busy || url == null ? null : onApprove,
            child: const Text('이 결과 승인'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('site_review_changes'),
            onPressed: busy ? null : onChangesRequested,
            style: OutlinedButton.styleFrom(
              foregroundColor: ControlColors.accentRose,
              side: const BorderSide(color: ControlColors.accentRose),
            ),
            child: const Text('보완수정'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('site_review_design'),
            onPressed: busy ? null : onDesignChange,
            child: const Text('디자인 변경'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('site_review_hold'),
            onPressed: busy ? null : onHold,
            child: const Text('보류 (결과 보존 · STEP16 미진입)'),
          ),
        ],
      ),
    );
  }
}

Future<SiteReviewDecisionPayload?> showSiteDesignChangeDialog(
  BuildContext context, {
  String reviewedRevision = 'r1',
  String currentProfileCode = '',
}) async {
  String selectedCode = currentProfileCode.trim().isNotEmpty
      ? currentProfileCode.trim().toUpperCase()
      : 'B';
  if (!kDesignSystemProfileOptions.any((o) => o.$1 == selectedCode)) {
    selectedCode = 'A';
  }
  // Prefer a different profile than current when changing design.
  if (currentProfileCode.trim().toUpperCase() == selectedCode) {
    selectedCode = selectedCode == 'A' ? 'B' : 'A';
  }
  final comment = TextEditingController();
  DesignSystemCatalog? catalog;
  try {
    catalog = await DesignSystemService.instance.loadCatalog();
  } catch (_) {
    catalog = null;
  }
  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final active = catalog?.byCode(selectedCode);
            return AlertDialog(
              title: const Text('디자인 변경'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFEFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF99F6E4)),
                        ),
                        child: Text(
                          currentProfileCode.trim().isEmpty
                              ? '기능·내용·히스토리는 보존하고, 디자인 프로필만 새 revision으로 변경합니다.'
                              : '현재 디자인: $currentProfileCode\n기능·내용·히스토리 보존 + 디자인만 변경합니다. 기존 revision은 덮어쓰지 않습니다.',
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (catalog != null)
                        ...catalog.profiles.where((p) => p.isActive).map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DesignProfileOptionCard(
                              profile: p,
                              selected: selectedCode == p.profileCode,
                              compact: true,
                              badge: currentProfileCode.trim().toUpperCase() ==
                                      p.profileCode
                                  ? '현재'
                                  : null,
                              onTap: () =>
                                  setLocal(() => selectedCode = p.profileCode),
                            ),
                          );
                        })
                      else
                        for (final opt in kDesignSystemProfileOptions)
                          RadioListTile<String>(
                            dense: true,
                            value: opt.$1,
                            // ignore: deprecated_member_use
                            groupValue: selectedCode,
                            title: Text(
                              opt.$2,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              'legacy: ${opt.$3}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            // ignore: deprecated_member_use
                            onChanged: (v) {
                              if (v == null) return;
                              setLocal(() => selectedCode = v);
                            },
                          ),
                      if (active != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '변경 미리보기: ${active.visualMood.isEmpty ? active.profileDescription : active.visualMood}'
                          '\n히어로 ${active.heroPattern} · 밀도 ${active.densityLabel} · CTA ${active.ctaTone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: ControlColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: comment,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '추가 요청',
                          hintText: '바꾸고 싶은 톤·레이아웃·카피 등을 적어 주세요.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('디자인 변경 요청'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return null;
    final opt = kDesignSystemProfileOptions.firstWhere(
      (o) => o.$1 == selectedCode,
      orElse: () => kDesignSystemProfileOptions.first,
    );
    final profile = catalog?.byCode(selectedCode);
    return SiteReviewDecisionPayload(
      reviewDecision: 'design_change_requested',
      selectedDesignDirection: profile?.revisionDirectionHint ?? opt.$3,
      designProfileCode: opt.$1,
      designSystemVersion:
          catalog?.designSystemVersion ?? DesignSystemCatalog.kVersion,
      reviewedRevision: reviewedRevision,
      reviewComment: comment.text.trim().isEmpty
          ? '디자인 프로필 ${opt.$1} 변경 요청 (기능·내용·히스토리 보존, 디자인만 변경)'
          : comment.text.trim(),
    );
  } finally {
    comment.dispose();
  }
}
