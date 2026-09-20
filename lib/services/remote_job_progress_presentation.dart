import '../models/remote_agent_models.dart';

/// 원격 Job 진행률 표시·진단 (가짜 진행률 계산 금지).
class RemoteJobProgressPresentation {
  RemoteJobProgressPresentation._();

  static const _activeOrInterrupted = {
    'running',
    'claimed',
    'reworking',
    'waiting_approval',
    'awaiting_user_approval',
    'pending_review',
    'revision_requested',
    'result_validation_retrying',
    'result_validation_failed',
    'paused',
    'paused_quota',
    'paused_network',
    'stalled',
    'ai_process_failed',
    'stage_transition_failed',
    'failed',
    'error',
  };

  static int resolvedStageNumber(
    RemoteJobDoc job,
    List<RemoteStageDoc> stages,
  ) {
    final fromStages = stages
        .where(
          (s) =>
              s.stageId.isNotEmpty &&
              s.stageId == job.currentStage &&
              s.stageNumber > 0,
        )
        .map((s) => s.stageNumber);
    if (fromStages.isNotEmpty) return fromStages.first;
    final maxActive = stages
        .where((s) => _activeOrInterrupted.contains(s.status))
        .map((s) => s.stageNumber)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (maxActive > 0) return maxActive;
    return 0;
  }

  /// currentStage가 진행됐는데 job.progress가 0에 고정된 경우 등.
  static bool hasProgressInconsistency(
    RemoteJobDoc job,
    List<RemoteStageDoc> stages,
  ) {
    final stageNum = resolvedStageNumber(job, stages);
    if (job.progress <= 0 && stageNum >= 2) return true;
    if (job.progress <= 0 &&
        job.currentStage.trim().isNotEmpty &&
        job.status != 'queued' &&
        job.status != 'claimed') {
      return true;
    }
    return hasStageStatusConflict(job, stages);
  }

  /// 동일 Job에서 이전 stage가 running인데 currentStage는 이후 단계인 모순.
  static bool hasStageStatusConflict(
    RemoteJobDoc job,
    List<RemoteStageDoc> stages,
  ) {
    final currentNum = resolvedStageNumber(job, stages);
    if (currentNum <= 0 || stages.isEmpty) return false;
    for (final s in stages) {
      if (s.stageNumber <= 0 || s.stageNumber >= currentNum) continue;
      if (s.status == 'running' || s.status == 'claimed') return true;
    }
    final currentId = job.currentStage.trim();
    if (currentId.isEmpty) return false;
    var nonTerminalBeyondCurrent = 0;
    for (final s in stages) {
      if (s.stageNumber <= currentNum) continue;
      if (_activeOrInterrupted.contains(s.status) && s.status != 'ready') {
        nonTerminalBeyondCurrent++;
      }
    }
    return nonTerminalBeyondCurrent > 0;
  }

  /// 정상처럼 보이는 가짜 %를 만들지 않는다. 불일치 시 진단 문구만.
  static String? inconsistencyBanner(
    RemoteJobDoc job,
    List<RemoteStageDoc> stages,
  ) {
    if (!hasProgressInconsistency(job, stages)) return null;
    final stage = job.currentStage.trim().isEmpty ? '—' : job.currentStage;
    final parts = <String>[
      '상태 불일치/진단 필요',
      'currentStage=$stage',
      'progress=${job.progress}%',
    ];
    if (hasStageStatusConflict(job, stages)) {
      parts.add('단계 상태가 서로 모순됨');
    }
    return '${parts.join(' · ')}. 가짜 진행률을 표시하지 않습니다.';
  }

  /// 진행률 바 value. 불일치·미보고(0)면 null이 아니라 표시 자체를 막도록
  /// [shouldShowProgressBar]와 함께 사용.
  static double? progressBarValue(
    RemoteJobDoc job,
    List<RemoteStageDoc> stages,
  ) {
    if (hasProgressInconsistency(job, stages)) return null;
    if (job.totalStages <= 0) return null;
    if (job.progress <= 0) return null;
    return (job.progress.clamp(0, 100)) / 100.0;
  }

  static bool shouldShowProgressBar(
    RemoteJobDoc job,
    List<RemoteStageDoc> stages,
  ) {
    return progressBarValue(job, stages) != null;
  }

  static String progressCaption(RemoteJobDoc job, List<RemoteStageDoc> stages) {
    if (hasProgressInconsistency(job, stages)) {
      return '전체 진행률 보고값 ${job.progress}% (상태 불일치 — 진단 필요)';
    }
    return '전체 진행률 ${job.progress}%';
  }
}
