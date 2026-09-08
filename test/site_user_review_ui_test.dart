import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_monitoring.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/widgets/site_user_review_actions.dart';

Sotong24RemoteStage _siteReviewStage({
  required String previewUrl,
  String status = Sotong24WorkStatus.awaitingApproval,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return Sotong24RemoteStage(
    stageId: 'site_user_review',
    stageNumber: 15,
    stageName: '사용자 검토 패키지',
    status: status,
    summary: 'review ready',
    previewUrl: previewUrl,
    resultUrl: previewUrl,
    approvalRequired: true,
    criteriaMet: true,
    approvalStatus: ApprovalStatus.pending,
    updatedAt: now,
    revision: 1,
    startedAt: now,
    completedAt: now,
    lastActivityAt: now,
    activityState: 'approval_preparing',
  );
}

Sotong24RemoteProject _siteProject(Sotong24RemoteStage stage) {
  final now = DateTime.now().toUtc().toIso8601String();
  return Sotong24RemoteProject(
    projectId: 'wi_plan_demo_site',
    title: 'Demo Site',
    productType: ArtifactType.site,
    currentStage: 15,
    totalStages: 18,
    progress: 80,
    status: Sotong24WorkStatus.awaitingApproval,
    approvalStatus: ApprovalStatus.pending,
    pcStatus: Sotong24PcLinkStatus.online,
    lastHeartbeat: now,
    startedAt: now,
    updatedAt: now,
    stages: [stage],
  );
}

void main() {
  test('waiting_user_review / awaiting_approval is not stalled', () {
    final stage = _siteReviewStage(
      previewUrl: 'https://sotongware-control--sr-demo-r1.web.app',
    );
    final project = _siteProject(stage);
    final snap = Sotong24StageMonitoring.evaluate(
      project: project,
      stage: stage,
      now: DateTime.now().toUtc(),
    );
    expect(snap.health, Sotong24StageHealth.awaitingUser);
    expect(snap.healthLabel, '사용자 승인 대기');
  });

  test('SiteReviewDecisionPayload wires design_change contract', () {
    final p = SiteReviewDecisionPayload(
      reviewDecision: 'design_change_requested',
      selectedDesignDirection: 'more_premium',
      reviewedRevision: 'r1',
      reviewComment: '톤을 더 고급스럽게',
    );
    final msg = p.toRevisionMessage();
    expect(msg, contains('[reviewDecision=design_change_requested]'));
    expect(msg, contains('[selectedDesignDirection=more_premium]'));
    expect(msg, contains('[reviewedRevision=r1]'));
    expect(msg, contains('톤을 더 고급스럽게'));
    final tags = SiteReviewDecisionPayload.parseTags(msg);
    expect(tags.reviewDecision, 'design_change_requested');
    expect(tags.selectedDesignDirection, 'more_premium');
    expect(tags.reviewedRevision, 'r1');
  });

  testWidgets('design_change_requested shows status banner', (tester) async {
    final stage =
        _siteReviewStage(
          previewUrl: 'https://sotongware-control--sr-demo-r1.web.app',
        ).copyWith(
          approvalStatus: ApprovalStatus.revisionRequested,
          reviewDecision: 'design_change_requested',
          selectedDesignDirection: 'more_premium',
        );
    final project = _siteProject(stage);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiteUserReviewActions(
            project: project,
            stage: stage,
            busy: false,
            onApprove: () {},
            onChangesRequested: () {},
            onDesignChange: () {},
            onHold: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('site_review_design_change_status')),
      findsOneWidget,
    );
    expect(find.textContaining('디자인 변경 요청됨'), findsOneWidget);
  });

  testWidgets('site review actions render open/approve controls', (
    tester,
  ) async {
    final stage = _siteReviewStage(
      previewUrl: 'https://sotongware-control--sr-demo-r1.web.app',
    );
    final project = _siteProject(stage);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiteUserReviewActions(
            project: project,
            stage: stage,
            busy: false,
            onApprove: () {},
            onChangesRequested: () {},
            onDesignChange: () {},
            onHold: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('site_review_open')), findsOneWidget);
    expect(find.byKey(const Key('site_review_mobile')), findsOneWidget);
    expect(find.byKey(const Key('site_review_approve')), findsOneWidget);
    expect(find.byKey(const Key('site_review_changes')), findsOneWidget);
    expect(find.byKey(const Key('site_review_design')), findsOneWidget);
    expect(find.byKey(const Key('site_review_hold')), findsOneWidget);
    expect(find.text('결과 사이트 열기'), findsOneWidget);
    expect(find.text('모바일에서 보기'), findsOneWidget);

    await tester.tap(find.byKey(const Key('site_review_mobile')));
    await tester.pumpAndSettle();
    expect(find.textContaining('모바일 Preview'), findsOneWidget);
    expect(find.byKey(const Key('site_mobile_preview_copy')), findsOneWidget);
    expect(find.byKey(const Key('site_mobile_preview_popup')), findsOneWidget);
  });

  testWidgets('결과 사이트 열기 ignores Storage artifact downloadUrl', (tester) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final stage = Sotong24RemoteStage(
      stageId: 'site_user_review',
      stageNumber: 15,
      stageName: '사용자 검토 패키지',
      status: Sotong24WorkStatus.awaitingApproval,
      resultUrl:
          'https://storage.googleapis.com/sotongware-control.firebasestorage.app/sotong24/artifacts/prod/wi/site_user_review/r1/15_site_user_review_result.md',
      previewUrl:
          'https://storage.googleapis.com/sotongware-control.firebasestorage.app/sotong24/artifacts/prod/wi/site_user_review/r1/15_site_user_review_result.md',
      approvalRequired: true,
      criteriaMet: true,
      approvalStatus: ApprovalStatus.pending,
      updatedAt: now,
      revision: 3,
    );
    expect(stage.openableSiteReviewPreviewUrl, isNull);
    expect(stage.openableResultUrl, isNotNull);

    final withHosting = stage.copyWith(revision: 2);
    // copyWith does not override urls; build explicit stage
    final stageR2 = Sotong24RemoteStage(
      stageId: 'site_user_review',
      stageNumber: 15,
      stageName: '사용자 검토 패키지',
      status: Sotong24WorkStatus.awaitingApproval,
      resultUrl: stage.resultUrl,
      previewUrl: 'https://sotongware-control--sr-demo-r2.web.app',
      approvalRequired: true,
      criteriaMet: true,
      approvalStatus: ApprovalStatus.pending,
      updatedAt: now,
      revision: 2,
    );
    expect(
      stageR2.openableSiteReviewPreviewUrl,
      'https://sotongware-control--sr-demo-r2.web.app',
    );
    expect(stageR2.openableResultUrl, stage.resultUrl);
    expect(withHosting.revision, 2);
  });
}
