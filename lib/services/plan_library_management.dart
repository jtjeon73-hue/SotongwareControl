import '../models/business_planning.dart';

/// 중복 후보 그룹 (자동 삭제 없음 — UI에서 사용자 승인 필요).
class PlanDuplicateGroup {
  const PlanDuplicateGroup({
    required this.key,
    required this.title,
    required this.plans,
    required this.strongChecksumMatch,
  });

  final String key;
  final String title;
  final List<BusinessPlanDocument> plans;
  final bool strongChecksumMatch;

  BusinessPlanDocument get newest {
    final sorted = List<BusinessPlanDocument>.from(plans)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.first;
  }
}

/// 영구삭제 전 강한 경고가 필요한 사유.
class PlanDeleteWarning {
  const PlanDeleteWarning({
    required this.planId,
    required this.reasons,
  });

  final String planId;
  final List<String> reasons;

  bool get hasStrongWarning => reasons.isNotEmpty;
}

/// Planning Library 전용 — DevWorkDoc/Inbox/외부 파일과 무관.
class PlanLibraryManagement {
  /// 내용 지문. instruction/전송 checksum 우선, 없으면 빈 문자열.
  static String contentChecksumOf(BusinessPlanDocument plan) {
    final fromInstruction = plan.instruction?.checksum.trim() ?? '';
    if (fromInstruction.isNotEmpty) return fromInstruction;
    final fromTransfer = (plan.lastTransferChecksum ?? '').trim();
    if (fromTransfer.isNotEmpty) return fromTransfer;
    return '';
  }

  static String shortId(String id) {
    final t = id.trim();
    if (t.length <= 12) return t.isEmpty ? '-' : t;
    return '${t.substring(0, 8)}…';
  }

  /// 관리 필터 적용 (폴더·상태·수명주기).
  static List<BusinessPlanDocument> applyManageFilter(
    List<BusinessPlanDocument> plans,
    String filter, {
    Set<String>? duplicateCandidateIds,
    Duration staleAfter = const Duration(days: 30),
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    switch (filter) {
      case 'all':
        return plans
            .where((p) => !p.isLibraryTrashed)
            .toList();
      case 'in_progress':
        return plans
            .where(
              (p) =>
                  !p.isLibraryTrashed &&
                  PlanningStatus.normalize(p.status) ==
                      PlanningStatus.inProgress,
            )
            .toList();
      case 'instruction_created':
        return plans
            .where((p) {
              if (p.isLibraryTrashed) return false;
              final s = PlanningStatus.normalize(p.status);
              return p.hasInstruction ||
                  s == PlanningStatus.instructionReady ||
                  s == PlanningStatus.readyToTransfer ||
                  s == PlanningStatus.validationRequired;
            })
            .toList();
      case 'transferred':
        return plans
            .where((p) {
              if (p.isLibraryTrashed) return false;
              return p.wasTransferred ||
                  PlanningStatus.normalize(p.status) ==
                      PlanningStatus.transferred ||
                  PlanningStatus.normalize(p.status) ==
                      PlanningStatus.imported;
            })
            .toList();
      case 'completed':
        return plans
            .where(
              (p) =>
                  !p.isLibraryTrashed &&
                  PlanningStatus.normalize(p.status) ==
                      PlanningStatus.completed,
            )
            .toList();
      case 'archived':
        return plans.where((p) {
          if (p.isLibraryTrashed) return false;
          return p.isLibraryArchived ||
              PlanningStatus.normalize(p.status) == PlanningStatus.archived;
        }).toList();
      case 'trashed':
        return plans.where((p) => p.isLibraryTrashed).toList();
      case 'duplicate_candidates':
        final ids = duplicateCandidateIds ??
            duplicateCandidateIdSet(findDuplicateGroups(plans));
        return plans
            .where((p) => !p.isLibraryTrashed && ids.contains(p.id))
            .toList();
      case 'stale':
        return plans.where((p) {
          if (p.isLibraryTrashed) return false;
          final dt = DateTime.tryParse(p.updatedAt)?.toLocal();
          if (dt == null) return false;
          return clock.difference(dt) >= staleAfter;
        }).toList();
      case 'favorite':
        return plans
            .where((p) => !p.isLibraryTrashed && p.favorite)
            .toList();
      default:
        return plans.where((p) => !p.isLibraryTrashed).toList();
    }
  }

  static Set<String> duplicateCandidateIdSet(List<PlanDuplicateGroup> groups) {
    return {for (final g in groups) for (final p in g.plans) p.id};
  }

  /// 중복 후보 탐지.
  /// - 동일 checksum(비어 있지 않음) → 강한 후보
  /// - 제목만 동일 → 그룹에 넣지 않음 (오탐 방지)
  /// - 제목+결과물+대상고객 동일 → 약한 후보 (checksum 다를 때)
  static List<PlanDuplicateGroup> findDuplicateGroups(
    List<BusinessPlanDocument> plans, {
    bool includeTrashed = false,
  }) {
    final source = includeTrashed
        ? plans
        : plans.where((p) => !p.isLibraryTrashed).toList();
    final groups = <PlanDuplicateGroup>[];
    final claimed = <String>{};

    // 1) 강한 중복: 동일 contentChecksum
    final byChecksum = <String, List<BusinessPlanDocument>>{};
    for (final p in source) {
      final cs = contentChecksumOf(p);
      if (cs.isEmpty) continue;
      byChecksum.putIfAbsent(cs, () => []).add(p);
    }
    var idx = 1;
    for (final entry in byChecksum.entries) {
      if (entry.value.length < 2) continue;
      for (final p in entry.value) {
        claimed.add(p.id);
      }
      final title = entry.value.first.input.topic.trim().isEmpty
          ? '(주제 미입력)'
          : entry.value.first.input.topic.trim();
      groups.add(
        PlanDuplicateGroup(
          key: 'checksum_${entry.key}_$idx',
          title: title,
          plans: List<BusinessPlanDocument>.from(entry.value)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
          strongChecksumMatch: true,
        ),
      );
      idx++;
    }

    // 2) 약한 중복: 제목+결과물+고객 (이미 강한 그룹에 속한 id 제외)
    final bySoft = <String, List<BusinessPlanDocument>>{};
    for (final p in source) {
      if (claimed.contains(p.id)) continue;
      final title = p.input.topic.trim().toLowerCase();
      if (title.isEmpty) continue;
      final artifact = p.input.resolvedArtifactType.trim().toLowerCase();
      final customer = p.input.targetCustomer.trim().toLowerCase();
      // 제목만으로는 키를 만들지 않음 — artifact·customer 중 최소 하나는 있어야 함
      if (artifact.isEmpty && customer.isEmpty) continue;
      final key = '$title|$artifact|$customer';
      bySoft.putIfAbsent(key, () => []).add(p);
    }
    for (final entry in bySoft.entries) {
      if (entry.value.length < 2) continue;
      // 내용 checksum이 모두 다르고 비어 있지 않으면 제목만 같은 수준으로 취급 → 제외?
      // 요구: 제목만 같으면 확정하지 않음. 여기선 artifact+customer까지 같으므로 약후보.
      final checksums = entry.value
          .map(contentChecksumOf)
          .where((c) => c.isNotEmpty)
          .toSet();
      // 서로 다른 비어있지 않은 checksum이 2개 이상이면 "제목 유사·내용 다름" → 오탐 방지로 제외
      if (checksums.length >= 2) continue;

      final title = entry.value.first.input.topic.trim().isEmpty
          ? '(주제 미입력)'
          : entry.value.first.input.topic.trim();
      groups.add(
        PlanDuplicateGroup(
          key: 'soft_${entry.key}_$idx',
          title: title,
          plans: List<BusinessPlanDocument>.from(entry.value)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
          strongChecksumMatch: false,
        ),
      );
      idx++;
    }

    return groups;
  }

  /// 휴지통 이동 가능 여부 (보호됨이면 차단).
  static bool canMoveToTrash(BusinessPlanDocument plan) => !plan.isProtected;

  static PlanDeleteWarning permanentDeleteWarnings(
    BusinessPlanDocument plan, {
    String? activePlanId,
  }) {
    final reasons = <String>[];
    final s = PlanningStatus.normalize(plan.status);
    if (s == PlanningStatus.inProgress) {
      reasons.add('진행중');
    }
    if (plan.wasTransferred ||
        s == PlanningStatus.transferred ||
        s == PlanningStatus.imported) {
      reasons.add('작업지시 전달 완료');
    }
    if (activePlanId != null &&
        activePlanId.isNotEmpty &&
        plan.id == activePlanId) {
      reasons.add('현재 Active 프로젝트와 연결');
    }
    if (plan.favorite) {
      reasons.add('즐겨찾기');
    }
    if (plan.isProtected) {
      reasons.add('보호됨');
    }
    return PlanDeleteWarning(planId: plan.id, reasons: reasons);
  }

  static BusinessPlanDocument archive(
    BusinessPlanDocument plan, {
    required String updatedAt,
  }) {
    return plan.copyWith(
      libraryState: PlanLibraryState.archived,
      updatedAt: updatedAt,
    );
  }

  static BusinessPlanDocument unarchive(
    BusinessPlanDocument plan, {
    required String updatedAt,
  }) {
    return plan.copyWith(
      libraryState: PlanLibraryState.active,
      updatedAt: updatedAt,
    );
  }

  static BusinessPlanDocument moveToTrash(
    BusinessPlanDocument plan, {
    required String updatedAt,
    required String trashedAt,
  }) {
    if (plan.isProtected) {
      throw StateError('보호된 기획은 휴지통으로 이동할 수 없습니다.');
    }
    return plan.copyWith(
      libraryState: PlanLibraryState.trashed,
      updatedAt: updatedAt,
      trashedAt: trashedAt,
    );
  }

  static BusinessPlanDocument restore(
    BusinessPlanDocument plan, {
    required String updatedAt,
  }) {
    return plan.copyWith(
      libraryState: PlanLibraryState.active,
      updatedAt: updatedAt,
      clearTrashedAt: true,
    );
  }
}
