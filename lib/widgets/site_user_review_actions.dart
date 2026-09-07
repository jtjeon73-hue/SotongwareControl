import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sotong24_remote_models.dart';
import '../theme/control_theme.dart';

/// Structured STEP15 site review decision payload for STEP16 revision.
class SiteReviewDecisionPayload {
  const SiteReviewDecisionPayload({
    required this.reviewDecision,
    required this.reviewComment,
    this.selectedDesignDirection = '',
    this.reviewedRevision = 'r1',
  });

  final String reviewDecision;
  final String reviewComment;
  final String selectedDesignDirection;
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
    if (reviewComment.trim().isNotEmpty) {
      buf.writeln(reviewComment.trim());
    }
    return buf.toString().trim();
  }
}

const kSiteDesignDirections = <(String, String)>[
  ('keep_current_partial_edit', '현재 디자인 유지 + 일부 수정'),
  ('more_professional_industrial', '더 전문적인 산업형'),
  ('more_modern_tech', '더 현대적인 테크형'),
  ('more_friendly_service', '더 친근한 서비스형'),
  ('more_premium', '더 고급스러운 프리미엄형'),
  ('custom_request', '직접 요청'),
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

  String? get _openUrl => stage.openablePreviewUrl ?? stage.openableResultUrl;

  @override
  Widget build(BuildContext context) {
    final url = _openUrl;
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
              onPressed: busy ? null : () => openSiteReviewUrl(url),
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
}) async {
  String selected = kSiteDesignDirections.first.$1;
  final comment = TextEditingController();
  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('디자인 변경 요청'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '기존 r1 결과는 보존됩니다. 선택 내용은 STEP16 revision 요청으로 전달됩니다.',
                        style: TextStyle(fontSize: 13, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      for (final opt in kSiteDesignDirections)
                        RadioListTile<String>(
                          dense: true,
                          value: opt.$1,
                          // ignore: deprecated_member_use
                          groupValue: selected,
                          title: Text(
                            opt.$2,
                            style: const TextStyle(fontSize: 14),
                          ),
                          // ignore: deprecated_member_use
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() => selected = v);
                          },
                        ),
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
    return SiteReviewDecisionPayload(
      reviewDecision: 'design_change_requested',
      selectedDesignDirection: selected,
      reviewedRevision: reviewedRevision,
      reviewComment: comment.text.trim().isEmpty
          ? '디자인 방향 변경 요청'
          : comment.text.trim(),
    );
  } finally {
    comment.dispose();
  }
}
