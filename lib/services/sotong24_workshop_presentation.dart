import '../models/artifact_type.dart';
import '../models/remote_e2e_sample.dart';
import '../models/sotong24_remote_models.dart';

class Sotong24FinalPdfArtifact {
  const Sotong24FinalPdfArtifact({
    required this.stageId,
    required this.revision,
    required this.viewUrl,
  });

  final String stageId;
  final int revision;
  final String viewUrl;
}

/// AI 제작공정 화면 전용 표시 로직 (Firestore/API contract 변경 없음).
class Sotong24WorkshopPresentation {
  Sotong24WorkshopPresentation._();

  /// TEST 세부 종류.
  static WorkshopTestKind testKind(Sotong24RemoteProject project) {
    final id = project.projectId.trim();
    final title = project.title.trim();
    if (project.isTest || project.environment == 'test') {
      if (RemoteCodexUnattendedMarkers.isCodexTestInstructionId(id)) {
        return WorkshopTestKind.codex;
      }
      if (RemoteCursorAutostartMarkers.isCursorTestInstructionId(id)) {
        return WorkshopTestKind.cursor;
      }
      return WorkshopTestKind.e2e;
    }
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

  /// 운영 화면에 노출할 실제 작업 (데모·TEST·불완전 제외).
  static List<Sotong24RemoteProject> operationalProjects(
    Iterable<Sotong24RemoteProject> projects,
  ) {
    return projects
        .where((p) => !p.isDemo && !p.isIncompleteListing && !isTestProject(p))
        .toList();
  }

  static bool hasOperationalWork(Iterable<Sotong24RemoteProject> projects) =>
      operationalProjects(projects).isNotEmpty;

  /// Viewer와 attachment download가 동일한 최종 PDF 객체를 사용하도록
  /// stage/revision/url을 한 번에 해석한다.
  static Sotong24FinalPdfArtifact? finalPdfArtifact(
    Sotong24RemoteProject project,
  ) {
    final candidates = <Sotong24FinalPdfArtifact>[];
    for (final stage in project.stages) {
      final result = _finalPdfUrl(stage.resultUrl);
      final preview = _finalPdfUrl(stage.previewUrl);
      final url = result ?? preview;
      if (url == null) continue;
      candidates.add(
        Sotong24FinalPdfArtifact(
          stageId: stage.stageId,
          revision: stage.revision > 0
              ? stage.revision
              : (project.finalRevision > 0 ? project.finalRevision : 1),
          viewUrl: url,
        ),
      );
    }
    if (candidates.isEmpty) return null;
    for (final artifact in candidates.reversed) {
      if (artifact.revision == project.finalRevision) return artifact;
    }
    return candidates.last;
  }

  static String? _finalPdfUrl(String raw) {
    final value = raw.trim();
    if (!Sotong24RemoteStage.isOpenableHttpUrl(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.last.toLowerCase() == 'final_ebook.pdf'
        ? value
        : null;
  }

  /// `sotong24work_projects/{instructionId}` 와 동일한 운영 프로젝트만.
  static Sotong24RemoteProject? projectForInstruction(
    Iterable<Sotong24RemoteProject> projects,
    String instructionId,
  ) {
    final id = instructionId.trim();
    if (id.isEmpty) return null;
    for (final p in operationalProjects(projects)) {
      if (p.projectId.trim() == id) return p;
    }
    return null;
  }

  static Sotong24RemoteProject? defaultFocusProject(
    Iterable<Sotong24RemoteProject> projects,
  ) {
    final real = operationalProjects(projects);
    if (real.isEmpty) return null;
    for (final p in real) {
      if (p.userFacingStatus == Sotong24WorkStatus.awaitingApproval) {
        return p;
      }
    }
    for (final p in real) {
      if (p.userFacingStatus != Sotong24WorkStatus.completed) return p;
    }
    return real.first;
  }

  /// `focusInstructionId`가 있으면 그 프로젝트만. 없으면 대시보드 기본 포커스.
  /// 지정 id의 프로젝트가 아직 없으면 이전 작업으로 fallback하지 않는다.
  static WorkshopFocusResolution resolveFocus({
    required Iterable<Sotong24RemoteProject> projects,
    String? focusInstructionId,
  }) {
    final id = focusInstructionId?.trim() ?? '';
    if (id.isEmpty) {
      return WorkshopFocusResolution(
        waitingForExactProject: false,
        project: defaultFocusProject(projects),
      );
    }
    final match = projectForInstruction(projects, id);
    if (match != null) {
      return WorkshopFocusResolution(
        waitingForExactProject: false,
        project: match,
      );
    }
    return const WorkshopFocusResolution(
      waitingForExactProject: true,
      project: null,
    );
  }

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

  static String businessTypeLabel(String productType) {
    switch (ArtifactType.normalize(productType)) {
      case ArtifactType.site:
        return '지식사이트';
      case ArtifactType.promoSite:
        return '마케팅사이트';
      default:
        return ArtifactType.labelKo(productType);
    }
  }

  /// Agent가 보고한 workDurationMs만 사용. 승인 대기·startedAt~completedAt 추정 금지.
  static Duration? stageWorkDuration(Sotong24RemoteStage stage) {
    if (stage.workDurationMs <= 0) return null;
    return Duration(milliseconds: stage.workDurationMs);
  }

  static String formatWorkDurationMs(int ms) {
    if (ms <= 0) return '';
    final d = Duration(milliseconds: ms);
    if (d.inHours >= 1) {
      final m = d.inMinutes.remainder(60);
      final sec = d.inSeconds.remainder(60);
      if (m > 0 && sec > 0) return '${d.inHours}시간 $m분 $sec초';
      if (m > 0) return '${d.inHours}시간 $m분';
      return '${d.inHours}시간';
    }
    if (d.inMinutes >= 1) {
      final sec = d.inSeconds.remainder(60);
      if (sec > 0) return '${d.inMinutes}분 $sec초';
      return '${d.inMinutes}분';
    }
    return '${d.inSeconds}초';
  }

  static String stageDurationLine(Sotong24RemoteStage stage) {
    final label = formatWorkDurationMs(stage.workDurationMs);
    if (label.isEmpty) return '';
    return '작업시간 $label';
  }

  static String stageRevisionLine(Sotong24RemoteStage stage) {
    if (stage.revision <= 0) return '';
    return '결과 버전 r${stage.revision}';
  }

  static String validationFailureSummary(String reason) {
    switch (reason.trim()) {
      case 'problem_validate_interview_evidence_missing':
        return '실제 인터뷰 근거가 확인되지 않음';
      case 'problem_validate_interview_status_missing':
        return '직접 인터뷰 실시 여부가 명시되지 않음';
      case 'problem_validate_interview_section_missing':
        return 'P01/P02 검증 프로필이 누락됨';
      case 'problem_validate_public_sources_insufficient':
        return '공개 출처가 부족함';
      case 'problem_validate_source_rows_insufficient':
        return '출처 ID와 URL을 연결한 공개 출처 표가 부족함';
      case 'problem_validate_source_domains_insufficient':
        return '독립적인 공개 출처 도메인이 부족함';
      case 'problem_validate_source_url_invalid':
        return 'placeholder 또는 유효하지 않은 출처 URL이 포함됨';
      case 'problem_validate_problem_signals_insufficient':
        return '고객 문제 신호가 부족함';
      case 'problem_validate_metadata_missing':
        return '검증 메타데이터가 누락됨';
      case 'problem_validate_problem_summary_missing':
        return '고객 문제 요약이 누락됨';
      case 'problem_validate_frequency_intensity_missing':
        return '문제 빈도 또는 강도 근거가 누락됨';
      case 'problem_validate_comparison_missing':
        return '인터뷰 비교표가 누락됨';
      case 'problem_validate_hypotheses_missing':
        return '핵심 가설 검증이 누락됨';
      case 'problem_validate_positioning_missing':
        return '수정 포지셔닝이 누락됨';
      case 'output_missing':
        return '결과 파일이 없음';
      case 'output_empty':
        return '결과 파일이 비어 있음';
      case 'output_too_short':
      case 'output_too_few_lines':
        return '결과 내용이 완료 기준보다 짧음';
      default:
        return reason.trim().isEmpty ? '검증 기준을 통과하지 못함' : '결과 형식 또는 필수 근거 미충족';
    }
  }

  static String retryCountdownLine(Sotong24RemoteStage stage, {DateTime? now}) {
    final at = DateTime.tryParse(stage.nextRetryAt);
    if (at == null) return '';
    final remaining = at.toUtc().difference((now ?? DateTime.now()).toUtc());
    if (remaining.isNegative || remaining == Duration.zero) {
      return '다음 재시도 시작 대기 중';
    }
    return '다음 재시도까지 ${remaining.inSeconds + (remaining.inMilliseconds % 1000 == 0 ? 0 : 1)}초';
  }

  /// 단계 workDurationMs 합. 데이터가 없으면 빈 문자열 (가짜 누적 금지).
  static String totalWorkDurationLine(Sotong24RemoteProject project) {
    var totalMs = 0;
    var any = false;
    for (final s in project.stages) {
      if (s.workDurationMs <= 0) continue;
      totalMs += s.workDurationMs;
      any = true;
    }
    if (!any) return '';
    return '전체 누적 작업시간: ${formatWorkDurationMs(totalMs)}';
  }

  static String stageTimingDetailNote(Sotong24RemoteStage stage) {
    final start = stage.startedAt.trim();
    final end = stage.completedAt.trim();
    if (start.isEmpty && end.isEmpty && stage.workDurationMs <= 0) {
      return '작업시간 기록 없음';
    }
    final lines = <String>[];
    if (start.isNotEmpty) lines.add('시작 ${_formatStageTimestamp(start)}');
    if (end.isNotEmpty) lines.add('완료 ${_formatStageTimestamp(end)}');
    final dur = stageDurationLine(stage);
    if (dur.isNotEmpty) {
      lines.add(dur.replaceFirst('작업시간 ', '누적 실제 작업시간 '));
    }
    if (stage.revision > 0) lines.add(stageRevisionLine(stage));
    return lines.join('\n');
  }

  static String _formatStageTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final month = local.month;
    final day = local.day;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  static String listProgressSummary(Sotong24RemoteProject project) {
    final lines = <String>[
      currentStageLine(project),
      overallProgressLine(project),
    ];
    final rev = revisionLine(project);
    if (rev.isNotEmpty) lines.add(rev);
    final stage = project.currentStageDoc;
    if (stage != null) {
      final duration = stageDurationLine(stage);
      if (duration.isNotEmpty) lines.add(duration);
    }
    return lines.join('\n');
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

class WorkshopFocusResolution {
  const WorkshopFocusResolution({
    required this.waitingForExactProject,
    this.project,
  });

  final Sotong24RemoteProject? project;
  final bool waitingForExactProject;

  bool get hasExactProject => project != null;
}
