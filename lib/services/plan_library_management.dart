import '../models/business_planning.dart';
import 'plan_user_facing_status.dart';

/// 기획 라이브러리 일괄 작업 종류.
enum PlanLibraryBulkAction {
  favorite,
  unfavorite,
  archive,
  unarchive,
  trash,
  restore,
  protect,
  unprotect,
  permanentDelete,
}

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
  const PlanDeleteWarning({required this.planId, required this.reasons});

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

  /// 기본 「현재」 목록 — 현재 운영 가능한 기획만 (보관·정리대상·휴지통 제외).
  static bool isOperationalListEntry(BusinessPlanDocument plan) {
    if (plan.isLibraryTrashed) return false;
    if (plan.isLibraryArchived) return false;
    if (PlanningStatus.normalize(plan.status) == PlanningStatus.archived) {
      return false;
    }
    if (plan.tags.contains('정리대상') || plan.tags.contains('cleanup')) {
      return false;
    }
    return true;
  }

  /// 카드/목록 표시 제목. WI businessIdea가 있으면 우선 (데이터 덮어쓰기 없음).
  static String displayTitle(BusinessPlanDocument plan) {
    final fromWi = plan.instruction?.businessIdea.trim() ?? '';
    if (fromWi.isNotEmpty) return fromWi;
    final topic = plan.input.topic.trim();
    return topic.isEmpty ? '(주제 미입력)' : topic;
  }

  /// 일괄 보관에서 제외해야 하는 보호·운영 기획.
  static bool isBulkArchiveBlocked(
    BusinessPlanDocument plan, {
    String? activePlanId,
  }) {
    if (plan.isLibraryArchived) return true;
    if (plan.isLibraryTrashed) return true;
    final active = (activePlanId ?? '').trim();
    if (active.isNotEmpty && plan.id == active) return true;
    return PlanUserFacingStatus.isOperationallyProtected(plan);
  }

  static String bulkArchiveBlockReason(
    BusinessPlanDocument plan, {
    String? activePlanId,
  }) {
    if (PlanUserFacingStatus.isProtectedInstruction(plan.stableInstructionId)) {
      return '운영 작업지시 보호';
    }
    if (plan.isProtected) return '보호됨';
    final active = (activePlanId ?? '').trim();
    if (active.isNotEmpty && plan.id == active) return '현재 Active';
    final facing = PlanUserFacingStatus.label(plan);
    if (facing == PlanUserFacingStatus.working) return '작업중';
    if (facing == PlanUserFacingStatus.awaitingApproval) return '승인대기';
    if (facing == PlanUserFacingStatus.delivered) return '전달완료';
    return '운영 보호';
  }

  /// 현재 관리 필터에서 체크박스·전체 선택에 쓰는 primary bulk action.
  static PlanLibraryBulkAction primarySelectionActionForFilter(
    String folderFilter,
  ) {
    switch (folderFilter) {
      case 'archived':
        return PlanLibraryBulkAction.unarchive;
      case 'trashed':
        return PlanLibraryBulkAction.restore;
      default:
        return PlanLibraryBulkAction.archive;
    }
  }

  /// bulk action + plan 상태 기준 선택 가능 여부 (체크박스 enable/disable).
  static bool isSelectableForBulkAction(
    BusinessPlanDocument plan,
    PlanLibraryBulkAction action, {
    String? activePlanId,
  }) {
    switch (action) {
      case PlanLibraryBulkAction.archive:
        return !isBulkArchiveBlocked(plan, activePlanId: activePlanId);
      case PlanLibraryBulkAction.unarchive:
        if (plan.isLibraryTrashed) return false;
        return plan.isLibraryArchived ||
            PlanningStatus.normalize(plan.status) == PlanningStatus.archived;
      case PlanLibraryBulkAction.restore:
      case PlanLibraryBulkAction.permanentDelete:
        return plan.isLibraryTrashed;
      case PlanLibraryBulkAction.trash:
        return canMoveToTrash(plan) &&
            !plan.isLibraryTrashed &&
            !plan.isLibraryArchived;
      case PlanLibraryBulkAction.favorite:
      case PlanLibraryBulkAction.unfavorite:
      case PlanLibraryBulkAction.protect:
      case PlanLibraryBulkAction.unprotect:
        return !plan.isLibraryTrashed;
    }
  }

  /// 자동 정리용 태그만 제거 (사용자 의미 태그는 유지).
  static List<String> withoutCleanupTags(List<String> tags) {
    return tags
        .where((t) {
          final n = t.trim();
          return n != '정리대상' && n != 'cleanup';
        })
        .toList();
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
        return plans.where(isOperationalListEntry).toList();
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
        return plans.where((p) {
          if (p.isLibraryTrashed) return false;
          final s = PlanningStatus.normalize(p.status);
          return p.hasInstruction ||
              s == PlanningStatus.instructionReady ||
              s == PlanningStatus.readyToTransfer ||
              s == PlanningStatus.validationRequired;
        }).toList();
      case 'transferred':
        return plans.where((p) {
          if (p.isLibraryTrashed) return false;
          return p.wasTransferred ||
              PlanningStatus.normalize(p.status) ==
                  PlanningStatus.transferred ||
              PlanningStatus.normalize(p.status) == PlanningStatus.imported;
        }).toList();
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
        final ids =
            duplicateCandidateIds ??
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
        return plans.where((p) => !p.isLibraryTrashed && p.favorite).toList();
      case 'active':
        // 진행중 = 기획중·작업지시준비·작업중·전달완료 (보관/휴지통/정리대상 제외)
        return plans.where((p) {
          if (p.isLibraryTrashed || p.isLibraryArchived) return false;
          if (p.tags.contains('정리대상') || p.tags.contains('cleanup')) {
            return false;
          }
          final s = PlanningStatus.normalize(p.status);
          return s != PlanningStatus.completed &&
              s != PlanningStatus.archived;
        }).toList();
      case 'waiting':
        return plans
            .where(
              (p) =>
                  !p.isLibraryTrashed &&
                  !p.isLibraryArchived &&
                  (p.tags.contains('승인대기') ||
                      PlanningStatus.normalize(p.status) ==
                          PlanningStatus.validationRequired),
            )
            .toList();
      case 'cleanup':
        return plans
            .where(
              (p) =>
                  p.tags.contains('정리대상') ||
                  p.tags.contains('cleanup') ||
                  p.isLibraryTrashed,
            )
            .toList();
      default:
        return plans.where((p) => !p.isLibraryTrashed).toList();
    }
  }

  /// 자동 보관은 **명확한 lineage**가 있는 경우에만 수행한다.
  /// checksum만 동일한 별도 planId는 후보 표시만 하고 자동 보관하지 않는다.
  /// 보호 instruction / isProtected / activePlanId / 운영 WI는 제외.
  /// 영구삭제는 하지 않는다. 기존 cleanup으로 보관된 항목은 복원하지 않는다.
  static List<BusinessPlanDocument> softMarkDuplicateCleanup(
    List<BusinessPlanDocument> plans, {
    Set<String> protectInstructionIds =
        PlanUserFacingStatus.protectedInstructionIds,
    String? activePlanId,
    String? nowIso,
  }) {
    final stamp = nowIso ?? DateTime.now().toUtc().toIso8601String();
    final byId = {for (final p in plans) p.id: p};
    final active = (activePlanId ?? '').trim();

    // Lineage-linked clusters only (not checksum-only groups).
    final lineageClusters = _lineageClusters(plans);
    for (final cluster in lineageClusters) {
      if (cluster.length < 2) continue;
      // Prefer same-checksum subgroups inside a lineage cluster.
      final byCs = <String, List<BusinessPlanDocument>>{};
      for (final p in cluster) {
        final cs = contentChecksumOf(p);
        if (cs.isEmpty) continue;
        byCs.putIfAbsent(cs, () => []).add(p);
      }
      // lineage + same checksum only (checksum alone without lineage never reaches here)
      final subgroups = byCs.values.where((g) => g.length >= 2).toList();
      for (final group in subgroups) {
        final sorted = List<BusinessPlanDocument>.from(group)
          ..sort((a, b) {
            final ap = protectInstructionIds.contains(a.stableInstructionId);
            final bp = protectInstructionIds.contains(b.stableInstructionId);
            if (ap != bp) return ap ? -1 : 1;
            if (a.isProtected != b.isProtected) return a.isProtected ? -1 : 1;
            if (active.isNotEmpty) {
              final aa = a.id == active;
              final ba = b.id == active;
              if (aa != ba) return aa ? -1 : 1;
            }
            final ao = PlanUserFacingStatus.isOperationallyProtected(a);
            final bo = PlanUserFacingStatus.isOperationallyProtected(b);
            if (ao != bo) return ao ? -1 : 1;
            if (a.hasInstruction != b.hasInstruction) {
              return a.hasInstruction ? -1 : 1;
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });
        final keep = sorted.first;
        for (final p in sorted.skip(1)) {
          if (protectInstructionIds.contains(p.stableInstructionId)) continue;
          if (p.isProtected) continue;
          if (active.isNotEmpty && p.id == active) continue;
          if (PlanUserFacingStatus.isOperationallyProtected(p)) continue;
          if (p.id == keep.id) continue;
          final tags = {...p.tags, '정리대상', 'cleanup'};
          byId[p.id] = archive(
            p.copyWith(tags: tags.toList()),
            updatedAt: stamp,
          );
        }
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// tags 기반 lineage: sourcePlanId: / cloneOf: / lineage:
  static String? lineageParentId(BusinessPlanDocument plan) {
    for (final raw in plan.tags) {
      final t = raw.trim();
      for (final prefix in ['sourcePlanId:', 'cloneOf:', 'lineage:']) {
        if (t.startsWith(prefix)) {
          final id = t.substring(prefix.length).trim();
          if (id.isNotEmpty) return id;
        }
      }
    }
    return null;
  }

  static bool sharesLineage(BusinessPlanDocument a, BusinessPlanDocument b) {
    if (a.id == b.id) return true;
    final ap = lineageParentId(a);
    final bp = lineageParentId(b);
    if (ap != null && (ap == b.id || ap == bp)) return true;
    if (bp != null && (bp == a.id || bp == ap)) return true;
    return false;
  }

  /// Connected components by lineage edges.
  static List<List<BusinessPlanDocument>> _lineageClusters(
    List<BusinessPlanDocument> plans,
  ) {
    final list = plans.where((p) => !p.isLibraryTrashed).toList();
    final parentOf = <String, String>{};
    for (final p in list) {
      final parent = lineageParentId(p);
      if (parent != null) parentOf[p.id] = parent;
    }
    if (parentOf.isEmpty) return const [];

    final byId = {for (final p in list) p.id: p};
    final adj = <String, Set<String>>{};
    void link(String a, String b) {
      adj.putIfAbsent(a, () => {}).add(b);
      adj.putIfAbsent(b, () => {}).add(a);
    }

    for (final e in parentOf.entries) {
      link(e.key, e.value);
      // Also connect siblings with same parent.
      for (final other in parentOf.entries) {
        if (other.key == e.key) continue;
        if (other.value == e.value) link(e.key, other.key);
      }
    }

    final seen = <String>{};
    final clusters = <List<BusinessPlanDocument>>[];
    for (final id in adj.keys) {
      if (seen.contains(id)) continue;
      final stack = <String>[id];
      final comp = <String>{};
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (!comp.add(cur)) continue;
        seen.add(cur);
        for (final n in adj[cur] ?? const <String>{}) {
          if (!comp.contains(n)) stack.add(n);
        }
      }
      final docs = comp.map((i) => byId[i]).whereType<BusinessPlanDocument>().toList();
      if (docs.length >= 2) clusters.add(docs);
    }
    return clusters;
  }

  static Set<String> duplicateCandidateIdSet(List<PlanDuplicateGroup> groups) {
    return {
      for (final g in groups)
        for (final p in g.plans) p.id,
    };
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
    if (PlanUserFacingStatus.isProtectedInstruction(plan.stableInstructionId)) {
      reasons.add('운영 작업지시 보호');
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
      tags: withoutCleanupTags(plan.tags),
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
      tags: withoutCleanupTags(plan.tags),
      updatedAt: updatedAt,
      clearTrashedAt: true,
    );
  }
}
