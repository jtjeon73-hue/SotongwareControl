import '../models/remote_e2e_sample.dart';
import '../models/sotong24_remote_models.dart';

/// AI 제작공정 화면 전용 표시 로직 (Firestore/API contract 변경 없음).
class Sotong24WorkshopPresentation {
  Sotong24WorkshopPresentation._();

  /// TEST 세부 종류.
  static WorkshopTestKind testKind(Sotong24RemoteProject project) {
    final id = project.projectId.trim();
    final title = project.title.trim();
    if (RemoteCodexUnattendedMarkers.isCodexTestInstructionId(id) ||
        RemoteCodexUnattendedMarkers.isCodexTestTitle(title)) {
      return WorkshopTestKind.codex;
    }
    if (RemoteCursorAutostartMarkers.isCursorTestInstructionId(id) ||
        RemoteCursorAutostartMarkers.isCursorTestTitle(title)) {
      return WorkshopTestKind.cursor;
    }
    if (RemoteE2eSampleMarkers.isTestInstructionId(id) ||
        RemoteE2eSampleMarkers.isTestTitle(title)) {
      return WorkshopTestKind.e2e;
    }
    return WorkshopTestKind.none;
  }

  static bool isTestProject(Sotong24RemoteProject project) =>
      testKind(project) != WorkshopTestKind.none;

  /// 카드/상세 제목 (사용자 SSOT).
  static String displayTitle(Sotong24RemoteProject project) {
    final t = project.title.trim();
    final kind = testKind(project);
    if (kind == WorkshopTestKind.none) {
      return t.isEmpty ? '(제목 없음)' : t;
    }
    if (t.startsWith('[TEST]') && t.length > 7 && !_isVagueTestTitle(t)) {
      return t;
    }
    switch (kind) {
      case WorkshopTestKind.codex:
        return RemoteCodexUnattendedMarkers.sampleTitle;
      case WorkshopTestKind.cursor:
        return RemoteCursorAutostartMarkers.sampleTitle;
      case WorkshopTestKind.e2e:
        if (t.isEmpty || _isVagueTestTitle(t)) {
          return '[TEST] 단계진행 E2E';
        }
        return t.startsWith('[TEST]') ? t : '[TEST] $t';
      case WorkshopTestKind.none:
        return t.isEmpty ? '(제목 없음)' : t;
    }
  }

  static String testKindBadgeLabel(WorkshopTestKind kind) {
    switch (kind) {
      case WorkshopTestKind.codex:
        return 'Codex TEST';
      case WorkshopTestKind.cursor:
        return 'Cursor TEST';
      case WorkshopTestKind.e2e:
        return 'E2E TEST';
      case WorkshopTestKind.none:
        return 'TEST';
    }
  }

  static String effectiveStatus(Sotong24RemoteProject project) =>
      Sotong24UserFacingStatus.effective(project);

  static String statusLabelKo(Sotong24RemoteProject project) =>
      project.userFacingStatusLabel;

  static bool showApprovalActions(Sotong24RemoteProject project) =>
      project.showApprovalActions;

  static String currentStageLine(Sotong24RemoteProject project) {
    if (effectiveStatus(project) == Sotong24WorkStatus.completed) {
      final n = project.totalStages > 0
          ? project.totalStages
          : project.currentStage;
      return '전체 $n단계 완료';
    }
    final n = project.currentStage;
    if (n <= 0) return '단계 정보 없음';
    final name = project.currentStageDoc?.stageName.trim() ?? '';
    if (name.isEmpty) return '$n단계';
    return '$n단계 · $name';
  }

  static String overallProgressLine(Sotong24RemoteProject project) {
    final pct = project.overallProgressPercent;
    if (effectiveStatus(project) == Sotong24WorkStatus.completed ||
        pct >= 100) {
      return '전체 진행률 100%';
    }
    return '전체 진행률 $pct%';
  }

  /// Agent가 revision을 보고한 경우에만 표시. 없으면 빈 문자열.
  static String revisionLine(Sotong24RemoteProject project) {
    final r = project.currentStageDoc?.revision ?? 0;
    if (r <= 0) return '';
    return '결과 버전 r$r';
  }

  static String listProgressSummary(Sotong24RemoteProject project) {
    return '${currentStageLine(project)}\n${overallProgressLine(project)}';
  }

  static String nowTodoHeadline(Sotong24RemoteProject project) =>
      project.nowTodoHeadline();

  static bool _isVagueTestTitle(String title) {
    final t = title.trim().toLowerCase();
    return t == 'e2e' ||
        t == '[test] e2e' ||
        t == 'test' ||
        t == '[test]' ||
        t == '테스트' ||
        t == '[test] 테스트';
  }
}

enum WorkshopTestKind { none, codex, cursor, e2e }
