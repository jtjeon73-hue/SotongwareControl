/// Deterministic studio rendering smoke + manifest (no network, no Chrome ops).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/project_design_state.dart';
import 'package:sotong_ware_control/services/commercial_work_instruction_preflight.dart';
import 'package:sotong_ware_control/services/work_instruction_delivery_presentation.dart';
import 'package:sotong_ware_control/widgets/project_design/project_design_wizard.dart';
import 'package:sotong_ware_control/widgets/project_design/step7_delivery_panel.dart';

class _RenderCase {
  const _RenderCase({
    required this.screenId,
    required this.viewport,
    required this.textScale,
    required this.state,
  });

  final String screenId;
  final Size viewport;
  final double textScale;
  final ProjectDesignState state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifestEntries = <Map<String, dynamic>>[];

  ProjectDesignState base({
    int step = 0,
    bool manualOnly = false,
    String creationMode = 'new_product',
    bool confirmed = false,
    bool validated = false,
  }) {
    return ProjectDesignState(
      step: step,
      artifactType: ArtifactType.ebook,
      selectedAudiences: const ['age_40_60', 'general'],
      selectedConceptIds: const ['ai_daily_assistant__ebook'],
      topic: '일상 AI 활용 입문 — 초보자를 위한 안전한 사용법',
      displayTitle: '일상 AI 활용 입문 — 초보자를 위한 안전한 사용법',
      customerProblem: '검색·요약·일정에 AI를 쓰고 싶지만 안전 규칙을 모름',
      desiredOutcome: '일상에서 안전하게 AI를 쓰는 루틴을 갖춤',
      targetCustomer: '40~60대 일반 사용자',
      reasonsToPay: const ['실전 체크리스트', '안전 주의사항'],
      uniqueValue: '과장 없는 생활형 AI 입문',
      designMemo: '반드시 포함할 내용: 피싱 주의',
      planningConfirmed: confirmed,
      originalUserBrief: '원문 브리프',
      originalUserBriefConfirmed: confirmed,
      aiAugmentedBrief: 'AI 보완 초안',
      acceptedAiSuggestions: const ['체크리스트 추가'],
      rejectedAiSuggestions: const ['수익 보장 문구'],
      manualOnlyMode: manualOnly,
      creationMode: creationMode,
      sourceInstructionId: creationMode == 'revise_existing' ? 'wi_src' : '',
      sourceRevision: creationMode == 'revise_existing' ? 'R1' : '',
      requestedChanges: creationMode == 'revise_existing'
          ? const ['문장 다듬기']
          : const [],
      commercialLocalValidated: validated,
      studioPipelinePhase: validated
          ? StudioPipelinePhase.locallyValidated
          : confirmed
          ? StudioPipelinePhase.contentConfirmed
          : StudioPipelinePhase.drafting,
      productionSelections: const {
        'level': ['beginner'],
      },
    );
  }

  Future<void> pumpCase(WidgetTester tester, _RenderCase c) async {
    tester.view.physicalSize = c.viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: c.viewport,
          textScaler: TextScaler.linear(c.textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 96),
                child: ProjectDesignWizard(
                  initial: c.state,
                  onChanged: (_) {},
                  instructionGenerated:
                      c.state.studioPipelinePhase !=
                          StudioPipelinePhase.drafting &&
                      c.state.planningConfirmed,
                  onRequestLocalValidate: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull, reason: c.screenId);

    // Overflow surfaces as FlutterError; also check no yellow/black overflow text.
    expect(find.textContaining('OVERFLOWED'), findsNothing);

    final hashInput =
        '${c.screenId}|${c.viewport.width.toInt()}x${c.viewport.height.toInt()}|${c.textScale}|${c.state.step}|${c.state.creationMode}|${c.state.manualOnlyMode}|${c.state.commercialLocalValidated}';
    manifestEntries.add({
      'screenId': c.screenId,
      'viewport': {
        'width': c.viewport.width.toInt(),
        'height': c.viewport.height.toInt(),
      },
      'textScale': c.textScale,
      'step': c.state.step,
      'creationMode': c.state.creationMode,
      'manualOnlyMode': c.state.manualOnlyMode,
      'commercialLocalValidated': c.state.commercialLocalValidated,
      'overflow': 0,
      'exception': null,
      'fixtureHash': hashInput.hashCode.toRadixString(16),
    });
  }

  testWidgets('studio screens × viewport × textScale render without overflow', (
    tester,
  ) async {
    final viewports = <(String, Size)>[
      ('desktop', const Size(1440, 900)),
      ('tablet', const Size(768, 1024)),
      ('mobile', const Size(390, 844)),
    ];
    final scales = [1.0, 1.3, 1.5];
    final screens = <(String, ProjectDesignState)>[
      ('step1_creation_artifact', base(step: ProjectDesignStep.artifact)),
      ('step2_audience', base(step: ProjectDesignStep.audience)),
      ('step3_topics', base(step: ProjectDesignStep.topics)),
      ('step4_value', base(step: ProjectDesignStep.details)),
      (
        'step5_ai_review',
        base(step: ProjectDesignStep.details)..aiAugmentedBrief = 'AI 비교문',
      ),
      ('step6_production', base(step: ProjectDesignStep.production)),
      (
        'step7_review_summary',
        base(step: ProjectDesignStep.review, confirmed: true),
      ),
      (
        'step7_finalize',
        base(step: ProjectDesignStep.finalize, confirmed: true),
      ),
      (
        'revise_existing',
        base(step: ProjectDesignStep.artifact, creationMode: 'revise_existing'),
      ),
      (
        'manual_only',
        base(
          step: ProjectDesignStep.finalize,
          manualOnly: true,
          confirmed: true,
        ),
      ),
      (
        'preflight_ready',
        base(
          step: ProjectDesignStep.finalize,
          confirmed: true,
          validated: true,
        ),
      ),
    ];

    for (final (vpName, size) in viewports) {
      for (final scale in scales) {
        for (final (screenId, state) in screens) {
          await pumpCase(
            tester,
            _RenderCase(
              screenId: '${screenId}_$vpName',
              viewport: size,
              textScale: scale,
              state: state.copy(),
            ),
          );
        }
      }
    }

    // Send blocked when not validated
    final blocked = WorkInstructionDeliveryPresentation.resolve(
      plan: null,
      validation: null,
      agents: const [],
      transferBusy: false,
      localCommercialValidated: false,
    );
    expect(blocked.buttonEnabled, isFalse);
    manifestEntries.add({
      'screenId': 'delivery_blocked_without_local_validate',
      'buttonEnabled': false,
      'buttonState': blocked.buttonState.name,
      'overflow': 0,
      'fixtureHash': 'delivery-blocked'.hashCode.toRadixString(16),
    });

    // Preflight fail issue shape for UX copy
    final failIssue = const CommercialPreflightIssue(
      code: 'WIBC_REQUIRED',
      fieldPath: 'workInstructionBrief.reasonsToPay',
      severity: CommercialIssueSeverity.error,
      userMessageKo: '고객이 돈을 지불할 이유가 비어 있습니다.',
      developerDetail: 'reasonsToPay empty',
      studioStepHint: "STEP 4 '고객 가치'에서 내용을 확인해 주세요.",
    );
    expect(failIssue.userMessageKo, contains('지불할 이유'));
    expect(failIssue.studioStepHint, contains('STEP 4'));

    final dir = Directory('test/support/studio_render_manifest');
    dir.createSync(recursive: true);
    final file = File('${dir.path}/render_manifest.json');
    final payload = {
      'generatedAt': '2026-09-04T12:40:00+09:00',
      'policy': 'hash_manifest_only_no_binary_commit',
      'remoteDeliveryCalls': 0,
      'cases': manifestEntries,
      'counts': {'cases': manifestEntries.length, 'overflowTotal': 0},
    };
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
    expect(file.existsSync(), isTrue);
    expect(manifestEntries.length, greaterThan(50));
  });

  testWidgets('disabled send reason is textual not color-only', (tester) async {
    final view = WorkInstructionDeliveryPresentation.resolve(
      plan: null,
      validation: null,
      agents: const [],
      transferBusy: false,
      localCommercialValidated: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Step7DeliveryPanel(view: view)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('로컬 검증'), findsWidgets);
    // Semantics / text present for disabled reason
    expect(view.buttonLabel, isNotEmpty);
  });
}
