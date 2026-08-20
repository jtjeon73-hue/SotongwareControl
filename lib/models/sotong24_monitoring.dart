import 'sotong24_remote_models.dart';

enum Sotong24StageHealth {
  healthy,
  delayed,
  awaitingUser,
  inactive,
  offline,
  pausedQuota,
  pausedNetwork,
  stalled,
  error,
}

class Sotong24DurationRange {
  const Sotong24DurationRange({
    required this.min,
    required this.max,
    required this.sampleCount,
  });

  final Duration min;
  final Duration max;
  final int sampleCount;
}

class Sotong24MonitoringPolicy {
  const Sotong24MonitoringPolicy({
    this.onlineWithin = const Duration(minutes: 2),
    this.offlineAfter = const Duration(minutes: 10),
    this.noActivityAfter = const Duration(minutes: 15),
    this.defaultExpectedMax = const Duration(minutes: 8),
    this.minimumDurationSamples = 5,
    this.stageExpectedDurations = const {},
  });

  final Duration onlineWithin;
  final Duration offlineAfter;
  final Duration noActivityAfter;
  final Duration defaultExpectedMax;
  final int minimumDurationSamples;
  final Map<String, Sotong24DurationRange> stageExpectedDurations;

  factory Sotong24MonitoringPolicy.fromMap(Map<String, dynamic> map) {
    Duration seconds(String key, int fallback) {
      final value = map[key];
      final n = value is num ? value.toInt() : int.tryParse('$value');
      return Duration(seconds: n != null && n > 0 ? n : fallback);
    }

    final minimum = (map['minimumDurationSamples'] is num)
        ? (map['minimumDurationSamples'] as num).toInt()
        : 5;
    final ranges = <String, Sotong24DurationRange>{};
    final rawRanges = map['stageExpectedDurations'];
    if (rawRanges is Map) {
      for (final entry in rawRanges.entries) {
        final raw = entry.value;
        if (raw is! Map) continue;
        final min = raw['minSeconds'];
        final max = raw['maxSeconds'];
        final samples = raw['sampleCount'];
        if (min is num &&
            max is num &&
            samples is num &&
            min > 0 &&
            max >= min) {
          ranges['${entry.key}'] = Sotong24DurationRange(
            min: Duration(seconds: min.toInt()),
            max: Duration(seconds: max.toInt()),
            sampleCount: samples.toInt(),
          );
        }
      }
    }
    return Sotong24MonitoringPolicy(
      onlineWithin: seconds('onlineWithinSeconds', 120),
      offlineAfter: seconds('offlineAfterSeconds', 600),
      noActivityAfter: seconds('noActivityAfterSeconds', 900),
      defaultExpectedMax: seconds('defaultExpectedMaxSeconds', 480),
      minimumDurationSamples: minimum > 0 ? minimum : 5,
      stageExpectedDurations: ranges,
    );
  }

  Sotong24DurationRange? expectedRangeFor(String stageId) {
    final value = stageExpectedDurations[stageId];
    if (value == null || value.sampleCount < minimumDurationSamples) {
      return null;
    }
    return value;
  }
}

class Sotong24StageMonitoringSnapshot {
  const Sotong24StageMonitoringSnapshot({
    required this.health,
    required this.elapsed,
    required this.lastActivityAge,
    required this.heartbeatAge,
    required this.agentOnline,
    required this.activityLabel,
    this.approvalWaitAge,
    this.expectedRange,
  });

  final Sotong24StageHealth health;
  final Duration? elapsed;
  final Duration? lastActivityAge;
  final Duration? heartbeatAge;
  final bool agentOnline;
  final String activityLabel;
  final Duration? approvalWaitAge;
  final Sotong24DurationRange? expectedRange;

  String get healthLabel {
    switch (health) {
      case Sotong24StageHealth.healthy:
        return '정상 진행';
      case Sotong24StageHealth.delayed:
        return '예상보다 오래 걸림';
      case Sotong24StageHealth.awaitingUser:
        return '사용자 승인 대기';
      case Sotong24StageHealth.inactive:
        return '응답 확인 필요';
      case Sotong24StageHealth.offline:
        return 'Agent 오프라인';
      case Sotong24StageHealth.pausedQuota:
        return 'AI 사용량 초기화 대기';
      case Sotong24StageHealth.pausedNetwork:
        return '네트워크 복구 대기';
      case Sotong24StageHealth.stalled:
        return '작업 정체';
      case Sotong24StageHealth.error:
        return '오류';
    }
  }
}

class Sotong24StageMonitoring {
  static Sotong24StageMonitoringSnapshot evaluate({
    required Sotong24RemoteProject project,
    required Sotong24RemoteStage stage,
    Sotong24MonitoringPolicy policy = const Sotong24MonitoringPolicy(),
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    Duration? age(String value) {
      final parsed = DateTime.tryParse(value)?.toUtc();
      if (parsed == null) return null;
      final difference = clock.difference(parsed);
      return difference.isNegative ? Duration.zero : difference;
    }

    final heartbeatAge = age(project.lastHeartbeat);
    final activityAge = age(
      stage.lastActivityAt.isNotEmpty
          ? stage.lastActivityAt
          : project.lastActivityAt,
    );
    final startedAt = DateTime.tryParse(
      stage.startedAt.isNotEmpty ? stage.startedAt : project.startedAt,
    )?.toUtc();
    final completedAt = DateTime.tryParse(stage.completedAt)?.toUtc();
    final elapsed = startedAt == null
        ? null
        : ((completedAt ?? clock).difference(startedAt).isNegative
              ? Duration.zero
              : (completedAt ?? clock).difference(startedAt));
    final approvalWaitAge = age(
      stage.completedAt.isNotEmpty ? stage.completedAt : stage.lastActivityAt,
    );
    final online = heartbeatAge != null && heartbeatAge <= policy.offlineAfter;
    final status = Sotong24UserFacingStatus.normalize(stage.status);
    late final Sotong24StageHealth health;
    if (status == Sotong24WorkStatus.pausedQuota) {
      health = Sotong24StageHealth.pausedQuota;
    } else if (status == Sotong24WorkStatus.pausedNetwork) {
      health = Sotong24StageHealth.pausedNetwork;
    } else if (status == Sotong24WorkStatus.stalled) {
      health = Sotong24StageHealth.stalled;
    } else if (status == Sotong24WorkStatus.error ||
        status == Sotong24WorkStatus.aiProcessFailed ||
        status == Sotong24WorkStatus.resultValidationFailed ||
        status == Sotong24WorkStatus.stageTransitionFailed ||
        stage.errorMessage.isNotEmpty) {
      health = Sotong24StageHealth.error;
    } else if (status == Sotong24WorkStatus.awaitingApproval) {
      health = Sotong24StageHealth.awaitingUser;
    } else if (!online) {
      health = Sotong24StageHealth.offline;
    } else if (activityAge == null || activityAge > policy.noActivityAfter) {
      health = Sotong24StageHealth.inactive;
    } else {
      final range = policy.expectedRangeFor(stage.stageId);
      final max = range?.max ?? policy.defaultExpectedMax;
      health = elapsed != null && elapsed > max
          ? Sotong24StageHealth.delayed
          : Sotong24StageHealth.healthy;
    }
    return Sotong24StageMonitoringSnapshot(
      health: health,
      elapsed: elapsed,
      lastActivityAge: activityAge,
      heartbeatAge: heartbeatAge,
      agentOnline: online,
      activityLabel: activityLabel(stage.activityState),
      approvalWaitAge: status == Sotong24WorkStatus.awaitingApproval
          ? approvalWaitAge
          : null,
      expectedRange: policy.expectedRangeFor(stage.stageId),
    );
  }

  static String activityLabel(String state) {
    switch (state) {
      case 'ai_requesting':
        return 'AI 작업 요청 중';
      case 'codex_running':
        return 'Codex 작업 중';
      case 'result_validating':
        return '결과 검증 중';
      case 'result_uploading':
        return '결과물 업로드 중';
      case 'approval_preparing':
        return '승인 대기 준비 중';
      case 'worker_dispatch_waiting':
        return '작업 worker 시작 대기';
      case 'stage_transitioning':
        return '다음 단계 전환 중';
      case 'auto_approval':
        return '검증 완료 · 자동 승인 중';
      case 'paused_quota':
        return 'AI 사용량 초기화 대기';
      case 'paused_network':
        return '네트워크 복구 대기';
      case 'stalled':
        return '작업 정체 감지';
      case 'ai_process_failed':
        return 'AI 실행 실패';
      case 'result_validation_failed':
        return '결과 검증 최종 실패';
      case 'validation_retry_waiting':
        return '결과 검증 자동 재시도 대기';
      case 'stage_transition_failed':
        return '단계 전환 실패';
      default:
        return state.trim().isEmpty ? '작업 worker 시작 대기' : '작업 상태 동기화 중';
    }
  }

  static String compactDuration(Duration? value) {
    if (value == null) return '기록 없음';
    final seconds = value.inSeconds;
    if (seconds < 60) return '$seconds초';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes < 60) {
      return '$minutes분 ${remainder.toString().padLeft(2, '0')}초';
    }
    final hours = minutes ~/ 60;
    return '$hours시간 ${minutes % 60}분';
  }

  static String relative(Duration? value) {
    if (value == null) return '활동 기록 없음';
    if (value.inSeconds < 60) return '${value.inSeconds}초 전';
    if (value.inMinutes < 60) return '${value.inMinutes}분 전';
    return '${value.inHours}시간 전';
  }
}
