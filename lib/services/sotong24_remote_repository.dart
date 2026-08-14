import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/instruction_contract.dart';
import '../models/sotong24_remote_models.dart';
import 'business_planning_service.dart';
import 'firebase_ready.dart';

/// Firestore: sotong24work_projects/{projectId}
///   stages/{stageId}, requests/{requestId}
///
/// Firebase 미연결·오류 시 데모 데이터(isDemo=true)로 UI를 유지한다.
/// 실제 제품 문서를 삭제·마이그레이션하지 않는다.
class Sotong24RemoteRepository {
  Sotong24RemoteRepository({
    this._db,
    Sotong24RemoteApprovalGuard? guard,
    List<Sotong24RemoteProject>? memorySeed,
    bool? forceMemory,
  }) : _guard = guard ?? const Sotong24RemoteApprovalGuard(),
       _forceMemory = forceMemory ?? false {
    _memory = List<Sotong24RemoteProject>.from(
      memorySeed ?? Sotong24RemoteDemoCatalog.demoProjects(),
    );
    _memoryRequests = {
      for (final p in _memory)
        p.projectId: [
          for (final s in p.stages)
            if (s.activeRequestId.isNotEmpty)
              Sotong24RemoteRequest(
                requestId: s.activeRequestId,
                projectId: p.projectId,
                stageId: s.stageId,
                requestType: 'approve',
                status: ApprovalStatus.pending,
                createdAt: s.updatedAt,
                updatedAt: s.updatedAt,
              ),
        ],
    };
  }

  final FirebaseFirestore? _db;
  final Sotong24RemoteApprovalGuard _guard;
  final bool _forceMemory;

  late List<Sotong24RemoteProject> _memory;
  late Map<String, List<Sotong24RemoteRequest>> _memoryRequests;
  final _memoryController =
      StreamController<List<Sotong24RemoteProject>>.broadcast();

  static const collectionName = 'sotong24work_projects';

  bool get usesMemory => _forceMemory || !isFirebaseReady();

  CollectionReference<Map<String, dynamic>>? get _projects {
    if (usesMemory) return null;
    final db = _db ?? FirebaseFirestore.instance;
    return db.collection(collectionName);
  }

  Stream<List<Sotong24RemoteProject>> watchProjects() {
    if (usesMemory || _projects == null) {
      return _watchMemoryProjects();
    }

    return _projects!.snapshots().asyncMap((snap) async {
      if (snap.docs.isEmpty) {
        return List<Sotong24RemoteProject>.unmodifiable(_memory);
      }
      final list = <Sotong24RemoteProject>[];
      for (final doc in snap.docs) {
        final stages = await _loadStages(doc.id);
        list.add(
          Sotong24RemoteProject.fromMap(doc.data(), id: doc.id, stages: stages),
        );
      }
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  Stream<List<Sotong24RemoteProject>> _watchMemoryProjects() async* {
    yield List<Sotong24RemoteProject>.unmodifiable(_memory);
    yield* _memoryController.stream;
  }

  Stream<Sotong24RemoteProject?> watchProject(String projectId) {
    return watchProjects().map((list) {
      for (final p in list) {
        if (p.projectId == projectId) return p;
      }
      return null;
    });
  }

  Future<List<Sotong24RemoteStage>> _loadStages(String projectId) async {
    final col = _projects;
    if (col == null) return const [];
    final snap = await col.doc(projectId).collection('stages').get();
    final stages = snap.docs
        .map((d) => Sotong24RemoteStage.fromMap(d.data(), id: d.id))
        .toList();
    stages.sort((a, b) => a.stageNumber.compareTo(b.stageNumber));
    return stages;
  }

  Future<List<Sotong24RemoteRequest>> _loadRequests(String projectId) async {
    if (usesMemory || _projects == null) {
      return List.unmodifiable(_memoryRequests[projectId] ?? const []);
    }
    final snap = await _projects!.doc(projectId).collection('requests').get();
    return snap.docs
        .map((d) => Sotong24RemoteRequest.fromMap(d.data(), id: d.id))
        .toList();
  }

  Future<Sotong24RemoteProject?> getProject(String projectId) async {
    final list = await watchProjects().first;
    for (final p in list) {
      if (p.projectId == projectId) return p;
    }
    return null;
  }

  /// 승인: approvalStatus=approved. 외부 배포/push는 수행하지 않는다.
  Future<String?> approveStage({
    required String projectId,
    required String stageId,
    required String requestId,
  }) {
    return _submitDecision(
      projectId: projectId,
      stageId: stageId,
      requestId: requestId,
      requestType: 'approve',
      decision: ApprovalStatus.approved,
      message: '',
    );
  }

  /// 보완 요청: approvalStatus=revision_requested.
  Future<String?> requestRevision({
    required String projectId,
    required String stageId,
    required String requestId,
    required String message,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return Future.value('보완 내용을 입력해 주세요.');
    }
    return _submitDecision(
      projectId: projectId,
      stageId: stageId,
      requestId: requestId,
      requestType: 'revision_request',
      decision: ApprovalStatus.revisionRequested,
      message: trimmed,
    );
  }

  Future<String?> _submitDecision({
    required String projectId,
    required String stageId,
    required String requestId,
    required String requestType,
    required String decision,
    required String message,
  }) async {
    final project = await getProject(projectId);
    if (project == null) return '프로젝트를 찾을 수 없습니다.';

    final existing = await _loadRequests(projectId);
    final error = _guard.validateSubmit(
      project: project,
      stageId: stageId,
      requestId: requestId,
      existingRequests: existing.where(
        (r) =>
            r.status == ApprovalStatus.pending ||
            r.status == ApprovalStatus.approved ||
            r.status == ApprovalStatus.revisionRequested,
      ),
    );
    if (error != null) return error;

    final now = DateTime.now().toUtc().toIso8601String();
    final request = Sotong24RemoteRequest(
      requestId: requestId,
      projectId: projectId,
      stageId: stageId,
      requestType: requestType,
      status: decision,
      message: message,
      createdAt: now,
      updatedAt: now,
      processedAt: now,
    );

    if (usesMemory || _projects == null || project.isDemo) {
      return _applyMemoryDecision(
        project: project,
        stageId: stageId,
        request: request,
        decision: decision,
        now: now,
      );
    }

    try {
      final doc = _projects!.doc(projectId);
      await doc.collection('requests').doc(requestId).set(request.toMap());
      await doc.collection('stages').doc(stageId).set({
        'approvalStatus': decision,
        'status': decision == ApprovalStatus.approved
            ? Sotong24WorkStatus.completed
            : Sotong24WorkStatus.revision,
        'activeRequestId': requestId,
        'updatedAt': now,
        if (message.isNotEmpty) 'userAttention': message,
      }, SetOptions(merge: true));
      await doc.set({
        'approvalStatus': decision,
        'status': decision == ApprovalStatus.approved
            ? Sotong24WorkStatus.inProgress
            : Sotong24WorkStatus.revision,
        'updatedAt': now,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return '저장에 실패했습니다. 네트워크·권한을 확인해 주세요. ($e)';
    }
  }

  String? _applyMemoryDecision({
    required Sotong24RemoteProject project,
    required String stageId,
    required Sotong24RemoteRequest request,
    required String decision,
    required String now,
  }) {
    final stages = project.stages.map((s) {
      if (s.stageId != stageId) return s;
      return s.copyWith(
        approvalStatus: decision,
        status: decision == ApprovalStatus.approved
            ? Sotong24WorkStatus.completed
            : Sotong24WorkStatus.revision,
        activeRequestId: request.requestId,
        updatedAt: now,
        summary: request.message.isNotEmpty ? request.message : s.summary,
      );
    }).toList();

    final nextStatus = decision == ApprovalStatus.approved
        ? Sotong24WorkStatus.inProgress
        : Sotong24WorkStatus.revision;

    final updated = project.copyWith(
      stages: stages,
      status: nextStatus,
      approvalStatus: decision,
      updatedAt: now,
    );

    _memory = [
      for (final p in _memory)
        if (p.projectId == project.projectId) updated else p,
    ];
    final reqs = [
      ...(_memoryRequests[project.projectId] ?? <Sotong24RemoteRequest>[]),
    ];
    // pending 제거 후 결정
    reqs.removeWhere(
      (r) =>
          r.requestId == request.requestId ||
          (r.stageId == stageId && r.status == ApprovalStatus.pending),
    );
    reqs.add(request);
    _memoryRequests[project.projectId] = reqs;
    _memoryController.add(List.unmodifiable(_memory));
    return null;
  }

  /// 취소/중지 요청 — Relay request_poll → Sotong24Work Agent.
  Future<String?> requestCancel({
    required String projectId,
    required String instructionId,
    String message = '',
    String stageId = '',
  }) async {
    final pid = projectId.trim();
    if (pid.isEmpty) return 'projectId가 필요합니다.';
    final now = DateTime.now().toUtc().toIso8601String();
    final requestId = 'cancel_${instructionId.trim()}_${now.hashCode.abs()}';

    var resolvedStageId = stageId.trim();
    if (resolvedStageId.isEmpty) {
      Sotong24RemoteProject? project;
      if (usesMemory) {
        for (final p in _memory) {
          if (p.projectId == pid) {
            project = p;
            break;
          }
        }
      } else if (_projects != null) {
        try {
          final snap = await _projects!.doc(pid).get();
          if (snap.exists) {
            project = Sotong24RemoteProject.fromMap(
              snap.data() ?? {},
              id: snap.id,
            );
          }
        } catch (_) {}
      }
      resolvedStageId =
          project?.currentStageDoc?.stageId ??
          _stageIdForNumber(project?.currentStage ?? 0) ??
          'maintain';
    }

    final request = Sotong24RemoteRequest(
      requestId: requestId,
      projectId: pid,
      stageId: resolvedStageId,
      requestType: 'cancel',
      status: ApprovalStatus.pending,
      message: message.trim().isEmpty ? '사용자 취소 요청' : message.trim(),
      createdAt: now,
      updatedAt: now,
    );

    if (usesMemory || _projects == null) {
      final list = _memoryRequests[pid] ?? <Sotong24RemoteRequest>[];
      _memoryRequests[pid] = [...list, request];
      return null;
    }

    try {
      final doc = _projects!.doc(pid);
      await doc.collection('requests').doc(requestId).set(request.toMap());
      await doc.set({
        'status': Sotong24WorkStatus.error,
        'updatedAt': now,
        'cancelRequestedAt': now,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return '취소 요청 저장 실패: $e';
    }
  }

  void dispose() {
    _memoryController.close();
  }

  String? _stageIdForNumber(int stageNumber) {
    if (stageNumber <= 0) return null;
    final titles = BusinessPlanningService.standardWorkflowTitles;
    if (stageNumber > titles.length) return null;
    return titles[stageNumber - 1].$1;
  }
}

/// 목록 필터.
enum Sotong24ProjectFilter { inProgress, awaitingApproval, completed, all }

extension Sotong24ProjectFilterX on Sotong24ProjectFilter {
  String get labelKo {
    switch (this) {
      case Sotong24ProjectFilter.inProgress:
        return '진행 중';
      case Sotong24ProjectFilter.awaitingApproval:
        return '승인 대기';
      case Sotong24ProjectFilter.completed:
        return '완료';
      case Sotong24ProjectFilter.all:
        return '전체';
    }
  }

  bool matches(Sotong24RemoteProject p) {
    switch (this) {
      case Sotong24ProjectFilter.inProgress:
        return p.status == Sotong24WorkStatus.inProgress ||
            p.status == Sotong24WorkStatus.revision ||
            p.status == Sotong24WorkStatus.ready;
      case Sotong24ProjectFilter.awaitingApproval:
        return p.status == Sotong24WorkStatus.awaitingApproval ||
            p.approvalStatus == ApprovalStatus.pending;
      case Sotong24ProjectFilter.completed:
        return p.status == Sotong24WorkStatus.completed;
      case Sotong24ProjectFilter.all:
        return true;
    }
  }
}
