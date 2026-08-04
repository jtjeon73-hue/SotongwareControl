/// 제작 포트폴리오 데이터 모델 (로컬 SharedPreferences, Firestore 불필요).
library;

import 'artifact_type.dart';

export 'artifact_type.dart';

/// artifact → 목표 제작 수 (기본 50, 상한 아님).
class PortfolioArtifactGoals {
  const PortfolioArtifactGoals({this.targets = const {}});

  static const defaultTarget = 50;

  static const defaultTargets = {
    ArtifactType.app: defaultTarget,
    ArtifactType.ebook: defaultTarget,
    ArtifactType.contents: defaultTarget,
    ArtifactType.site: defaultTarget,
    ArtifactType.promoSite: defaultTarget,
  };

  final Map<String, int> targets;

  int goalFor(String artifact) {
    final key = ArtifactType.normalize(artifact);
    return targets[key] ?? defaultTargets[key] ?? defaultTarget;
  }

  PortfolioArtifactGoals setGoal(String artifact, int count) {
    final key = ArtifactType.normalize(artifact);
    final next = Map<String, int>.from(targets);
    next[key] = count;
    return copyWith(targets: next);
  }

  PortfolioArtifactGoals copyWith({Map<String, int>? targets}) {
    return PortfolioArtifactGoals(targets: targets ?? this.targets);
  }

  Map<String, dynamic> toJson() => {'targets': targets};

  factory PortfolioArtifactGoals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PortfolioArtifactGoals();
    final raw = json['targets'];
    if (raw is! Map) {
      return const PortfolioArtifactGoals(targets: defaultTargets);
    }
    final parsed = <String, int>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is int) {
        parsed[ArtifactType.normalize(entry.key.toString())] = v;
      } else if (v is num) {
        parsed[ArtifactType.normalize(entry.key.toString())] = v.toInt();
      }
    }
    return PortfolioArtifactGoals(targets: {...defaultTargets, ...parsed});
  }
}

/// 포트폴리오 항목 진행 상태.
class PortfolioStatus {
  static const ideaCandidate = 'idea_candidate';
  static const researchNeeded = 'research_needed';
  static const planningCandidate = 'planning_candidate';
  static const planning = 'planning';
  static const productionApproved = 'production_approved';
  static const transferred24work = 'transferred_24work';
  static const inProduction = 'in_production';
  static const reviewRevise = 'review_revise';
  static const launchReady = 'launch_ready';
  static const launchedOps = 'launched_ops';
  static const performanceWatch = 'performance_watch';
  static const improve = 'improve';
  static const archived = 'archived';

  static const all = [
    ideaCandidate,
    researchNeeded,
    planningCandidate,
    planning,
    productionApproved,
    transferred24work,
    inProduction,
    reviewRevise,
    launchReady,
    launchedOps,
    performanceWatch,
    improve,
    archived,
  ];

  static String normalize(String raw) {
    if (raw.isEmpty) return ideaCandidate;
    if (all.contains(raw)) return raw;
    return raw;
  }

  static String labelKo(String status) {
    switch (normalize(status)) {
      case ideaCandidate:
        return '아이디어 후보';
      case researchNeeded:
        return '조사 필요';
      case planningCandidate:
        return '기획 후보';
      case planning:
        return '기획 중';
      case productionApproved:
        return '제작 승인';
      case transferred24work:
        return '24워크 전달';
      case inProduction:
        return '제작 중';
      case reviewRevise:
        return '검토·수정';
      case launchReady:
        return '출시 준비';
      case launchedOps:
        return '출시·운영';
      case performanceWatch:
        return '성과 관찰';
      case improve:
        return '개선';
      case archived:
        return '보관';
      default:
        return status;
    }
  }

  static bool isCandidate(String status) {
    final s = normalize(status);
    return s == ideaCandidate || s == researchNeeded || s == planningCandidate;
  }

  static bool isPlanned(String status) {
    final s = normalize(status);
    return s == planning || s == productionApproved;
  }

  static bool isInProduction(String status) {
    final s = normalize(status);
    return s == transferred24work || s == inProduction || s == reviewRevise;
  }

  static bool isLaunched(String status) {
    final s = normalize(status);
    return s == launchReady ||
        s == launchedOps ||
        s == performanceWatch ||
        s == improve;
  }

  static bool isTerminal(String status) {
    final s = normalize(status);
    return s == archived || s == launchedOps || s == performanceWatch;
  }
}

/// 점수 근거 출처.
class PortfolioEvidenceSource {
  static const aiEstimate = 'ai_estimate';
  static const userJudgment = 'user_judgment';
  static const externalNeeded = 'external_needed';

  static String labelKo(String source) {
    switch (source) {
      case aiEstimate:
        return 'AI 추정';
      case userJudgment:
        return '사용자 판단';
      case externalNeeded:
        return '외부 근거 필요';
      default:
        return source;
    }
  }
}

/// 7개 차원 점수 + 가중 총점.
class PortfolioScoreBreakdown {
  const PortfolioScoreBreakdown({
    this.chairmanInterest = 0,
    this.futureNeed = 0,
    this.marketability = 0,
    this.necessity = 0,
    this.differentiation = 0,
    this.monetizationPotential = 0,
    this.buildability = 0,
    this.total = 0,
    this.reasons = const [],
    this.cautions = const [],
    this.evidenceSource = PortfolioEvidenceSource.userJudgment,
  });

  final int chairmanInterest;
  final int futureNeed;
  final int marketability;
  final int necessity;
  final int differentiation;
  final int monetizationPotential;
  final int buildability;
  final int total;
  final List<String> reasons;
  final List<String> cautions;
  final String evidenceSource;

  PortfolioScoreBreakdown copyWith({
    int? chairmanInterest,
    int? futureNeed,
    int? marketability,
    int? necessity,
    int? differentiation,
    int? monetizationPotential,
    int? buildability,
    int? total,
    List<String>? reasons,
    List<String>? cautions,
    String? evidenceSource,
  }) {
    return PortfolioScoreBreakdown(
      chairmanInterest: chairmanInterest ?? this.chairmanInterest,
      futureNeed: futureNeed ?? this.futureNeed,
      marketability: marketability ?? this.marketability,
      necessity: necessity ?? this.necessity,
      differentiation: differentiation ?? this.differentiation,
      monetizationPotential:
          monetizationPotential ?? this.monetizationPotential,
      buildability: buildability ?? this.buildability,
      total: total ?? this.total,
      reasons: reasons ?? this.reasons,
      cautions: cautions ?? this.cautions,
      evidenceSource: evidenceSource ?? this.evidenceSource,
    );
  }

  Map<String, dynamic> toJson() => {
    'chairmanInterest': chairmanInterest,
    'futureNeed': futureNeed,
    'marketability': marketability,
    'necessity': necessity,
    'differentiation': differentiation,
    'monetizationPotential': monetizationPotential,
    'buildability': buildability,
    'total': total,
    'reasons': reasons,
    'cautions': cautions,
    'evidenceSource': evidenceSource,
  };

  factory PortfolioScoreBreakdown.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PortfolioScoreBreakdown();
    return PortfolioScoreBreakdown(
      chairmanInterest: _int(json['chairmanInterest']),
      futureNeed: _int(json['futureNeed']),
      marketability: _int(json['marketability']),
      necessity: _int(json['necessity']),
      differentiation: _int(json['differentiation']),
      monetizationPotential: _int(json['monetizationPotential']),
      buildability: _int(json['buildability']),
      total: _int(json['total']),
      reasons: _stringList(json['reasons']),
      cautions: _stringList(json['cautions']),
      evidenceSource:
          json['evidenceSource']?.toString() ??
          PortfolioEvidenceSource.userJudgment,
    );
  }
}

class PostLaunchResult {
  const PostLaunchResult({
    required this.summary,
    required this.recordedAt,
    this.metrics = const {},
  });

  final String summary;
  final DateTime recordedAt;
  final Map<String, String> metrics;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'recordedAt': recordedAt.toIso8601String(),
    'metrics': metrics,
  };

  factory PostLaunchResult.fromJson(Map<String, dynamic> json) {
    final metricsRaw = json['metrics'];
    final metrics = <String, String>{};
    if (metricsRaw is Map) {
      for (final e in metricsRaw.entries) {
        metrics[e.key.toString()] = e.value?.toString() ?? '';
      }
    }
    return PostLaunchResult(
      summary: json['summary']?.toString() ?? '',
      recordedAt: _date(json['recordedAt']),
      metrics: metrics,
    );
  }
}

class ImproveArchiveEntry {
  const ImproveArchiveEntry({
    required this.action,
    required this.note,
    required this.at,
  });

  final String action;
  final String note;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'action': action,
    'note': note,
    'at': at.toIso8601String(),
  };

  factory ImproveArchiveEntry.fromJson(Map<String, dynamic> json) {
    return ImproveArchiveEntry(
      action: json['action']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      at: _date(json['at']),
    );
  }
}

class PortfolioItem {
  const PortfolioItem({
    required this.id,
    this.sequence = 0,
    this.title = '',
    this.artifactType = ArtifactType.undecided,
    this.topicCategory = '',
    this.oneLiner = '',
    this.topicReason = '',
    this.targetUsers = '',
    this.problem = '',
    this.mainDeliverables = const [],
    this.chairmanInterest = 0,
    this.futureNeed = 0,
    this.marketability = 0,
    this.necessity = 0,
    this.differentiation = 0,
    this.monetizationPotential = 0,
    this.buildability = 0,
    this.scoreBreakdown,
    this.priority = 0,
    this.recommendedTotalScore = 0,
    this.status = PortfolioStatus.ideaCandidate,
    this.planId,
    this.instructionId,
    this.transferStatus = '',
    this.githubUrl = '',
    this.publishUrl = '',
    required this.createdAt,
    required this.updatedAt,
    this.postLaunchResults = const [],
    this.improveArchiveHistory = const [],
    this.themeBundleId,
    this.notes = '',
  });

  final String id;
  final int sequence;
  final String title;
  final String artifactType;
  final String topicCategory;
  final String oneLiner;
  final String topicReason;
  final String targetUsers;
  final String problem;
  final List<String> mainDeliverables;
  final int chairmanInterest;
  final int futureNeed;
  final int marketability;
  final int necessity;
  final int differentiation;
  final int monetizationPotential;
  final int buildability;
  final PortfolioScoreBreakdown? scoreBreakdown;
  final int priority;
  final int recommendedTotalScore;
  final String status;
  final String? planId;
  final String? instructionId;
  final String transferStatus;
  final String githubUrl;
  final String publishUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PostLaunchResult> postLaunchResults;
  final List<ImproveArchiveEntry> improveArchiveHistory;
  final String? themeBundleId;
  final String notes;

  bool get isTestMarked => notes.contains('[TEST]');

  PortfolioItem copyWith({
    String? id,
    int? sequence,
    String? title,
    String? artifactType,
    String? topicCategory,
    String? oneLiner,
    String? topicReason,
    String? targetUsers,
    String? problem,
    List<String>? mainDeliverables,
    int? chairmanInterest,
    int? futureNeed,
    int? marketability,
    int? necessity,
    int? differentiation,
    int? monetizationPotential,
    int? buildability,
    PortfolioScoreBreakdown? scoreBreakdown,
    int? priority,
    int? recommendedTotalScore,
    String? status,
    String? planId,
    String? instructionId,
    String? transferStatus,
    String? githubUrl,
    String? publishUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PostLaunchResult>? postLaunchResults,
    List<ImproveArchiveEntry>? improveArchiveHistory,
    String? themeBundleId,
    String? notes,
  }) {
    return PortfolioItem(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      title: title ?? this.title,
      artifactType: artifactType ?? this.artifactType,
      topicCategory: topicCategory ?? this.topicCategory,
      oneLiner: oneLiner ?? this.oneLiner,
      topicReason: topicReason ?? this.topicReason,
      targetUsers: targetUsers ?? this.targetUsers,
      problem: problem ?? this.problem,
      mainDeliverables: mainDeliverables ?? this.mainDeliverables,
      chairmanInterest: chairmanInterest ?? this.chairmanInterest,
      futureNeed: futureNeed ?? this.futureNeed,
      marketability: marketability ?? this.marketability,
      necessity: necessity ?? this.necessity,
      differentiation: differentiation ?? this.differentiation,
      monetizationPotential:
          monetizationPotential ?? this.monetizationPotential,
      buildability: buildability ?? this.buildability,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      priority: priority ?? this.priority,
      recommendedTotalScore:
          recommendedTotalScore ?? this.recommendedTotalScore,
      status: status ?? this.status,
      planId: planId ?? this.planId,
      instructionId: instructionId ?? this.instructionId,
      transferStatus: transferStatus ?? this.transferStatus,
      githubUrl: githubUrl ?? this.githubUrl,
      publishUrl: publishUrl ?? this.publishUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      postLaunchResults: postLaunchResults ?? this.postLaunchResults,
      improveArchiveHistory:
          improveArchiveHistory ?? this.improveArchiveHistory,
      themeBundleId: themeBundleId ?? this.themeBundleId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sequence': sequence,
    'title': title,
    'artifactType': artifactType,
    'topicCategory': topicCategory,
    'oneLiner': oneLiner,
    'topicReason': topicReason,
    'targetUsers': targetUsers,
    'problem': problem,
    'mainDeliverables': mainDeliverables,
    'chairmanInterest': chairmanInterest,
    'futureNeed': futureNeed,
    'marketability': marketability,
    'necessity': necessity,
    'differentiation': differentiation,
    'monetizationPotential': monetizationPotential,
    'buildability': buildability,
    if (scoreBreakdown != null) 'scoreBreakdown': scoreBreakdown!.toJson(),
    'priority': priority,
    'recommendedTotalScore': recommendedTotalScore,
    'status': status,
    if (planId != null) 'planId': planId,
    if (instructionId != null) 'instructionId': instructionId,
    'transferStatus': transferStatus,
    'githubUrl': githubUrl,
    'publishUrl': publishUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'postLaunchResults': postLaunchResults.map((e) => e.toJson()).toList(),
    'improveArchiveHistory': improveArchiveHistory
        .map((e) => e.toJson())
        .toList(),
    if (themeBundleId != null) 'themeBundleId': themeBundleId,
    'notes': notes,
  };

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['scoreBreakdown'];
    PortfolioScoreBreakdown? breakdown;
    if (breakdownRaw is Map) {
      breakdown = PortfolioScoreBreakdown.fromJson(
        Map<String, dynamic>.from(breakdownRaw),
      );
    }
    return PortfolioItem(
      id: json['id']?.toString() ?? '',
      sequence: _int(json['sequence']),
      title: json['title']?.toString() ?? '',
      artifactType: ArtifactType.normalize(
        json['artifactType']?.toString() ?? ArtifactType.undecided,
      ),
      topicCategory: json['topicCategory']?.toString() ?? '',
      oneLiner: json['oneLiner']?.toString() ?? '',
      topicReason: json['topicReason']?.toString() ?? '',
      targetUsers: json['targetUsers']?.toString() ?? '',
      problem: json['problem']?.toString() ?? '',
      mainDeliverables: _stringList(json['mainDeliverables']),
      chairmanInterest: _int(json['chairmanInterest']),
      futureNeed: _int(json['futureNeed']),
      marketability: _int(json['marketability']),
      necessity: _int(json['necessity']),
      differentiation: _int(json['differentiation']),
      monetizationPotential: _int(json['monetizationPotential']),
      buildability: _int(json['buildability']),
      scoreBreakdown: breakdown,
      priority: _int(json['priority']),
      recommendedTotalScore: _int(json['recommendedTotalScore']),
      status: PortfolioStatus.normalize(
        json['status']?.toString() ?? PortfolioStatus.ideaCandidate,
      ),
      planId: json['planId']?.toString(),
      instructionId: json['instructionId']?.toString(),
      transferStatus: json['transferStatus']?.toString() ?? '',
      githubUrl: json['githubUrl']?.toString() ?? '',
      publishUrl: json['publishUrl']?.toString() ?? '',
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      postLaunchResults: _list(
        json['postLaunchResults'],
        PostLaunchResult.fromJson,
      ),
      improveArchiveHistory: _list(
        json['improveArchiveHistory'],
        ImproveArchiveEntry.fromJson,
      ),
      themeBundleId: json['themeBundleId']?.toString(),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class ThemeBundle {
  const ThemeBundle({
    required this.id,
    this.coreTopic = '',
    this.description = '',
    this.linkedProjectIds = const [],
    this.sharedMaterials = const [],
  });

  final String id;
  final String coreTopic;
  final String description;
  final List<String> linkedProjectIds;
  final List<String> sharedMaterials;

  ThemeBundle copyWith({
    String? id,
    String? coreTopic,
    String? description,
    List<String>? linkedProjectIds,
    List<String>? sharedMaterials,
  }) {
    return ThemeBundle(
      id: id ?? this.id,
      coreTopic: coreTopic ?? this.coreTopic,
      description: description ?? this.description,
      linkedProjectIds: linkedProjectIds ?? this.linkedProjectIds,
      sharedMaterials: sharedMaterials ?? this.sharedMaterials,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'coreTopic': coreTopic,
    'description': description,
    'linkedProjectIds': linkedProjectIds,
    'sharedMaterials': sharedMaterials,
  };

  factory ThemeBundle.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ThemeBundle(id: '');
    }
    return ThemeBundle(
      id: json['id']?.toString() ?? '',
      coreTopic: json['coreTopic']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      linkedProjectIds: _stringList(json['linkedProjectIds']),
      sharedMaterials: _stringList(json['sharedMaterials']),
    );
  }
}

class ArtifactPortfolioStats {
  const ArtifactPortfolioStats({
    required this.artifact,
    this.goal = PortfolioArtifactGoals.defaultTarget,
    this.candidates = 0,
    this.planned = 0,
    this.inProduction = 0,
    this.launched = 0,
    this.progress = 0,
    this.nextRecommended,
  });

  final String artifact;
  final int goal;
  final int candidates;
  final int planned;
  final int inProduction;
  final int launched;
  final int progress;
  final PortfolioItem? nextRecommended;
}

class PortfolioDashboardStats {
  const PortfolioDashboardStats({
    this.byArtifact = const {},
    this.nextRecommended = const [],
    this.actionNeeded = const [],
    this.transferWaiting = const [],
    this.reviewWaiting = const [],
    this.stalled = const [],
    this.launchedWithResults = const [],
  });

  final Map<String, ArtifactPortfolioStats> byArtifact;
  final List<PortfolioItem> nextRecommended;
  final List<PortfolioItem> actionNeeded;
  final List<PortfolioItem> transferWaiting;
  final List<PortfolioItem> reviewWaiting;
  final List<PortfolioItem> stalled;
  final List<PortfolioItem> launchedWithResults;
}

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return fallback;
}

List<String> _stringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList();
}

DateTime _date(dynamic v) {
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v) ?? DateTime.now();
  }
  return DateTime.now();
}

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
