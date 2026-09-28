import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/ebook_r1_package_manifest.dart';
import 'package:sotong_ware_control/models/instruction_contract.dart';
import 'package:sotong_ware_control/models/sotong24_human_approval_gate.dart';
import 'package:sotong_ware_control/models/sotong24_monitoring.dart';
import 'package:sotong_ware_control/models/sotong24_remote_models.dart';
import 'package:sotong_ware_control/services/sotong24_remote_repository.dart';

Map<String, dynamic> _art(String path, {bool ready = true}) => {
  'path': path,
  'fileName': path.split('/').last,
  'size': 10,
  'sha256': 'abc',
  'remoteStatus': ready ? 'grantReady' : 'error',
  'remoteReady': ready,
  'grantReady': ready,
  'remoteUrl': ready ? 'https://example.com/$path' : '',
};

Map<String, dynamic> _trustedR2Raw() => {
  'schemaVersion': 'ebookReviewPackage/v2',
  'contractVersion': 2,
  'revision': 'r2',
  'title': 'frozen r2 final',
  'reviewReady': true,
  'deliveryStatus': 'ready',
  'manifestSHA256': 'abc',
  'cover': _art('publish/revisions/r2/cover/cover.png'),
  'pdf': _art('publish/revisions/r2/book.pdf'),
  'epub': {
    ..._art('publish/revisions/r2/book.epub'),
    'sha256':
        '147d9ccc15bea8c5917296498a5dc8cbc30f85c9df9210f3730abe09c5fde3e6',
  },
  'qualityReport': _art(
    'publish/revisions/r2/pre_review_quality_report.json',
  ),
  'manifest': _art('publish/revisions/r2/package_manifest.json'),
  'quality': {'score': 95, 'criticalCount': 0, 'majorCount': 0},
  'toc': ['1'],
  'frozen': true,
  'immutablePath': 'publish/revisions/r2',
};

Sotong24RemoteStage _gate({
  required String stageId,
  required String status,
  required bool criteriaMet,
  required bool approvalRequired,
  String approvalStatus = ApprovalStatus.pending,
  String userAttention = '',
  int revision = 2,
  Map<String, dynamic>? package,
}) {
  return Sotong24RemoteStage(
    stageId: stageId,
    stageNumber: stageId == 'final_user_approval'
        ? 17
        : (stageId == 'package_user_review' ? 15 : 2),
    stageName: stageId,
    status: status,
    approvalRequired: approvalRequired,
    criteriaMet: criteriaMet,
    revision: revision,
    approvalStatus: approvalStatus,
    userAttention: userAttention,
    ebookReviewPackage: package,
  );
}

Sotong24RemoteProject _project({
  required Sotong24RemoteStage gate,
  String approvalMode = 'auto',
}) {
  return Sotong24RemoteProject(
    projectId: 'wi_plan_1789914868666',
    title: 'mandatory gate auto policy',
    productType: 'ebook',
    currentStage: gate.stageNumber,
    totalStages: 18,
    progress: 90,
    status: gate.status,
    approvalStatus: ApprovalStatus.pending,
    approvalMode: approvalMode,
    lastHeartbeat: DateTime.now().toUtc().toIso8601String(),
    stages: [
      gate,
      const Sotong24RemoteStage(
        stageId: 'publication_package',
        stageNumber: 18,
        stageName: '출시 준비 패키지',
        status: Sotong24WorkStatus.ready,
      ),
    ],
  );
}

void main() {
  group('mandatory human-gate vs approvalMode=auto', () {
    test('helper SSOT: monitoring delegates to Sotong24HumanApprovalGate', () {
      expect(
        Sotong24HumanApprovalGate.isMandatory('final_user_approval'),
        isTrue,
      );
      expect(
        Sotong24StageMonitoring.isHumanApprovalGateStage('final_user_approval'),
        isTrue,
      );
      expect(Sotong24HumanApprovalGate.isMandatory('idea_clarify'), isFalse);
      expect(
        Sotong24StageMonitoring.isHumanApprovalGateStage('idea_clarify'),
        isFalse,
      );
    });

    test(
      'A: auto + final_user_approval + empty userAttention → showApprovalActions',
      () {
        final project = _project(
          gate: _gate(
            stageId: 'final_user_approval',
            status: Sotong24WorkStatus.awaitingApproval,
            criteriaMet: true,
            approvalRequired: true,
            userAttention: '',
            package: _trustedR2Raw(),
          ),
        );
        expect(project.approvalMode, 'auto');
        expect(project.currentStageDoc!.userAttention, isEmpty);
        expect(project.showApprovalActions, isTrue);
      },
    );

    test(
      'B: auto + normal stage + empty userAttention → hide approval actions',
      () {
        final project = _project(
          gate: _gate(
            stageId: 'idea_clarify',
            status: Sotong24WorkStatus.awaitingApproval,
            criteriaMet: true,
            approvalRequired: true,
            userAttention: '',
          ),
        );
        expect(project.showApprovalActions, isFalse);
      },
    );

    test('C: mandatory gate + criteriaMet=false → false', () {
      final project = _project(
        gate: _gate(
          stageId: 'final_user_approval',
          status: Sotong24WorkStatus.awaitingApproval,
          criteriaMet: false,
          approvalRequired: true,
          package: _trustedR2Raw(),
        ),
      );
      expect(project.showApprovalActions, isFalse);
    });

    test('D: mandatory gate + approvalRequired=false → false', () {
      final project = _project(
        gate: _gate(
          stageId: 'final_user_approval',
          status: Sotong24WorkStatus.awaitingApproval,
          criteriaMet: true,
          approvalRequired: false,
          package: _trustedR2Raw(),
        ),
      );
      expect(project.showApprovalActions, isFalse);
    });

    test('E: mandatory gate + status != awaiting_approval → false', () {
      final project = _project(
        gate: _gate(
          stageId: 'final_user_approval',
          status: Sotong24WorkStatus.inProgress,
          criteriaMet: true,
          approvalRequired: true,
          package: _trustedR2Raw(),
        ),
      );
      expect(project.showApprovalActions, isFalse);
    });

    test('F: terminal approvalStatus → false', () {
      // Guard terminal set is approved + revision_requested (not rejected).
      for (final terminal in const [
        ApprovalStatus.approved,
        ApprovalStatus.revisionRequested,
      ]) {
        final project = _project(
          gate: _gate(
            stageId: 'final_user_approval',
            status: Sotong24WorkStatus.awaitingApproval,
            criteriaMet: true,
            approvalRequired: true,
            approvalStatus: terminal,
            package: _trustedR2Raw(),
          ),
        );
        expect(
          project.showApprovalActions,
          isFalse,
          reason: 'terminal=$terminal must hide actions',
        );
      }
    });

    test('G: authoritative r2 contract still wins for final gate', () {
      final r2 = EbookR1PackageManifest.fromEbookReviewPackage(_trustedR2Raw());
      expect(
        EbookPackageReviewContract.authoritativeFinalApprovalRevision(
          stageId: 'final_user_approval',
          stageRevision: 1,
          package: r2,
        ),
        2,
      );
      final project = _project(
        gate: _gate(
          stageId: 'final_user_approval',
          status: Sotong24WorkStatus.awaitingApproval,
          criteriaMet: true,
          approvalRequired: true,
          revision: 2,
          package: _trustedR2Raw(),
        ),
      );
      expect(project.showApprovalActions, isTrue);
      expect(project.currentStageDoc!.revision, 2);
    });

    test('H: showing actions alone does not create approval request', () async {
      final gate = _gate(
        stageId: 'final_user_approval',
        status: Sotong24WorkStatus.awaitingApproval,
        criteriaMet: true,
        approvalRequired: true,
        package: _trustedR2Raw(),
      );
      final project = _project(gate: gate);
      expect(project.showApprovalActions, isTrue);

      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [project],
      );
      addTearDown(repo.dispose);
      final before = await repo.getProject(project.projectId);
      expect(before!.showApprovalActions, isTrue);
      expect(before.approvalStatus, ApprovalStatus.pending);
      expect(before.currentStageDoc!.approvalStatus, ApprovalStatus.pending);
      // No approveStage call — visibility alone must not mutate approvals.
      final after = await repo.getProject(project.projectId);
      expect(after!.approvalStatus, ApprovalStatus.pending);
      expect(after.currentStageDoc!.approvalStatus, ApprovalStatus.pending);
      expect(after.currentStage, 17);
    });

    test('I: STEP18 stays ready — no auto advance from visibility', () async {
      final project = _project(
        gate: _gate(
          stageId: 'final_user_approval',
          status: Sotong24WorkStatus.awaitingApproval,
          criteriaMet: true,
          approvalRequired: true,
          package: _trustedR2Raw(),
        ),
      );
      expect(project.showApprovalActions, isTrue);
      final repo = Sotong24RemoteRepository(
        forceMemory: true,
        memorySeed: [project],
      );
      addTearDown(repo.dispose);
      final after = await repo.getProject(project.projectId);
      expect(after!.currentStage, 17);
      final step18 = after.stages.firstWhere(
        (s) => s.stageId == 'publication_package',
      );
      expect(step18.status, Sotong24WorkStatus.ready);
      expect(step18.status, isNot(Sotong24WorkStatus.inProgress));
    });

    test('J: STEP15 package_user_review auto still shows actions', () {
      final project = _project(
        gate: _gate(
          stageId: 'package_user_review',
          status: Sotong24WorkStatus.awaitingApproval,
          criteriaMet: true,
          approvalRequired: true,
          userAttention: '',
          package: _trustedR2Raw(),
        ),
      );
      expect(project.approvalMode, 'auto');
      expect(project.showApprovalActions, isTrue);
    });

    test('J: normal auto stage still hides without userAttention', () {
      final project = _project(
        gate: _gate(
          stageId: 'problem_validate',
          status: Sotong24WorkStatus.awaitingApproval,
          criteriaMet: true,
          approvalRequired: true,
          userAttention: '',
        ),
      );
      expect(project.showApprovalActions, isFalse);
    });
  });
}
