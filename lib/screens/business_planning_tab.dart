import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/business_planning.dart';
import '../models/dev_work_doc_status.dart';
import '../models/idea_bank.dart';
import '../models/planning_wizard_state.dart';
import '../models/project_design_state.dart';
import '../models/remote_agent_models.dart';
import '../services/business_planning_service.dart';
import '../services/business_planning_store.dart';
import '../services/dev_work_doc_paths.dart';
import '../services/dev_work_doc_service.dart';
import '../services/dev_work_doc_verify.dart';
import '../services/instruction_contract_validator.dart';
import '../services/instruction_transfer_service.dart';
import '../models/sotong24_remote_models.dart';
import '../services/plan_execution_index.dart';
import '../services/plan_execution_status.dart';
import '../services/plan_library_management.dart';
import '../services/plan_progress_status.dart';
import '../services/plan_user_facing_status.dart';
import '../services/pc_workspace_ui.dart';
import '../services/project_design_engine.dart';
import '../services/remote_agent_repository.dart';
import '../services/remote_work_instruction_mirror.dart';
import '../services/sotong24_remote_repository.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../services/work_instruction_remote_delivery.dart';
import '../services/work_instruction_validator.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/project_design/instruction_preview_panel.dart';
import '../widgets/project_design/plan_library_panel.dart';
import '../widgets/operational_collapsible_section.dart';
import '../widgets/project_design/project_design_wizard.dart';

/// 작업지시 제작소 본문 (로컬 규칙 기반).
/// Production AI는 새 ebook WI에만 opt-in `aiExecution`으로 연결한다.
class BusinessPlanningTab extends StatefulWidget {
  const BusinessPlanningTab({super.key, this.ideaSeed});

  /// 뉴 아이디어 뱅크에서 전달. 새 기획으로만 적용(기존 active 덮어쓰지 않음).
  final IdeaToPlanningSeed? ideaSeed;

  @override
  State<BusinessPlanningTab> createState() => _BusinessPlanningTabState();
}

class _BusinessPlanningTabState extends State<BusinessPlanningTab> {
  final _service = BusinessPlanningService();
  final _store = BusinessPlanningStore();
  final _transfer = InstructionTransferService();
  final _devWorkDoc = DevWorkDocService();
  final _wiMirror = RemoteWorkInstructionMirrorService();
  final _agentRepo = RemoteAgentRepository();
  final _remoteRepo = Sotong24RemoteRepository();
  final _delivery = WorkInstructionRemoteDeliveryService();
  final _contractValidator = InstructionContractValidator();
  final _designEngine = ProjectDesignEngine();

  final _topicCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _materialsCtrl = TextEditingController();
  final _scaleCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _salesPriceCtrl = TextEditingController();
  final _referencesCtrl = TextEditingController();
  final _constraintsCtrl = TextEditingController();
  final _extraRequestsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  PlanningWizardState _wizardState = PlanningWizardState(mode: 'quick');
  ProjectDesignState _designState = ProjectDesignState();
  String _artifactType = ArtifactType.undecided;
  String _contentSubtype = '';
  List<BusinessPlanDocument> _allPlans = const [];
  BusinessPlanDocument? _activeDoc;
  PlanningAnalysisResult? _analysis;
  WorkInstruction? _instruction;
  String? _activePlanId;
  String? _instructionId;
  int _version = 1;

  bool _loading = true;
  bool _transferBusy = false;
  String? _lastTransferDiagnosis;
  bool _inputModeQuick = true;

  /// 새 ebook WI에만 Codex 1단계 pilot 정책 부착. 기존 WI에는 자동 삽입하지 않음.
  bool _aiProductionPilot = true;
  String _libraryFolder = 'all';
  PlanLibraryViewMode _libraryView = PlanLibraryViewMode.cards;
  PlanLibrarySort _librarySort = PlanLibrarySort.newest;
  FolderPermissionState? _folderState;
  DevWorkDocState? _devDocState;
  List<RemoteAgentDoc> _remoteAgents = const [];
  List<RemoteJobDoc> _remoteJobs = const [];
  List<Sotong24RemoteProject> _remoteProjects = const [];
  StreamSubscription<List<Sotong24RemoteProject>>? _remoteProjectsSub;
  StreamSubscription<List<RemoteJobDoc>>? _remoteJobsSub;
  StreamSubscription<List<RemoteAgentDoc>>? _remoteAgentsSub;
  bool _orphanRepairStarted = false;
  bool _pcWorkspaceExpanded = false;
  DevWorkDocWriteResult? _lastDevWorkDocResult;
  Timer? _draftTimer;
  Timer? _wizardTimer;

  static const _artifactOptions = [
    ...ArtifactType.allSelectable,
    ArtifactType.undecided,
  ];

  static const _contentSubtypeOptions = [
    ...ContentSubtype.allSelectable,
    ContentSubtype.undecided,
  ];

  @override
  void initState() {
    super.initState();
    _bindDraftListeners();
    _loadInitial();
    _remoteProjectsSub = _remoteRepo.watchProjects().listen((projects) {
      if (!mounted) return;
      setState(() => _remoteProjects = projects);
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _remoteJobsSub = _agentRepo.watchJobs(ownerUid: uid).listen((jobs) {
        if (!mounted) return;
        setState(() => _remoteJobs = jobs);
        unawaited(_maybeRepairOrphan());
      });
      _remoteAgentsSub = _agentRepo.watchAgents(ownerUid: uid).listen((agents) {
        if (!mounted) return;
        setState(() => _remoteAgents = agents);
      });
    } catch (_) {}
  }

  PlanExecutionIndex get _executionIndex =>
      PlanExecutionIndex.fromRemoteProjects(_remoteProjects, jobs: _remoteJobs);

  PlanExecutionSnapshot _execFor(BusinessPlanDocument plan) =>
      _executionIndex.snapshotFor(plan);

  bool get _showWorkshopEmptyPrep {
    if (Sotong24WorkshopPresentation.hasOperationalWork(_remoteProjects)) {
      return false;
    }
    if (_remoteJobs.isNotEmpty) return false;
    final doc = _activeDoc;
    if (doc == null) return true;
    return !_execFor(doc).hasActualExecution;
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _wizardTimer?.cancel();
    _remoteProjectsSub?.cancel();
    _remoteJobsSub?.cancel();
    _remoteAgentsSub?.cancel();
    _remoteRepo.dispose();
    for (final c in _allControllers) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TextEditingController> get _allControllers => [
    _topicCtrl,
    _problemCtrl,
    _targetCtrl,
    _outcomeCtrl,
    _skillsCtrl,
    _materialsCtrl,
    _scaleCtrl,
    _budgetCtrl,
    _salesPriceCtrl,
    _referencesCtrl,
    _constraintsCtrl,
    _extraRequestsCtrl,
    _notesCtrl,
  ];

  void _bindDraftListeners() {
    void scheduleDraft() {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 800), _persistDraft);
    }

    for (final c in _allControllers) {
      c.addListener(scheduleDraft);
    }
    _searchCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadInitial() async {
    try {
      // Active context MUST be restored before cleanup (see bootstrapSession).
      final boot = await BusinessPlanningStore.bootstrapSession(_store);
      final draft = await _store.loadDraftInput();
      final folder = await _transfer.currentState();
      final devDoc = await _devWorkDoc.currentState();
      var agents = <RemoteAgentDoc>[];
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        agents = await _agentRepo
            .watchAgents(ownerUid: uid)
            .first
            .timeout(
              const Duration(seconds: 4),
              onTimeout: () => const <RemoteAgentDoc>[],
            );
      } catch (_) {
        agents = const [];
      }
      if (!mounted) return;
      setState(() {
        _allPlans = BusinessPlanningStore.dedupeById(boot.plans);
        _activePlanId = boot.activePlanId;
        _folderState = folder;
        _devDocState = devDoc;
        _remoteAgents = agents;
        _loading = false;
        if (boot.activePlanId != null) {
          final match = boot.plans.where((p) => p.id == boot.activePlanId);
          if (match.isNotEmpty) {
            final plan = match.first;
            _instructionId = plan.stableInstructionId;
            _version = plan.version;
            _applyInput(plan.input);
            _analysis = plan.analysis;
            _instruction = plan.instruction;
            _activeDoc = plan;
            _aiProductionPilot = plan.instruction?.aiExecution?.enabled == true;
            if (plan.input.wizardSelections != null) {
              _wizardState = PlanningWizardState.fromJson(
                plan.input.wizardSelections!,
              );
              _designState = ProjectDesignState.fromWizardState(_wizardState);
              _inputModeQuick = _wizardState.mode != 'advanced';
            }
          }
        } else if (draft != null) {
          _applyInput(draft);
          if (draft.wizardSelections != null) {
            _wizardState = PlanningWizardState.fromJson(
              draft.wizardSelections!,
            );
            _designState = ProjectDesignState.fromWizardState(_wizardState);
            _inputModeQuick = _wizardState.mode != 'advanced';
          }
        }
      });
      _consumeIdeaSeedIfNeeded();
      unawaited(_maybeRepairOrphan());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant BusinessPlanningTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ideaSeed != oldWidget.ideaSeed) {
      _appliedIdeaSeedId = null;
      _consumeIdeaSeedIfNeeded();
    }
  }

  BusinessPlanInput get _currentInput {
    if (_inputModeQuick) {
      return _designEngine.toBusinessPlanInput(_designState);
    }
    return BusinessPlanInput(
      topic: _topicCtrl.text,
      customerProblem: _problemCtrl.text,
      targetCustomer: _targetCtrl.text,
      desiredOutcome: _outcomeCtrl.text,
      experienceSkills: _skillsCtrl.text,
      existingMaterials: _materialsCtrl.text,
      expectedScale: _scaleCtrl.text,
      budgetEstimate: _budgetCtrl.text,
      salesPrice: _salesPriceCtrl.text,
      references: _referencesCtrl.text,
      constraints: _constraintsCtrl.text,
      extraRequests: _extraRequestsCtrl.text,
      notes: _notesCtrl.text,
      deliverableTypes: _artifactType == ArtifactType.undecided
          ? const [DeliverableType.undecided]
          : [_artifactType],
      artifactType: _artifactType,
      contentSubtype: _contentSubtype,
      wizardSelections: _wizardState.toJson(),
      sentencesManuallyEdited: _wizardState.sentencesManuallyEdited,
    );
  }

  bool get _hasSomeContent {
    final input = _currentInput;
    return input.topic.trim().isNotEmpty ||
        input.customerProblem.trim().isNotEmpty ||
        input.targetCustomer.trim().isNotEmpty ||
        input.desiredOutcome.trim().isNotEmpty ||
        _wizardState.artifactType != null ||
        _artifactType != ArtifactType.undecided;
  }

  bool get _planReady {
    final input = _currentInput;
    if (_inputModeQuick) {
      return _wizardState.step >= 4 && input.hasRequiredFields;
    }
    return input.hasRequiredFields;
  }

  bool get _canCreateInstruction {
    final input = _currentInput;
    if (!input.hasRequiredFields) return false;
    final artifact = input.resolvedArtifactType;
    if (artifact == ArtifactType.undecided) return false;
    if (artifact == ArtifactType.contents) {
      final sub = ContentSubtype.normalize(
        input.contentSubtype.isEmpty
            ? ContentSubtype.undecided
            : input.contentSubtype,
      );
      if (sub == ContentSubtype.undecided) return false;
    }
    if (_inputModeQuick && !_designState.planningConfirmed) return false;
    return true;
  }

  bool get _canTransfer {
    if (_instruction == null) return false;
    final result = _contractValidator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
    return result.canTransfer;
  }

  ContractValidationResult? get _contractValidation {
    if (_instruction == null) return null;
    return _contractValidator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
  }

  bool get _inboxTransferReady => _folderState?.readyToWrite == true;

  void _applyInput(BusinessPlanInput input) {
    _topicCtrl.text = input.topic;
    _problemCtrl.text = input.customerProblem;
    _targetCtrl.text = input.targetCustomer;
    _outcomeCtrl.text = input.desiredOutcome;
    _skillsCtrl.text = input.experienceSkills;
    _materialsCtrl.text = input.existingMaterials;
    _scaleCtrl.text = input.expectedScale;
    _budgetCtrl.text = input.budgetEstimate;
    _salesPriceCtrl.text = input.salesPrice;
    _referencesCtrl.text = input.references;
    _constraintsCtrl.text = input.constraints;
    _extraRequestsCtrl.text = input.extraRequests;
    _notesCtrl.text = input.notes;
    _artifactType = input.resolvedArtifactType;
    _contentSubtype = input.contentSubtype;
  }

  void _onDesignChanged(ProjectDesignState state) {
    _designState = state;
    _wizardState = state.toWizardState();
    _wizardTimer?.cancel();
    _wizardTimer = Timer(const Duration(milliseconds: 500), _persistDraft);
    setState(() {});
  }

  Future<void> _persistDraft() async {
    await _store.saveDraftInput(_currentInput);
  }

  void _selectArtifact(String type) {
    final normalized = ArtifactType.normalize(type);
    setState(() {
      _artifactType = normalized;
      if (normalized != ArtifactType.contents) {
        _contentSubtype = '';
      }
    });
    _persistDraft();
  }

  void _selectContentSubtype(String subtype) {
    setState(() {
      _contentSubtype = ContentSubtype.normalize(subtype);
    });
    _persistDraft();
  }

  String get _docStatus => _activeDoc == null
      ? PlanningStatus.draft
      : PlanningStatus.normalize(_activeDoc!.status);

  bool get _isInstructionArchived => _docStatus == PlanningStatus.archived;

  bool get _isInstructionReady {
    switch (_docStatus) {
      case PlanningStatus.instructionReady:
      case PlanningStatus.readyToTransfer:
      case PlanningStatus.validationRequired:
      case PlanningStatus.transferred:
      case PlanningStatus.transferFailed:
      case PlanningStatus.downloadedPendingImport:
        return _instruction != null;
      default:
        return false;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshPlans() async {
    _allPlans = BusinessPlanningStore.dedupeById(
      await _store.loadPlans(
        activePlanId: _activePlanId,
        activeContextReady: true,
        runCleanup: true,
      ),
    );
  }

  String _stableInstructionId(String planId) => 'wi_$planId';

  PlanningAnalysisResult _ensureAnalysis(BusinessPlanInput input) {
    return _analysis ?? _service.analyze(input);
  }

  BusinessPlanDocument _buildDocument({
    required String id,
    required String createdAt,
    required String updatedAt,
    required String status,
    required BusinessPlanInput input,
    PlanningAnalysisResult? analysis,
    WorkInstruction? instruction,
    String? instructionId,
    int? version,
    List<PlanVersionSnapshot>? versionHistory,
    String? lastTransferAt,
    String? lastTransferFileName,
    String? lastTransferChecksum,
    String? lastTransferMode,
    bool? favorite,
    String? libraryFolder,
    List<String>? tags,
    String? libraryState,
    bool? isProtected,
    String? trashedAt,
    bool clearTrashedAt = false,
  }) {
    final iid = instructionId ?? _instructionId ?? _stableInstructionId(id);
    final existing = _allPlans.cast<BusinessPlanDocument?>().firstWhere(
      (p) => p?.id == id,
      orElse: () => null,
    );
    return BusinessPlanDocument(
      id: id,
      input: input,
      status: PlanningStatus.normalize(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      analysis: analysis,
      instruction: instruction,
      instructionId: iid,
      version: version ?? _version,
      primaryTrack: input.primaryTrack,
      followUpTracks: instruction?.followUpTracks ?? const [],
      lastTransferAt: lastTransferAt ?? _activeDoc?.lastTransferAt,
      lastTransferFileName:
          lastTransferFileName ?? _activeDoc?.lastTransferFileName,
      lastTransferChecksum:
          lastTransferChecksum ?? _activeDoc?.lastTransferChecksum,
      lastTransferMode: lastTransferMode ?? _activeDoc?.lastTransferMode,
      lastRemoteJobId: _activeDoc?.lastRemoteJobId,
      lastRemoteCommandId: _activeDoc?.lastRemoteCommandId,
      lastRemoteAgentId: _activeDoc?.lastRemoteAgentId,
      lastDeliveryErrorCode: _activeDoc?.lastDeliveryErrorCode,
      lastDeliveryErrorLabel: _activeDoc?.lastDeliveryErrorLabel,
      versionHistory: versionHistory ?? _activeDoc?.versionHistory ?? const [],
      favorite: favorite ?? existing?.favorite ?? false,
      libraryFolder: libraryFolder ?? existing?.libraryFolder ?? '',
      tags: tags ?? existing?.tags ?? const [],
      libraryState:
          libraryState ?? existing?.libraryState ?? PlanLibraryState.active,
      isProtected: isProtected ?? existing?.isProtected ?? false,
      trashedAt: clearTrashedAt ? null : (trashedAt ?? existing?.trashedAt),
    );
  }

  Future<BusinessPlanDocument> _savePlan({bool silent = false}) async {
    final input = _currentInput;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _activePlanId ?? BusinessPlanningStore.newPlanId();
    final existing = _activePlanId == null
        ? null
        : _allPlans.cast<BusinessPlanDocument?>().firstWhere(
            (p) => p?.id == id,
            orElse: () => null,
          );

    final analysis = _ensureAnalysis(input);
    final doc = _buildDocument(
      id: id,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: existing?.status ?? PlanningStatus.draft,
      input: input,
      analysis: analysis,
      instruction: _instruction ?? existing?.instruction,
      instructionId: existing?.instructionId ?? _stableInstructionId(id),
      version: existing?.version ?? _version,
      versionHistory: existing?.versionHistory,
    );

    await _store.upsertPlan(doc);
    await _persistDraft();
    await _refreshPlans();
    if (!mounted) return doc;
    setState(() {
      _activePlanId = id;
      _instructionId = doc.stableInstructionId;
      _version = doc.version;
      _analysis = analysis;
      _activeDoc = doc;
      if (_instruction == null && doc.instruction != null) {
        _instruction = doc.instruction;
      }
    });
    if (!silent) _snack('기획안을 임시 저장했습니다.');
    return doc;
  }

  bool get _devWorkDocFolderReady => _devDocState?.readyToWrite == true;

  bool _planningInputMatchesInstruction(
    BusinessPlanInput input,
    WorkInstruction wi,
  ) {
    final artifact = input.resolvedArtifactType == ArtifactType.undecided
        ? (wi.artifactType.isEmpty ? ArtifactType.ebook : wi.artifactType)
        : input.resolvedArtifactType;
    final wiArtifact = wi.artifactType.isEmpty
        ? artifact
        : ArtifactType.normalize(wi.artifactType);
    return input.topic.trim() == wi.businessIdea.trim() &&
        input.customerProblem.trim() == wi.customerProblem.trim() &&
        input.targetCustomer.trim() == wi.targetCustomer.trim() &&
        input.desiredOutcome.trim() == wi.businessPurpose.trim() &&
        ArtifactType.normalize(artifact) == wiArtifact &&
        input.notes.trim() == wi.notes.trim();
  }

  /// 새 ebook + pilot 토글 ON일 때만 고정 정책. 기존 WI 자동 migration 없음.
  AiExecutionPolicy? _resolveAiExecutionForBuild(BusinessPlanInput input) {
    if (!_aiProductionPilot) return null;
    final artifact = input.resolvedArtifactType == ArtifactType.undecided
        ? ArtifactType.ebook
        : ArtifactType.normalize(input.resolvedArtifactType);
    if (artifact != ArtifactType.ebook) return null;
    return AiExecutionPolicy.pilotCodexStage1;
  }

  Future<void> _createInstruction() async {
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
    if (_instruction != null) {
      _snack('이미 작업지시서가 있습니다. 「수정」 또는 「새 버전」을 사용하세요.');
      return;
    }
    if (!_devWorkDocFolderReady) {
      _snack('DevWorkDoc 폴더를 먼저 설정하세요. JSON만 필요하면 「JSON 다운로드」를 사용하세요.');
      return;
    }
    await _saveInstructionInternal(
      version: 1,
      isNewVersion: false,
      appendPreviousToHistory: false,
      saveTarget: DevWorkDocSaveTarget.folder,
    );
  }

  Future<void> _downloadInstructionJson() async {
    if (_transferBusy) {
      _snack('Inbox 직접 전달 중에는 수동 다운로드를 실행할 수 없습니다.');
      return;
    }
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
    // 수동 다운로드 전용 경로 (Inbox writeJsonFile과 분리)
    await _saveInstructionInternal(
      version: _instruction == null ? 1 : _version,
      isNewVersion: false,
      appendPreviousToHistory: false,
      saveTarget: DevWorkDocSaveTarget.downloadOnly,
    );
  }

  Future<void> _editInstruction() async {
    if (!_canCreateInstruction || _instruction == null) {
      _snack('수정할 작업지시서가 없거나 필수 항목이 부족합니다.');
      return;
    }
    await _saveInstructionInternal(
      version: _version,
      isNewVersion: false,
      appendPreviousToHistory: false,
      saveTarget: DevWorkDocSaveTarget.folder,
    );
  }

  Future<void> _createNewVersion() async {
    if (!_canCreateInstruction || _instruction == null || _activeDoc == null) {
      _snack('새 버전을 만들 수 없습니다. 필수 항목을 확인하세요.');
      return;
    }
    if (_needsVersionRecovery) {
      _snack('부분 저장 또는 충돌 상태입니다. 먼저 「기존 버전 확인 및 복구」를 진행하세요.');
      await _openVersionDiagnoseAndRecover();
      return;
    }
    if (!_folderVersionConfirmed) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('다음 버전 생성'),
          content: const Text(
            '직전 버전의 DevWorkDoc 저장이 확정되지 않았습니다.\n'
            '그래도 현재 내용을 다음 버전으로 생성할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('다음 버전으로 생성'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    await _saveInstructionInternal(
      version: _version + 1,
      isNewVersion: true,
      appendPreviousToHistory: true,
      saveTarget: DevWorkDocSaveTarget.folder,
    );
  }

  bool get _folderVersionConfirmed {
    final r = _lastDevWorkDocResult;
    if (r == null) return false;
    if (r.instructionId != null &&
        _instructionId != null &&
        r.instructionId != _instructionId &&
        r.instructionId != _instruction?.instructionId) {
      return false;
    }
    if (r.version != null && r.version != _version) return false;
    return r.isFolderCompleteSuccess ||
        (r.outcome == DevWorkDocSaveOutcome.alreadyExists &&
            r.activeVerified &&
            r.versionsVerified) ||
        r.outcome == DevWorkDocSaveOutcome.recoveredFromPartial;
  }

  bool get _needsVersionRecovery {
    final r = _lastDevWorkDocResult;
    if (r == null) return false;
    if (r.ok) return false;
    if (r.instructionId != null &&
        _instruction != null &&
        r.instructionId != _instruction!.instructionId) {
      return false;
    }
    return r.outcome == DevWorkDocSaveOutcome.conflict ||
        r.outcome == DevWorkDocSaveOutcome.partialSuccess;
  }

  Future<void> _showConflictOrRecoverDialog({
    required DevWorkDocWriteResult saveResult,
  }) async {
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Versions v${saveResult.version ?? _version} 충돌'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(saveResult.message ?? '기존 Versions와 핵심 내용이 다릅니다.'),
              if (saveResult.conflictDiffSummary != null) ...[
                const SizedBox(height: 12),
                const Text(
                  '차이 요약',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(saveResult.conflictDiffSummary!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'diagnose'),
            child: const Text('기존 버전 확인'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'next'),
            child: const Text('다음 버전으로 생성'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'diagnose') {
      await _openVersionDiagnoseAndRecover();
    } else if (choice == 'next') {
      await _saveInstructionInternal(
        version: _version + 1,
        isNewVersion: true,
        appendPreviousToHistory: true,
        saveTarget: DevWorkDocSaveTarget.folder,
      );
    }
  }

  Future<void> _openVersionDiagnoseAndRecover() async {
    if (_instruction == null) {
      _snack('작업지시서가 없습니다.');
      return;
    }
    if (!_devWorkDocFolderReady) {
      _snack('DevWorkDoc 폴더를 먼저 설정하세요.');
      return;
    }
    final artifact = _currentInput.resolvedArtifactType;
    final iid = _instruction!.instructionId;
    final appJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(_instruction!.toJson());
    final diagnosis = await _devWorkDoc.diagnoseInstruction(
      artifactType: artifact,
      instructionId: iid,
      appVersion: _version,
      appJsonText: appJson,
    );
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final lines = <Widget>[
          Text(diagnosis.summary),
          const SizedBox(height: 8),
          Text(
            diagnosis.nextAction,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...diagnosis.versions.map(
            (v) => Text(
              'Versions v${v.version}: ${v.exists ? '${v.size}B / ${v.stableChecksum}' : '없음'}'
              '${v.parseOk ? '' : ' (파싱 실패)'}',
            ),
          ),
          Text(
            diagnosis.activeExists
                ? 'Active: v${diagnosis.activeVersion ?? '?'} '
                      '${diagnosis.activeBytes}B / ${diagnosis.activeStableChecksum}'
                : 'Active: 없음',
          ),
          Text(
            '앱: v${diagnosis.appVersion ?? _version} / '
            '${diagnosis.appStableChecksum.isEmpty ? '(없음)' : diagnosis.appStableChecksum}',
          ),
        ];
        return AlertDialog(
          title: const Text('기존 버전 확인 및 복구'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('취소'),
            ),
            if (diagnosis.recommendedVersion != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'restore'),
                child: Text(
                  'Versions v${diagnosis.recommendedVersion} → Active 복구',
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'next'),
              child: const Text('현재 내용을 다음 버전으로'),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null || action == 'cancel') return;

    if (action == 'restore' && diagnosis.recommendedVersion != null) {
      final result = await _devWorkDoc.restoreActiveFromVersion(
        artifactType: artifact,
        instructionId: iid,
        version: diagnosis.recommendedVersion!,
      );
      if (!mounted) return;
      setState(() => _lastDevWorkDocResult = result);
      ScaffoldMessenger.of(context).clearSnackBars();
      if (result.ok) {
        // 앱 지시서를 Versions 스냅샷에 맞춤
        final verText = await _devWorkDoc.readVersionFile(
          artifactType: artifact,
          instructionId: iid,
          version: diagnosis.recommendedVersion!,
        );
        if (verText != null && mounted) {
          await _mirrorActiveSoft(
            artifactType: artifact,
            instructionId: iid,
            jsonText: verText,
            version: diagnosis.recommendedVersion!,
          );
          try {
            final restored = WorkInstruction.fromJson(
              Map<String, dynamic>.from(jsonDecode(verText) as Map),
            );
            final id = _activePlanId;
            if (id != null) {
              final existing = _allPlans.firstWhere((p) => p.id == id);
              final doc = existing.copyWith(
                instruction: restored,
                version: diagnosis.recommendedVersion,
                updatedAt: DateTime.now().toUtc().toIso8601String(),
                status: PlanningStatus.instructionReady,
              );
              await _store.upsertPlan(doc);
              await _refreshPlans();
              if (!mounted) return;
              setState(() {
                _instruction = restored;
                _version = diagnosis.recommendedVersion!;
                _activeDoc = doc;
              });
            }
          } catch (_) {}
        }
        _snack(result.message ?? 'Active 복구 완료');
      } else {
        _snack(result.message ?? 'Active 복구 실패');
      }
      return;
    }

    if (action == 'next') {
      await _saveInstructionInternal(
        version: _version + 1,
        isNewVersion: true,
        appendPreviousToHistory: true,
        saveTarget: DevWorkDocSaveTarget.folder,
      );
    }
  }

  Future<void> _saveInstructionInternal({
    required int version,
    required bool isNewVersion,
    required bool appendPreviousToHistory,
    DevWorkDocSaveTarget saveTarget = DevWorkDocSaveTarget.folder,
  }) async {
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
    if (saveTarget == DevWorkDocSaveTarget.folder &&
        _instruction == null &&
        !_devWorkDocFolderReady) {
      _snack('DevWorkDoc 폴더를 먼저 설정하세요.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final input = _currentInput;
    final analysis = _ensureAnalysis(input);
    final now = DateTime.now().toUtc();
    final id = _activePlanId ?? BusinessPlanningStore.newPlanId();
    final existing = _allPlans.cast<BusinessPlanDocument?>().firstWhere(
      (p) => p?.id == id,
      orElse: () => null,
    );

    final iid = existing?.stableInstructionId ?? _stableInstructionId(id);
    var history = List<PlanVersionSnapshot>.from(
      existing?.versionHistory ?? const [],
    );

    if (appendPreviousToHistory && existing?.instruction != null) {
      history.add(
        PlanVersionSnapshot(
          version: existing!.version,
          createdAt: existing.updatedAt,
          status: existing.status,
          instruction: existing.instruction,
          transferFileName: existing.lastTransferFileName,
          transferredAt: existing.lastTransferAt,
          checksum: existing.lastTransferChecksum,
        ),
      );
    }

    final existingInstruction = existing?.instruction;
    final preserveCreatedAt = isNewVersion || existingInstruction == null
        ? null
        : existingInstruction.createdAt;
    final preserveUpdatedAt = isNewVersion || existingInstruction == null
        ? null
        : existingInstruction.updatedAt;

    final artifact = input.resolvedArtifactType;
    late WorkInstruction instruction;
    late String jsonText;

    // 동일 버전 + 기획 입력 미변경: 디스크 Versions(우선) 또는 앱 스냅샷 재사용
    // buildInstruction 재생성으로 파생 필드가 달라져 구형 파일과 Conflict 나던 문제 방지
    final sameVersionReuse =
        !isNewVersion &&
        existingInstruction != null &&
        existingInstruction.instructionVersion == '$version' &&
        _planningInputMatchesInstruction(input, existingInstruction);

    if (sameVersionReuse) {
      instruction = existingInstruction;
      String? diskVersion;
      if (saveTarget == DevWorkDocSaveTarget.folder && _devWorkDocFolderReady) {
        diskVersion = await _devWorkDoc.readVersionFile(
          artifactType: artifact,
          instructionId: iid,
          version: version,
        );
      }
      if (diskVersion != null && diskVersion.trim().isNotEmpty) {
        final diskDiff = diffInstructionContent(
          diskVersion,
          existingInstruction.toJson(),
        );
        if (diskDiff.isSameCore || diskDiff.coreDiffFieldCount == 0) {
          jsonText = diskVersion;
        } else {
          // 앱 스냅샷이 파생 필드로 달라도, 기획 입력이 디스크와 같으면 Versions를 기준으로 사용
          try {
            final diskInst = WorkInstruction.fromJson(
              Map<String, dynamic>.from(jsonDecode(diskVersion) as Map),
            );
            if (_planningInputMatchesInstruction(input, diskInst)) {
              jsonText = diskVersion;
              instruction = diskInst;
            } else {
              jsonText = const JsonEncoder.withIndent(
                '  ',
              ).convert(existingInstruction.toJson());
            }
          } catch (_) {
            jsonText = const JsonEncoder.withIndent(
              '  ',
            ).convert(existingInstruction.toJson());
          }
        }
      } else {
        jsonText = const JsonEncoder.withIndent(
          '  ',
        ).convert(existingInstruction.toJson());
      }
    } else {
      final aiExecution = _resolveAiExecutionForBuild(input);
      var built = _service.buildInstruction(
        planId: id,
        input: input,
        analysis: analysis,
        now: now,
        instructionId: iid,
        version: version,
        createdAt: preserveCreatedAt,
        updatedAt: preserveUpdatedAt,
        status: PlanningStatus.instructionReady,
        aiExecution: aiExecution,
      );
      final sourceFileName =
          'WI_${DevWorkDocPaths.sanitizeInstructionId(iid)}.json';
      final withSums = withCanonicalChecksumFields({
        ...built.toJson(),
        'sourceFileName': sourceFileName,
      });
      final checksum = '${withSums['contentChecksum'] ?? ''}';
      instruction = _service.buildInstruction(
        planId: id,
        input: input,
        analysis: analysis,
        now: now,
        instructionId: iid,
        version: version,
        createdAt: built.createdAt,
        updatedAt: built.updatedAt,
        checksum: checksum,
        sourceFileName: sourceFileName,
        status: PlanningStatus.instructionReady,
        aiExecution: aiExecution,
      );
      jsonText = const JsonEncoder.withIndent(
        '  ',
      ).convert(withCanonicalChecksumFields(instruction.toJson()));
    }

    final DevWorkDocWriteResult saveResult;
    if (saveTarget == DevWorkDocSaveTarget.downloadOnly) {
      saveResult = await _devWorkDoc.downloadInstructionJson(
        artifactType: artifact,
        instructionId: iid,
        version: version,
        jsonText: jsonText,
      );
    } else {
      saveResult = await _devWorkDoc.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: version,
        jsonText: jsonText,
        isNewVersion: isNewVersion && version > 1,
      );
    }

    final isDownloadTarget = saveTarget == DevWorkDocSaveTarget.downloadOnly;
    final isFolderSuccess =
        !isDownloadTarget &&
        (saveResult.isFolderCompleteSuccess ||
            (saveResult.outcome == DevWorkDocSaveOutcome.alreadyExists &&
                saveResult.activeVerified &&
                saveResult.versionsVerified) ||
            saveResult.outcome == DevWorkDocSaveOutcome.recoveredFromPartial);
    final isDownloadComplete =
        isDownloadTarget &&
        saveResult.mode == 'download' &&
        saveResult.outcome == DevWorkDocSaveOutcome.downloadOnly;

    if (!isFolderSuccess && !isDownloadComplete) {
      if (mounted) {
        setState(() => _lastDevWorkDocResult = saveResult);
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      final failureMessage = saveResult.message ?? 'DevWorkDoc 저장에 실패했습니다.';
      if (!isDownloadTarget &&
          saveResult.outcome == DevWorkDocSaveOutcome.conflict &&
          mounted) {
        await _showConflictOrRecoverDialog(saveResult: saveResult);
        return;
      }
      if (!isDownloadTarget && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage),
            action: SnackBarAction(
              label: '진단·복구',
              onPressed: _openVersionDiagnoseAndRecover,
            ),
          ),
        );
      } else {
        _snack(failureMessage);
      }
      return;
    }

    final validation = _contractValidator.validate(
      input: input,
      instruction: instruction,
    );
    final status = isDownloadComplete
        ? PlanningStatus.downloadedPendingImport
        : validation.canTransfer
        ? PlanningStatus.instructionReady
        : PlanningStatus.validationRequired;

    final doc = _buildDocument(
      id: id,
      createdAt: existing?.createdAt ?? now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      status: status,
      input: input,
      analysis: analysis,
      instruction: instruction,
      instructionId: iid,
      version: version,
      versionHistory: history,
      lastTransferAt: isDownloadComplete ? now.toIso8601String() : null,
      lastTransferFileName: isDownloadComplete ? saveResult.fileName : null,
      lastTransferChecksum: isDownloadComplete ? saveResult.checksum : null,
      lastTransferMode: isDownloadComplete
          ? PlanProgressStatus.downloadMode
          : null,
    );

    await _store.upsertPlan(doc);
    await _persistDraft();
    await _refreshPlans();
    if (!mounted) return;

    setState(() {
      _activePlanId = id;
      _instructionId = iid;
      _version = version;
      _analysis = analysis;
      _instruction = instruction;
      _activeDoc = doc;
      _lastDevWorkDocResult = saveResult;
    });

    if (isDownloadComplete) {
      _snack(
        'JSON 다운로드 완료 · 수동 가져오기 대기 '
        '(전달됨 아님). v$version · ${saveResult.fileName ?? ''}',
      );
    } else if (saveResult.isFolderCompleteSuccess ||
        saveResult.outcome == DevWorkDocSaveOutcome.recoveredFromPartial) {
      await _mirrorActiveSoft(
        artifactType: artifact,
        instructionId: iid,
        jsonText: jsonText,
        version: version,
        title: instruction.businessIdea.isNotEmpty
            ? instruction.businessIdea
            : instruction.projectId,
      );
      _snack(
        saveResult.outcome == DevWorkDocSaveOutcome.recoveredFromPartial
            ? '부분 저장 복구 완료. v$version\n'
                  'Active: ${saveResult.activeBytes}B · Versions: ${saveResult.versionsBytes}B'
            : 'DevWorkDoc에 저장했습니다. v$version\n'
                  'Active: 저장·검증 완료 (${saveResult.activeBytes}B)\n'
                  'Versions: v$version 저장·검증 완료 (${saveResult.versionsBytes}B)',
      );
    } else if (saveResult.outcome == DevWorkDocSaveOutcome.alreadyExists) {
      await _mirrorActiveSoft(
        artifactType: artifact,
        instructionId: iid,
        jsonText: jsonText,
        version: version,
        title: instruction.businessIdea.isNotEmpty
            ? instruction.businessIdea
            : instruction.projectId,
      );
      _snack(
        saveResult.message?.contains('구형') == true
            ? '${saveResult.message}\nActive·Versions v$version 유지'
            : 'DevWorkDoc 기존 파일 확인 (동일 핵심 checksum). v$version\n'
                  'Active·Versions v$version 검증 완료',
      );
    } else if (validation.canTransfer) {
      _snack(
        validation.level == ContractValidationLevel.warning
            ? '작업지시서를 생성했습니다. (v$version, WARNING — 전달 전 확인 필요)'
            : '작업지시서를 생성했습니다. (v$version)',
      );
    } else {
      _snack('작업지시서를 생성했으나 BLOCKED입니다. 「기타 작업」에서 검증을 확인하세요.');
    }
  }

  Future<void> _transferToWork() async {
    if (_transferBusy) return;
    if (_instruction == null) {
      _snack('먼저 작업지시서를 생성하세요.');
      return;
    }
    if (_needsVersionRecovery) {
      _snack('부분 저장 또는 충돌 상태입니다. 먼저 Active를 복구하세요.');
      await _openVersionDiagnoseAndRecover();
      return;
    }

    final validation = _contractValidator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
    if (!validation.canTransfer) {
      _snack(
        '전달 차단(BLOCKED): ${validation.blockers.isNotEmpty ? validation.blockers.first.reason : validation.issues.first.reason}',
      );
      return;
    }
    if (validation.level == ContractValidationLevel.warning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('WARNING — 전달 전 확인'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('경고가 있습니다. 내용을 확인한 뒤 전달할 수 있습니다.'),
                const SizedBox(height: 12),
                for (final issue in validation.warnings.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('· ${issue.field}: ${issue.reason}'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인하고 전달'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final iid = _instruction!.instructionId.trim().isNotEmpty
        ? _instruction!.instructionId
        : (_activeDoc?.stableInstructionId ?? '');
    final artifact = _currentInput.resolvedArtifactType;
    if (iid.isEmpty || artifact == ArtifactType.undecided) {
      _snack('instructionId 또는 결과물 유형이 없어 전달할 수 없습니다.');
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작업을 전송할까요?'),
        content: Text(
          '「${_currentInput.topic}」을 연결된 노트북 Agent로 전달합니다.\n'
          '전송이 성공해야 전달됨으로 표시됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('전달'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _deliverActiveInstruction(
      instructionId: iid,
      artifactType: artifact,
      ensurePilot: _aiProductionPilot,
      silent: false,
    );
  }

  Future<void> _maybeRepairOrphan() async {
    if (_transferBusy || _loading) return;
    const iid = WorkInstructionRemoteDelivery.orphanProductionInstructionId;
    BusinessPlanDocument? plan;
    for (final p in _allPlans) {
      if (p.stableInstructionId == iid) plan = p;
    }
    if (plan == null || plan.instruction == null) return;
    if (WorkInstructionRemoteDelivery.isProtectedSkip(iid)) return;
    final existing = WorkInstructionRemoteDelivery.findJob(_remoteJobs, iid);
    if (existing != null) {
      if (!plan.hasRemoteDelivery) {
        final cmds = await _agentRepo.listCommands(existing.jobId);
        final start = WorkInstructionRemoteDelivery.findStartJob(cmds);
        if (start != null) {
          final doc = WorkInstructionRemoteDelivery.markDelivered(
            plan: plan,
            result: RemoteDeliveryResult(
              delivered: true,
              jobId: existing.jobId,
              commandId: start.commandId,
              agentId: existing.assignedAgentId,
              outcome: 'reused',
            ),
            instruction: plan.instruction,
          );
          await _store.upsertPlan(doc);
          await _refreshPlans();
          if (mounted && _activePlanId == plan.id) {
            setState(() {
              _activeDoc = doc;
              _instruction = doc.instruction;
            });
          }
        }
      }
      return;
    }
    if (_orphanRepairStarted) return;
    if (WorkInstructionRemoteDelivery.pickTargetAgent(_remoteAgents) == null) {
      return;
    }
    _orphanRepairStarted = true;
    await _deliverActiveInstruction(
      instructionId: iid,
      artifactType: plan.input.resolvedArtifactType.isEmpty
          ? ArtifactType.ebook
          : plan.input.resolvedArtifactType,
      ensurePilot: true,
      silent: true,
      planOverride: plan,
    );
  }

  Future<void> _deliverActiveInstruction({
    required String instructionId,
    required String artifactType,
    required bool ensurePilot,
    required bool silent,
    BusinessPlanDocument? planOverride,
  }) async {
    if (_transferBusy) return;
    setState(() => _transferBusy = true);
    try {
      if (!silent) await _savePlan(silent: true);
      var plan =
          planOverride ??
          (_activePlanId == null
              ? null
              : _allPlans.cast<BusinessPlanDocument?>().firstWhere(
                  (p) => p?.id == _activePlanId,
                  orElse: () => null,
                ));
      plan ??= _activeDoc;
      if (plan == null || plan.instruction == null) {
        if (!silent) _snack('전달할 작업지시서가 없습니다.');
        return;
      }

      Map<String, dynamic> payload = Map<String, dynamic>.from(
        plan.instruction!.toJson(),
      );
      if (_devWorkDocFolderReady) {
        final activeText = await _devWorkDoc.readActive(
          artifactType,
          instructionId,
        );
        if (activeText != null && activeText.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(activeText);
            if (decoded is Map &&
                '${decoded['instructionId'] ?? ''}'.trim() == instructionId) {
              payload = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      }

      final attach = WorkInstructionRemoteDelivery.shouldAttachPilot(
        toggleOn: ensurePilot,
        instruction: WorkInstruction.fromJson(payload),
        repairOrphan: WorkInstructionRemoteDelivery.isOrphanProduction(
          instructionId,
        ),
      );
      if (attach) {
        payload = WorkInstructionRemoteDelivery.attachPilotAiExecution(payload);
      }
      payload['instructionId'] = instructionId;
      final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
      final instruction = WorkInstruction.fromJson(payload);

      await _mirrorActiveSoft(
        artifactType: artifactType,
        instructionId: instructionId,
        jsonText: jsonText,
        version: plan.version,
        title: instruction.businessIdea,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final result = await _delivery.deliver(
        instructionId: instructionId,
        title: instruction.businessIdea.isNotEmpty
            ? instruction.businessIdea
            : plan.input.topic,
        type: ArtifactType.normalize(artifactType),
        payload: payload,
        totalStages: instruction.workflowSteps.isEmpty
            ? 18
            : instruction.workflowSteps.length,
        ownerUid: uid,
      );

      final existing = _allPlans.firstWhere(
        (p) => p.id == plan!.id,
        orElse: () => plan!,
      );
      final transientAgentGap =
          silent &&
          (result.errorCode == 'agent_offline' ||
              result.errorCode == 'agent_missing');
      if (!result.delivered && transientAgentGap) {
        _orphanRepairStarted = false;
        return;
      }
      final doc = result.delivered
          ? WorkInstructionRemoteDelivery.markDelivered(
              plan: existing,
              result: result,
              instruction: instruction,
            )
          : WorkInstructionRemoteDelivery.markFailed(
              plan: existing,
              result: result,
            );
      if (result.delivered || !silent) {
        await _store.upsertPlan(doc);
        await _refreshPlans();
      }
      if (!mounted) return;
      final viewing = _activePlanId == plan.id;
      if (viewing && (result.delivered || !silent)) {
        setState(() {
          _activeDoc = doc;
          _instruction = instruction;
        });
      }
      if (result.delivered) {
        if (!silent) {
          _snack('소통24워크 Agent로 전달했습니다.');
        } else if (result.outcome == 'created' ||
            result.outcome == 'command_repaired') {
          _snack('기존 작업을 Agent로 복구 전송했습니다.');
        }
      } else if (!silent) {
        await _showTransferFailedDialog(result.userMessage);
      } else {
        _snack(result.userMessage);
      }
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _showTransferFailedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전송 실패'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTransferFolder() async {
    final state = await _transfer.pickFolder();
    if (!mounted) return;
    setState(() => _folderState = state);
    if (state.readyToWrite) {
      _snack('전달 폴더 준비 완료: ${state.folderName ?? 'Inbox'}');
    } else {
      _snack(
        state.statusMessage.isNotEmpty
            ? state.statusMessage
            : '전달 폴더를 다시 선택해 주세요.',
      );
    }
  }

  Future<void> _copyJson() async {
    final doc = await _savePlan(silent: true);
    final json = const JsonEncoder.withIndent('  ').convert(doc.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    _snack('JSON을 클립보드에 복사했습니다.');
  }

  Future<void> _copyReadableInstruction() async {
    if (_instruction == null) {
      _snack('작업지시서를 먼저 생성하세요.');
      return;
    }
    final text = _service.buildReadableInstruction(_instruction!);
    await Clipboard.setData(ClipboardData(text: text));
    _snack('텍스트 지시서를 복사했습니다.');
  }

  Future<void> _copyCursorPrompt() async {
    if (_instruction == null) {
      _snack('작업지시서를 먼저 생성하세요.');
      return;
    }
    final text = _service.buildCursorPrompt(
      input: _currentInput,
      instruction: _instruction!,
    );
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Cursor 프롬프트를 복사했습니다.');
  }

  Future<void> _duplicatePlan() async {
    if (!_hasSomeContent) {
      _snack('복제할 내용이 없습니다.');
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = BusinessPlanningStore.newPlanId();
    final input = _currentInput;
    final analysis =
        _analysis ?? (_canCreateInstruction ? _service.analyze(input) : null);
    final sourceId = _activePlanId;
    final lineageTags = <String>[
      if (sourceId != null && sourceId.isNotEmpty) ...[
        'cloneOf:$sourceId',
        'sourcePlanId:$sourceId',
      ],
    ];
    final doc = BusinessPlanDocument(
      id: id,
      input: input,
      status: PlanningStatus.draft,
      createdAt: now,
      updatedAt: now,
      analysis: analysis,
      instructionId: _stableInstructionId(id),
      tags: lineageTags,
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() {
      _activePlanId = id;
      _instructionId = doc.stableInstructionId;
      _version = 1;
      _instruction = null;
      _activeDoc = doc;
    });
    _snack('기획안을 복제했습니다.');
  }

  Future<void> _mirrorActiveSoft({
    required String artifactType,
    required String instructionId,
    required String jsonText,
    int? version,
    String? title,
  }) async {
    final ok = await _wiMirror.upsertActive(
      artifactType: artifactType,
      instructionId: instructionId,
      jsonText: jsonText,
      version: version,
      title: title,
    );
    if (!ok && mounted) {
      _snack('원격 작업지시 동기화에 실패했습니다. 로컬 저장은 유지됩니다.');
    }
  }

  Future<void> _archiveInstruction() async {
    if (_instruction == null || _activePlanId == null) {
      _snack('보관할 작업지시서가 없습니다.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작업지시서 보관'),
        content: const Text('작업지시서를 보관함으로 이동하시겠습니까?\n필요하면 다시 복원할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('보관'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final input = _currentInput;
    final artifact = input.resolvedArtifactType;
    final iid = _instruction!.instructionId;
    final result = await _devWorkDoc.archiveInstruction(
      artifactType: artifact,
      instructionId: iid,
      version: _version,
    );
    if (!result.ok) {
      _snack(result.message ?? '보관에 실패했습니다.');
      return;
    }

    await _wiMirror.markArchived(artifactType: artifact, instructionId: iid);

    final id = _activePlanId!;
    final existing = _allPlans.firstWhere((p) => p.id == id);
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = existing.copyWith(
      status: PlanningStatus.archived,
      updatedAt: now,
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() => _activeDoc = doc);
    _snack('작업지시서를 보관함으로 이동했습니다.');
  }

  Future<void> _restoreInstruction() async {
    if (_instruction == null || _activePlanId == null) {
      _snack('복원할 작업지시서가 없습니다.');
      return;
    }
    final input = _currentInput;
    final artifact = input.resolvedArtifactType;
    final iid = _instruction!.instructionId;
    final result = await _devWorkDoc.restoreInstruction(
      artifactType: artifact,
      instructionId: iid,
    );
    if (!result.ok) {
      _snack(result.message ?? '복원에 실패했습니다.');
      return;
    }

    final restoredText = await _devWorkDoc.readActive(artifact, iid);
    if (restoredText != null && restoredText.isNotEmpty) {
      await _mirrorActiveSoft(
        artifactType: artifact,
        instructionId: iid,
        jsonText: restoredText,
        version: _version,
        title: _instruction?.businessIdea,
      );
    } else {
      await _wiMirror.restoreActive(artifactType: artifact, instructionId: iid);
    }

    final id = _activePlanId!;
    final existing = _allPlans.firstWhere((p) => p.id == id);
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = existing.copyWith(
      status: PlanningStatus.instructionReady,
      updatedAt: now,
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() => _activeDoc = doc);
    _snack('작업지시서를 복원했습니다.');
  }

  Future<void> _permanentDeleteInstruction() async {
    if (_docStatus != PlanningStatus.archived) {
      _snack('영구 삭제는 보관 상태에서만 가능합니다.');
      return;
    }
    if (_instruction == null || _activePlanId == null) return;

    final input = _currentInput;
    final artifact = input.resolvedArtifactType;
    final iid = _instruction!.instructionId;
    final versionCount = 1 + (_activeDoc?.versionHistory.length ?? 0);
    final filesHint = [
      DevWorkDocPaths.activeRelative(artifact, iid),
      DevWorkDocPaths.archiveRelative(artifact, iid, _version),
      DevWorkDocPaths.versionDirRelative(artifact, iid),
    ].join('\n');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작업지시서 영구 삭제'),
        content: SingleChildScrollView(
          child: Text(
            '「${_currentInput.topic.isEmpty ? '제목 없음' : _currentInput.topic}」\n'
            'ID: $iid · 버전 $versionCount개\n\n'
            '삭제 대상:\n$filesHint\n\n'
            '이 작업은 되돌릴 수 없습니다.'
            '${_activeDoc?.wasTransferred == true ? '\n\n소통24워크 Agent 쪽 파일은 자동 삭제되지 않습니다.' : ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ControlColors.accentWarm,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _devWorkDoc.permanentDelete(
      artifactType: artifact,
      instructionId: iid,
    );
    if (!result.ok) {
      _snack(result.message ?? '삭제에 실패했습니다.');
      return;
    }

    final id = _activePlanId!;
    final existing = _allPlans.firstWhere((p) => p.id == id);
    final now = DateTime.now().toUtc().toIso8601String();
    final doc = existing.copyWith(
      status: PlanningStatus.draft,
      updatedAt: now,
      clearInstruction: true,
      version: 1,
      versionHistory: const [],
    );
    await _store.upsertPlan(doc);
    await _refreshPlans();
    if (!mounted) return;
    setState(() {
      _instruction = null;
      _version = 1;
      _activeDoc = doc;
    });
    _snack('작업지시서를 영구 삭제했습니다.');
  }

  Future<void> _useNestedDevWorkDocFolder() async {
    final state = await _devWorkDoc.useNestedDevWorkDocFolder();
    if (!mounted) return;
    setState(() => _devDocState = state);
    _snack(
      state.statusMessage.isNotEmpty
          ? state.statusMessage
          : 'DevWorkDoc 하위 폴더로 전환했습니다.',
    );
  }

  Future<void> _pickDevWorkDocFolder() async {
    final state = await _devWorkDoc.pickRootFolder();
    if (!mounted) return;
    if (state.hasRoot) {
      final structure = await _devWorkDoc.ensureStructure();
      if (!mounted) return;
      if (!structure.ok && structure.mode == 'failed') {
        _snack(structure.message ?? '폴더 구조 생성에 실패했습니다.');
      }
    }
    final refreshed = await _devWorkDoc.currentState();
    if (!mounted) return;
    setState(() => _devDocState = refreshed);
    if (refreshed.hasRoot && refreshed.rootFolderName != null) {
      _snack('DevWorkDoc 폴더: ${refreshed.rootFolderName}');
    }
  }

  DevWorkDocMigrateItemResult _buildMigrateItemResult({
    required BusinessPlanDocument plan,
    required String artifact,
    required DevWorkDocWriteResult result,
  }) {
    final title = plan.input.topic.isEmpty
        ? plan.stableInstructionId
        : plan.input.topic;
    final iid = plan.stableInstructionId;
    final v = plan.version;

    if (result.mode == 'download' ||
        result.outcome == DevWorkDocSaveOutcome.downloadOnly) {
      return DevWorkDocMigrateItemResult(
        title: title,
        instructionId: iid,
        artifactType: artifact,
        outcome: DevWorkDocSaveOutcome.downloadOnly,
        summary: '다운로드만: $title (폴더 저장 아님)',
        failureReason: result.message ?? '폴더 직접 저장 불가',
        nextAction: 'DevWorkDoc 폴더를 설정한 뒤 다시 마이그레이션하세요.',
      );
    }

    if (result.isFolderCompleteSuccess) {
      return DevWorkDocMigrateItemResult(
        title: title,
        instructionId: iid,
        artifactType: artifact,
        outcome: DevWorkDocSaveOutcome.completeSuccess,
        summary: '완전 성공: $title / Active 저장·검증 완료 / Versions v$v 저장·검증 완료',
        activeResult: 'Active 저장·검증 완료 (${result.activeBytes}B)',
        versionsResult: 'Versions v$v 저장·검증 완료 (${result.versionsBytes}B)',
        verifyResult: result.message ?? 'Active·Versions 재읽기 검증 완료',
      );
    }

    if (result.outcome == DevWorkDocSaveOutcome.alreadyExists &&
        result.activeVerified &&
        result.versionsVerified) {
      return DevWorkDocMigrateItemResult(
        title: title,
        instructionId: iid,
        artifactType: artifact,
        outcome: DevWorkDocSaveOutcome.alreadyExists,
        summary: '기존 파일 확인: $title / Active·Versions v$v 동일 checksum',
        activeResult: 'Active 기존 파일 확인 (${result.activeBytes}B)',
        versionsResult: 'Versions v$v 기존 파일 확인 (${result.versionsBytes}B)',
        verifyResult: result.message ?? '다시 쓰지 않음',
      );
    }

    if (result.outcome == DevWorkDocSaveOutcome.partialSuccess) {
      final activeLine = result.activeVerified
          ? 'Active 저장·검증 완료'
          : 'Active 실패';
      final versionsLine = result.versionsVerified
          ? 'Versions v$v 저장·검증 완료'
          : 'Versions v$v 실패';
      return DevWorkDocMigrateItemResult(
        title: title,
        instructionId: iid,
        artifactType: artifact,
        outcome: DevWorkDocSaveOutcome.partialSuccess,
        summary: '부분 성공: $title / $activeLine / $versionsLine',
        activeResult: activeLine,
        versionsResult: versionsLine,
        verifyResult: result.message ?? '',
        failureReason: result.message ?? '',
        nextAction: '폴더 권한·경로를 확인한 뒤 다시 시도하세요.',
      );
    }

    if (result.outcome == DevWorkDocSaveOutcome.conflict) {
      return DevWorkDocMigrateItemResult(
        title: title,
        instructionId: iid,
        artifactType: artifact,
        outcome: DevWorkDocSaveOutcome.conflict,
        summary: '충돌: $title — 기존 파일과 내용이 다릅니다',
        failureReason: result.message ?? '충돌',
        nextAction: '기존 DevWorkDoc 파일을 확인한 뒤 수동으로 정리하세요.',
      );
    }

    if (result.outcome == DevWorkDocSaveOutcome.permissionNeeded) {
      return DevWorkDocMigrateItemResult(
        title: title,
        instructionId: iid,
        artifactType: artifact,
        outcome: DevWorkDocSaveOutcome.permissionNeeded,
        summary: '권한 필요: $title',
        failureReason: result.message ?? '권한 재승인 필요',
        nextAction: '「작업지시서 관리 폴더 설정」에서 권한을 다시 허용하세요.',
      );
    }

    return DevWorkDocMigrateItemResult(
      title: title,
      instructionId: iid,
      artifactType: artifact,
      outcome: DevWorkDocSaveOutcome.failed,
      summary: '실패: $title',
      failureReason: result.message ?? result.errorCode ?? '저장 실패',
      nextAction: '오류를 확인한 뒤 다시 시도하세요.',
    );
  }

  Future<void> _migratePlansToDevWorkDoc() async {
    final devDoc = _devDocState;
    if (devDoc == null ||
        !devDoc.readyToWrite ||
        !devDoc.hasRoot ||
        !devDoc.permissionGranted ||
        devDoc.selectionKind != DevWorkDocSelectionKind.devWorkDocRoot) {
      _snack(
        'DevWorkDoc 저장 준비가 되지 않았습니다. '
        'DevWorkDoc 폴더 자체를 선택하고 쓰기 권한·경로 구조를 확인하세요.',
      );
      return;
    }

    final withInstruction = _allPlans.where((p) => p.hasInstruction).toList();
    if (withInstruction.isEmpty) {
      _snack('마이그레이션할 작업지시서가 없습니다.');
      return;
    }

    final items = <DevWorkDocMigrateItemResult>[];
    final seenIds = <String>{};

    for (final plan in withInstruction) {
      final iid = plan.stableInstructionId;
      if (seenIds.contains(iid)) {
        items.add(
          DevWorkDocMigrateItemResult(
            title: plan.input.topic.isEmpty ? iid : plan.input.topic,
            instructionId: iid,
            artifactType: plan.instruction!.artifactType,
            outcome: DevWorkDocSaveOutcome.failed,
            summary: '건너뜀 (중복 ID): $iid',
            failureReason: '동일 instructionId 중복',
          ),
        );
        continue;
      }
      seenIds.add(iid);

      var artifact = plan.instruction!.artifactType.trim().isNotEmpty
          ? ArtifactType.normalize(plan.instruction!.artifactType)
          : plan.input.resolvedArtifactType;

      if (artifact == ArtifactType.undecided) {
        if (!mounted) return;
        final picked = await _pickArtifactDialog(
          title: '「${plan.input.topic.isEmpty ? iid : plan.input.topic}」 제작 형태',
        );
        if (picked == null) {
          items.add(
            DevWorkDocMigrateItemResult(
              title: plan.input.topic.isEmpty ? iid : plan.input.topic,
              instructionId: iid,
              artifactType: ArtifactType.undecided,
              outcome: DevWorkDocSaveOutcome.awaitingArtifact,
              summary:
                  '유형 선택 대기: ${plan.input.topic.isEmpty ? iid : plan.input.topic}',
              nextAction: '나중에 다시 마이그레이션하여 유형을 선택하세요.',
            ),
          );
          continue;
        }
        artifact = picked;
      }

      final jsonText = const JsonEncoder.withIndent(
        '  ',
      ).convert(plan.instruction!.toJson());
      final result = await _devWorkDoc.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: plan.version,
        jsonText: jsonText,
        isNewVersion: plan.version > 1,
      );
      items.add(
        _buildMigrateItemResult(plan: plan, artifact: artifact, result: result),
      );
    }

    final report = DevWorkDocMigrateReport(items: items);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DevWorkDoc 마이그레이션 결과'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '완전 성공 ${report.completeSuccessCount} · '
                '기존 확인 ${report.alreadyExistsCount} · '
                '부분 ${report.partialSuccessCount} · '
                '유형 대기 ${report.awaitingCount} · '
                '권한 ${report.permissionCount} · '
                '충돌 ${report.conflictCount} · '
                '다운로드만 ${report.downloadOnlyCount} · '
                '실패 ${report.failedCount}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final item in items) ...[
                Text(
                  '${outcomeLabelKo(item.outcome)}: ${item.summary}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (item.activeResult.isNotEmpty)
                  Text(
                    '  · ${item.activeResult}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                if (item.versionsResult.isNotEmpty)
                  Text(
                    '  · ${item.versionsResult}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                if (item.failureReason.isNotEmpty)
                  Text(
                    '  · ${item.failureReason}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ControlColors.textMuted,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickArtifactDialog({required String title}) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ArtifactType.allSelectable)
                  ActionChip(
                    label: Text(ArtifactType.labelShortKo(type)),
                    onPressed: () => Navigator.pop(ctx, type),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에 선택'),
          ),
        ],
      ),
    );
  }

  void _loadPlan(BusinessPlanDocument plan) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _activePlanId = plan.id;
      _instructionId = plan.stableInstructionId;
      _version = plan.version;
      _applyInput(plan.input);
      _analysis = plan.analysis;
      _instruction = plan.instruction;
      _activeDoc = plan;
      _aiProductionPilot = plan.instruction?.aiExecution?.enabled == true;
      if (plan.input.wizardSelections != null) {
        _wizardState = PlanningWizardState.fromJson(
          plan.input.wizardSelections!,
        );
        _designState = ProjectDesignState.fromWizardState(_wizardState);
        _inputModeQuick = _wizardState.mode != 'advanced';
      } else {
        _inputModeQuick = false;
        _wizardState = PlanningWizardState(mode: 'advanced', step: 4);
        _designState = ProjectDesignState();
      }
    });
    unawaited(_store.persistActivePlanId(plan.id));
    _persistDraft();
    _snack(
      '「${plan.input.topic.isEmpty ? '제목 없음' : plan.input.topic}」을(를) 불러왔습니다.',
    );
  }

  void _startNewPlan({IdeaToPlanningSeed? seed}) {
    FocusManager.instance.primaryFocus?.unfocus();
    final s = seed ?? widget.ideaSeed;
    setState(() {
      _activePlanId = null;
      _instructionId = null;
      _version = 1;
      _analysis = null;
      _instruction = null;
      _activeDoc = null;
      _aiProductionPilot = true;
      _inputModeQuick = true;
      _wizardState = PlanningWizardState(mode: 'quick');
      _designState = ProjectDesignState();
      if (s != null && s.title.trim().isNotEmpty) {
        final notes = [
          if (s.description.trim().isNotEmpty) s.description.trim(),
          if (s.field.trim().isNotEmpty) '상품/분야: ${s.field.trim()}',
          if (s.memo.trim().isNotEmpty) s.memo.trim(),
        ].join('\n');
        _applyInput(
          BusinessPlanInput(
            topic: s.title.trim(),
            targetCustomer: s.targetCustomer.trim(),
            notes: notes,
          ),
        );
      } else {
        _applyInput(const BusinessPlanInput());
      }
    });
    unawaited(_store.persistActivePlanId(null));
    _persistDraft();
    if (s != null && s.title.trim().isNotEmpty) {
      _snack('아이디어「${s.title}」을(를) 새 기획으로 불러왔습니다.');
    }
  }

  String? _appliedIdeaSeedId;

  void _consumeIdeaSeedIfNeeded() {
    final s = widget.ideaSeed;
    if (s == null || s.title.trim().isEmpty) return;
    final key = '${s.title}|${s.targetCustomer}|${s.memo}';
    if (_appliedIdeaSeedId == key) return;
    _appliedIdeaSeedId = key;
    _startNewPlan(seed: s);
  }

  void _showValidationIssues() {
    if (_instruction == null) {
      _snack('작업지시서가 없습니다.');
      return;
    }
    final result = _contractValidator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('검증 ${result.levelLabel}'),
        content: SingleChildScrollView(
          child: result.ok
              ? const Text('소통24워크 Agent 전달에 필요한 항목이 모두 충족됩니다.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.isBlocked
                          ? 'BLOCKED — Inbox 전달이 비활성화됩니다.'
                          : 'WARNING — 확인 후 전달할 수 있습니다.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    for (final issue in result.issues) ...[
                      Text(
                        '[${issue.level.name.toUpperCase()}] ${issue.field}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(issue.reason),
                      Text(
                        issue.fix,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ControlColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInstructionViewer() async {
    if (_instruction == null) {
      _snack('작업지시서가 없습니다.');
      return;
    }
    final validation = _contractValidation;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('작업지시서 최종 검토 v${_instruction!.instructionVersion}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: InstructionPreviewPanel(
              instruction: _instruction!,
              validation: validation,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOtherActionsMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;

    final hasInstruction = _instruction != null;
    final items = <PopupMenuEntry<String>>[
      if (_isInstructionArchived && hasInstruction)
        const PopupMenuItem(value: 'permanent_delete', child: Text('영구 삭제'))
      else if (hasInstruction) ...[
        const PopupMenuItem(value: 'view', child: Text('작업지시서 보기')),
        const PopupMenuItem(value: 'edit', child: Text('작업지시서 수정')),
        const PopupMenuItem(value: 'new_version', child: Text('새 버전 생성')),
        const PopupMenuItem(value: 'archive', child: Text('보관')),
        const PopupMenuDivider(),
      ],
      if (!_isInstructionArchived) ...[
        const PopupMenuItem(value: 'validate', child: Text('지시서 검증 보기')),
        const PopupMenuItem(value: 'json', child: Text('JSON 내보내기')),
        const PopupMenuItem(value: 'readable', child: Text('텍스트 지시서 복사')),
        const PopupMenuItem(value: 'cursor', child: Text('Cursor 프롬프트 복사')),
        const PopupMenuItem(value: 'duplicate', child: Text('기획 복제')),
      ],
    ];

    if (items.isEmpty) return;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        overlay.size.width - position.dx - size.width,
        overlay.size.height - position.dy - size.height,
      ),
      items: items,
    );

    if (value == null) return;
    switch (value) {
      case 'view':
        await _showInstructionViewer();
      case 'edit':
        await _editInstruction();
      case 'new_version':
        await _createNewVersion();
      case 'archive':
        await _archiveInstruction();
      case 'permanent_delete':
        await _permanentDeleteInstruction();
      case 'validate':
        _showValidationIssues();
      case 'json':
        await _copyJson();
      case 'readable':
        await _copyReadableInstruction();
      case 'cursor':
        await _copyCursorPrompt();
      case 'duplicate':
        await _duplicatePlan();
    }
  }

  PlanProgressView _progressFor(BusinessPlanDocument? plan) {
    return PlanProgressStatus.resolve(
      plan,
      hasDevWorkDocRoot: _devWorkDocFolderReady,
      hasTransferFolder: _inboxTransferReady,
      lastDevWorkDocMode: _lastDevWorkDocResult?.mode,
    );
  }

  PlanProgressView get _activeProgressView => _progressFor(_activeDoc);

  Color _progressBadgeColor(PlanProgressView view) {
    switch (view.kind) {
      case PlanProgressKind.inboxTransferred:
      case PlanProgressKind.imported:
        return ControlColors.accentGreen;
      case PlanProgressKind.jsonDownloaded:
        return ControlColors.sandBeige;
      case PlanProgressKind.transferReady:
        return ControlColors.teal;
      case PlanProgressKind.failed:
        return ControlColors.accentWarm;
      case PlanProgressKind.archived:
        return ControlColors.textMuted;
      default:
        return ControlColors.sandBeige;
    }
  }

  String _planListBadge(BusinessPlanDocument plan) {
    return PlanUserFacingStatus.label(plan, execution: _execFor(plan));
  }

  String _userFacingProgressLabel() {
    final doc = _activeDoc;
    if (doc != null) {
      return PlanUserFacingStatus.label(doc, execution: _execFor(doc));
    }
    if (_instruction != null) return PlanUserFacingStatus.instructionReady;
    if (_planReady) return PlanUserFacingStatus.planning;
    return PlanUserFacingStatus.planning;
  }

  String _userFacingProgressHint() {
    if (_showWorkshopEmptyPrep) {
      return '아래에서 새 작업지시를 만들어 시작하세요.';
    }
    final doc = _activeDoc;
    if (doc != null) {
      final exec = _execFor(doc);
      if (exec.isAwaitingApproval) {
        return '승인 대기 중입니다. 결과를 확인하세요.';
      }
      if (exec.isActivelyRunning) {
        return 'AI 제작공정에서 ${exec.productionCurrentStage}/${exec.productionTotalStages}단계 진행 중입니다.';
      }
      if (exec.isDeliveredOnly) {
        return '전달은 완료되었으나 PC에서 아직 실행하지 않았습니다.';
      }
      if (!exec.isPostTransfer) {
        if (exec.primaryStatusLabel == PlanUserFacingStatus.transferFailed) {
          return '전송에 실패했습니다. 「다시 시도」로 연결된 노트북 Agent에 전달하세요.';
        }
        return '기획을 완성한 뒤 작업지시서를 생성·전달하세요.';
      }
    }
    final label = _userFacingProgressLabel();
    switch (label) {
      case PlanUserFacingStatus.planning:
        return '기획을 완성한 뒤 작업지시서를 생성하세요.';
      case PlanUserFacingStatus.instructionReady:
        return '작업지시서가 준비되었습니다. 소통24워크 Agent로 전달하세요.';
      case PlanUserFacingStatus.transferPending:
        return '전달 준비가 완료되었습니다. 소통24워크 Agent로 전달하세요.';
      case PlanUserFacingStatus.deliveredNotRun:
      case PlanUserFacingStatus.pcReceivedNotStarted:
        return '전달 후 실행 전입니다. 필요하면 취소·보관할 수 있습니다.';
      case PlanUserFacingStatus.working:
        return 'AI 제작공정에서 작업이 진행 중입니다.';
      case PlanUserFacingStatus.awaitingApproval:
        return '승인 대기 중입니다.';
      case PlanUserFacingStatus.completed:
        return '작업이 완료되었습니다.';
      case PlanUserFacingStatus.archived:
        return '보관된 기획입니다.';
      case PlanUserFacingStatus.cleanup:
        return '정리 대상입니다. 관리 필터에서 확인하세요.';
      default:
        return '기획 → 작업지시 → 전달 → 진행 확인';
    }
  }

  List<BusinessPlanDocument> get _latestPlans {
    // Duplicate-topic detection helper; list UI uses planId identity.
    return BusinessPlanningStore.dedupeById(_allPlans);
  }

  Future<void> _onLibraryBulkAction(
    PlanLibraryBulkAction action,
    List<BusinessPlanDocument> selected,
  ) async {
    if (selected.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();

    if (action == PlanLibraryBulkAction.permanentDelete) {
      // 기획 라이브러리 레코드만 삭제 — DevWorkDoc/Inbox/외부 파일은 호출하지 않음.
      await _store.deletePlans(selected.map((p) => p.id));
      await _refreshPlans();
      if (!mounted) return;
      if (_activePlanId != null && selected.any((p) => p.id == _activePlanId)) {
        setState(() {
          _activePlanId = null;
          _activeDoc = null;
        });
      } else {
        setState(() {});
      }
      _snack('기획 라이브러리에서 ${selected.length}건을 영구 삭제했습니다.');
      return;
    }

    final updates = <BusinessPlanDocument>[];
    for (final p in selected) {
      switch (action) {
        case PlanLibraryBulkAction.favorite:
          updates.add(p.copyWith(favorite: true, updatedAt: now));
        case PlanLibraryBulkAction.unfavorite:
          updates.add(p.copyWith(favorite: false, updatedAt: now));
        case PlanLibraryBulkAction.archive:
          if (PlanLibraryManagement.isBulkArchiveBlocked(
            p,
            activePlanId: _activePlanId,
            execution: _execFor(p),
          )) {
            continue;
          }
          updates.add(PlanLibraryManagement.archive(p, updatedAt: now));
        case PlanLibraryBulkAction.unarchive:
          updates.add(PlanLibraryManagement.unarchive(p, updatedAt: now));
        case PlanLibraryBulkAction.trash:
          if (!PlanLibraryManagement.canMoveToTrash(p)) continue;
          updates.add(
            PlanLibraryManagement.moveToTrash(
              p,
              updatedAt: now,
              trashedAt: now,
            ),
          );
        case PlanLibraryBulkAction.restore:
          updates.add(PlanLibraryManagement.restore(p, updatedAt: now));
        case PlanLibraryBulkAction.protect:
          updates.add(p.copyWith(isProtected: true, updatedAt: now));
        case PlanLibraryBulkAction.unprotect:
          updates.add(p.copyWith(isProtected: false, updatedAt: now));
        case PlanLibraryBulkAction.permanentDelete:
          break;
      }
    }

    if (updates.isEmpty) {
      _snack(
        action == PlanLibraryBulkAction.archive
            ? '보호·운영 기획은 일괄 보관할 수 없습니다.'
            : '적용할 항목이 없습니다.',
      );
      return;
    }
    await _store.upsertPlans(updates);
    await _refreshPlans();
    if (!mounted) return;
    setState(() {});
    final label = switch (action) {
      PlanLibraryBulkAction.favorite => '즐겨찾기',
      PlanLibraryBulkAction.unfavorite => '즐겨찾기 해제',
      PlanLibraryBulkAction.archive => '보관',
      PlanLibraryBulkAction.unarchive => '보관 해제',
      PlanLibraryBulkAction.trash => '휴지통 이동',
      PlanLibraryBulkAction.restore => '복원',
      PlanLibraryBulkAction.protect => '보호',
      PlanLibraryBulkAction.unprotect => '보호 해제',
      PlanLibraryBulkAction.permanentDelete => '영구 삭제',
    };
    _snack(
      '$label ${updates.length}건 완료'
      '${action == PlanLibraryBulkAction.archive ? ' (클라우드 동기화 요청됨)' : ''}',
    );
  }

  List<BusinessPlanDocument> _similarPlans(BusinessPlanDocument plan) {
    final topic = plan.input.topic.trim().toLowerCase();
    if (topic.isEmpty) return const [];
    return _latestPlans
        .where(
          (p) => p.id != plan.id && p.input.topic.trim().toLowerCase() == topic,
        )
        .toList();
  }

  Future<void> _onPlanTileTap(BusinessPlanDocument plan) async {
    final similar = _similarPlans(plan);
    if (similar.isEmpty) {
      _loadPlan(plan);
      return;
    }

    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan.input.topic.isEmpty ? '(주제 미입력)' : plan.input.topic),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '같은 주제의 기획안이 여러 개 있습니다. '
                '어떻게 진행할지 선택하세요.',
              ),
              const SizedBox(height: 12),
              Text(
                '유사 기획 ${similar.length + 1}건',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final p in [plan, ...similar])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· ${p.input.topic.isEmpty ? '(주제 미입력)' : p.input.topic} '
                    '(v${p.version} · ${_planListBadge(p)})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'link_theme'),
            child: const Text('테마 묶음으로 연결'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'merge_review'),
            child: const Text('병합 검토'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'open'),
            child: const Text('이 기획안 열기'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        _loadPlan(plan);
      case 'link_theme':
        _loadPlan(plan);
        _snack('테마 묶음 연결은 메모에 표시했습니다. 관련 기획을 함께 검토하세요.');
      case 'merge_review':
        _loadPlan(plan);
        _snack('병합 검토 모드: 유사 기획 ${similar.length}건과 내용을 비교하세요.');
    }
  }

  Set<String> get _duplicateTopics {
    final byTopic = <String, Set<String>>{};
    for (final p in _latestPlans) {
      final t = p.input.topic.trim().toLowerCase();
      if (t.isEmpty) continue;
      byTopic.putIfAbsent(t, () => {}).add(p.stableInstructionId);
    }
    return byTopic.entries
        .where((e) => e.value.length > 1)
        .map((e) => e.key)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(),
          if (_showWorkshopEmptyPrep) ...[
            const SizedBox(height: 10),
            _buildEmptyWorkshopPrepBanner(),
          ],
          const SizedBox(height: 12),
          _buildTransferredInstructionList(),
          const SizedBox(height: 12),
          if (_inputModeQuick)
            ProjectDesignWizard(
              initial: _designState,
              onChanged: _onDesignChanged,
              onRequestSavePlan: () => _savePlan(),
              onRequestCreateInstruction: () => _createOrPromptInstruction(),
            )
          else
            _buildAdvancedForm(),
          if (_instruction != null) ...[
            const SizedBox(height: 12),
            _buildSendSummaryCard(),
            const SizedBox(height: 12),
            _buildMainActions(),
          ],
          const SizedBox(height: 12),
          OperationalCollapsibleSection(
            title: '직접 입력으로 만들기',
            subtitle: '설계 엔진 대신 직접 입력',
            sectionKey: const Key('planning_advanced_input'),
            child: _buildModeToggle(),
          ),
          const SizedBox(height: 12),
          OperationalCollapsibleSection(
            title: 'AI 제작설정 보기',
            subtitle: '파일럿 정책·Codex·승인 방식',
            sectionKey: const Key('planning_ai_settings'),
            child: _buildAiProductionPilotCard(),
          ),
          const SizedBox(height: 12),
          OperationalCollapsibleSection(
            title: '고급/진단정보',
            subtitle: 'PC 작업공간·Inbox·DevWorkDoc 상태',
            sectionKey: const Key('planning_diagnostics'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWorkspaceStatusStrip(),
                if (_planReady || _activeDoc != null) ...[
                  const SizedBox(height: 12),
                  _buildProgressBanner(),
                  const SizedBox(height: 12),
                  _buildWorkflowStepStrip(),
                  const SizedBox(height: 12),
                  _buildReviewCard(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildStatusPrimaryActions(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          OperationalCollapsibleSection(
            title: '저장된 기획 목록',
            subtitle: '필요할 때만 펼치세요',
            sectionKey: const Key('planning_library'),
            child: PlanLibraryPanel(
              plans: _allPlans,
              activePlanId: _activePlanId,
              folderFilter: _libraryFolder,
              searchQuery: _searchCtrl.text,
              viewMode: _libraryView,
              sort: _librarySort,
              duplicateTopics: _duplicateTopics,
              onFolderChanged: (f) => setState(() => _libraryFolder = f),
              onSearchChanged: (q) {
                _searchCtrl.text = q;
                setState(() {});
              },
              onViewModeChanged: (m) => setState(() => _libraryView = m),
              onSortChanged: (s) => setState(() => _librarySort = s),
              onOpenPlan: _onPlanTileTap,
              onToggleFavorite: (p) async {
                final next = p.copyWith(favorite: !p.favorite);
                await _store.upsertPlan(next);
                await _refreshPlans();
                if (mounted) setState(() {});
              },
              onStartNew: _startNewPlan,
              onBulkAction: _onLibraryBulkAction,
              executionIndex: _executionIndex,
            ),
          ),
        ],
      ),
    );
  }

  List<BusinessPlanDocument> get _transferredPlans {
    final latest = BusinessPlanningStore.latestByInstructionId(_allPlans);
    final sent = latest.where((p) {
      if (p.wasTransferred) return true;
      return (p.lastTransferAt ?? '').trim().isNotEmpty;
    }).toList();
    sent.sort((a, b) {
      final ta =
          DateTime.tryParse(a.lastTransferAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          DateTime.tryParse(b.lastTransferAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return sent;
  }

  String _formatTransferTime(String? iso) {
    final t = DateTime.tryParse(iso ?? '');
    if (t == null) return '—';
    final local = t.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '오늘 $hh:$mm';
    }
    return '${local.month}/${local.day} $hh:$mm';
  }

  String _transferStatusLabel(BusinessPlanDocument plan) {
    final exec = _execFor(plan);
    if (exec.primaryStatusLabel == '전송 실패') return '전송 실패';
    if (plan.wasTransferred) return '전송 완료';
    return '전송됨';
  }

  Widget _buildTransferredInstructionList() {
    final sent = _transferredPlans;
    if (sent.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('planning_transferred_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '전송 작업지시 목록',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          '전송 이후 진행은 AI 제작공정에서 관리합니다.',
          style: TextStyle(fontSize: 12.5, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final plan in sent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: ControlColors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  _loadPlan(plan);
                  await _showInstructionViewer();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ControlColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ArtifactType.labelKo(plan.input.resolvedArtifactType),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ControlColors.teal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.input.topic.trim().isEmpty
                            ? '(제목 없음)'
                            : plan.input.topic.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTransferTime(plan.lastTransferAt),
                        style: const TextStyle(
                          fontSize: 13,
                          color: ControlColors.textSecondary,
                        ),
                      ),
                      Text(
                        _transferStatusLabel(plan),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            _loadPlan(plan);
                            await _showInstructionViewer();
                          },
                          child: const Text('상세보기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSendSummaryCard() {
    final input = _currentInput;
    final isEbookPilot =
        _aiProductionPilot &&
        ArtifactType.normalize(input.resolvedArtifactType) ==
            ArtifactType.ebook;

    return Card(
      key: const Key('planning_send_summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '최종 확인',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _sendSummaryRow(
              '제작물',
              ArtifactType.labelKo(input.resolvedArtifactType),
            ),
            _sendSummaryRow(
              '제목',
              input.topic.trim().isEmpty ? '(미입력)' : input.topic.trim(),
            ),
            _sendSummaryRow(
              '대상',
              input.targetCustomer.trim().isEmpty
                  ? '(미입력)'
                  : input.targetCustomer.trim(),
            ),
            _sendSummaryRow('제작방식', isEbookPilot ? 'AI 제작' : '수동/혼합'),
            if (isEbookPilot) ...[
              _sendSummaryRow('AI 작업자', 'Codex'),
              _sendSummaryRow('자동진행', '1단계까지 자동 · 이후 승인 필요'),
              _sendSummaryRow('승인', '필요'),
              _sendSummaryRow('자동배포', '안 함'),
            ],
            if (_instruction != null) ...[
              const SizedBox(height: 8),
              Text(
                '작업지시 v${_instruction!.instructionVersion} 준비됨',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ControlColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sendSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ControlColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkshopPrepBanner() {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(10),
      color: ControlColors.surfaceMuted,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ControlColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 20,
              color: ControlColors.teal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '새 작업 준비',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ControlColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '현재 진행 중인 작업이 없습니다.\n'
                    '아래에서 새 작업지시를 만들어 시작하세요.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: ControlColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(label: '새 작업 준비', color: ControlColors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBanner() {
    final view = _activeProgressView;
    final label = _userFacingProgressLabel();
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(10),
      color: ControlColors.surfaceMuted,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ControlColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.route_outlined, size: 20, color: ControlColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ControlColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userFacingProgressHint(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ControlColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(label: label, color: _progressBadgeColor(view)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStepStrip() {
    final view = _activeProgressView;
    final steps = [
      _WorkflowStepDef('기획', _planReady),
      _WorkflowStepDef('작업지시', _instruction != null),
      _WorkflowStepDef(
        '전달',
        view.isTrulyTransferred ||
            PlanningStatus.normalize(_activeDoc?.status ?? '') ==
                PlanningStatus.imported,
      ),
      _WorkflowStepDef(
        '진행',
        PlanningStatus.normalize(_activeDoc?.status ?? '') ==
                PlanningStatus.inProgress ||
            PlanningStatus.normalize(_activeDoc?.status ?? '') ==
                PlanningStatus.completed ||
            view.kind == PlanProgressKind.imported,
      ),
    ];

    var currentIndex = steps.indexWhere((s) => !s.done);
    if (currentIndex < 0) currentIndex = steps.length - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('진행 단계', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              _buildWorkflowStepRow(
                steps[i],
                isCurrent: i == currentIndex,
                isLast: i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStepRow(
    _WorkflowStepDef step, {
    required bool isCurrent,
    required bool isLast,
  }) {
    final color = step.done
        ? ControlColors.accentGreen
        : isCurrent
        ? ControlColors.teal
        : ControlColors.textMuted;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            step.done
                ? Icons.check_circle
                : isCurrent
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.label,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: step.done || isCurrent
                    ? ControlColors.textPrimary
                    : ControlColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ControlColors.border),
      ),
      child: const Text(
        '새 작업을 순서대로 만들고 Sotong24Work로 보냅니다. 전송 후 진행은 AI 제작공정에서 관리합니다.',
        style: TextStyle(fontSize: 12.5, color: ControlColors.textSecondary),
      ),
    );
  }

  Widget _buildAiProductionPilotCard() {
    final isEbook =
        _artifactType == ArtifactType.undecided ||
        ArtifactType.normalize(_artifactType) == ArtifactType.ebook;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'AI 제작 (파일럿)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ControlColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'pilot',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ControlColors.teal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 제작 사용'),
              subtitle: Text(
                isEbook
                    ? '새 전자책 작업지시서에만 적용됩니다. 기존 지시서에는 자동으로 넣지 않습니다.'
                    : '현재는 전자책 파일럿만 지원합니다.',
                style: const TextStyle(fontSize: 12.5),
              ),
              value: _aiProductionPilot && isEbook,
              onChanged: !isEbook
                  ? null
                  : (v) => setState(() => _aiProductionPilot = v),
            ),
            if (_aiProductionPilot && isEbook) ...[
              const Divider(height: 20),
              const _PilotKv('AI 작업자', 'Codex'),
              const _PilotKv('자동 진행', '1단계까지만'),
              const _PilotKv('1단계 결과 후', '사용자 승인 필요'),
              const _PilotKv('결과물 휴대폰 보기', '사용'),
              const _PilotKv('자동 배포', '사용 안 함'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('설계 엔진')),
            ButtonSegment(value: false, label: Text('직접 입력')),
          ],
          selected: {_inputModeQuick},
          onSelectionChanged: (s) {
            setState(() {
              _inputModeQuick = s.first;
              _wizardState = _wizardState.copyWith(
                mode: _inputModeQuick ? 'quick' : 'advanced',
              );
            });
            _persistDraft();
          },
        ),
      ),
    );
  }

  Widget _buildAdvancedForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('직접 입력하여 만들기', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _field(_topicCtrl, '사업 주제 *'),
            _field(_problemCtrl, '고객 문제 *', maxLines: 3),
            _field(_targetCtrl, '대상 고객 *', maxLines: 2),
            _field(_outcomeCtrl, '원하는 결과 *', maxLines: 2),
            const SizedBox(height: 8),
            Text('제작 형태 *', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in _artifactOptions)
                  FilterChip(
                    label: Text(ArtifactType.labelKo(type)),
                    selected: _artifactType == type,
                    onSelected: (_) => _selectArtifact(type),
                  ),
              ],
            ),
            if (_artifactType == ArtifactType.contents) ...[
              const SizedBox(height: 8),
              Text(
                '콘텐츠 하위 유형 *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sub in _contentSubtypeOptions)
                    FilterChip(
                      label: Text(ContentSubtype.labelKo(sub)),
                      selected: _contentSubtype == sub,
                      onSelected: (_) => _selectContentSubtype(sub),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('선택 입력 (경험·자료·규모 등)'),
              children: [
                _field(_skillsCtrl, '보유 경험·기술'),
                _field(_materialsCtrl, '기존 자료'),
                _field(_scaleCtrl, '예상 규모'),
                _field(_budgetCtrl, '예산'),
                _field(_salesPriceCtrl, '희망 판매가'),
                _field(_referencesCtrl, '참고 자료'),
                _field(_constraintsCtrl, '제약 조건'),
                _field(_extraRequestsCtrl, '추가 요청'),
                _field(_notesCtrl, '메모', maxLines: 3),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildReviewCard() {
    final input = _currentInput;
    final progress = _activeProgressView;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '기획 검토',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_instruction != null)
                  StatusBadge(
                    label: 'v${_instruction!.instructionVersion}',
                    color: ControlColors.teal,
                  ),
                const SizedBox(width: 6),
                StatusBadge(
                  label: _userFacingProgressLabel(),
                  color: _progressBadgeColor(progress),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              input.topic.trim().isEmpty ? '(주제 미입력)' : input.topic,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _reviewLabeledLine(
              '제작 형태',
              ArtifactType.labelKo(input.resolvedArtifactType),
            ),
            _reviewLabeledLine(
              '주 트랙',
              ArtifactType.primaryTrack(input.resolvedArtifactType),
            ),
            const SizedBox(height: 6),
            _reviewLabeledLine('고객 문제', input.customerProblem, maxLines: 3),
            if (_instruction != null) ...[
              const SizedBox(height: 8),
              Text(
                _instruction!.valueProposition,
                softWrap: true,
                style: const TextStyle(color: ControlColors.textSecondary),
              ),
              const SizedBox(height: 12),
              InstructionPreviewPanel(
                instruction: _instruction!,
                validation: _contractValidation,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewLabeledLine(String label, String value, {int maxLines = 2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: ControlColors.textSecondary,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: ControlColors.textMuted,
              ),
            ),
            TextSpan(text: value.trim().isEmpty ? '—' : value),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [if (!_isInstructionArchived) ..._buildTransferActions()],
        ),
        ..._buildActionHints(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _showOtherActionsMenu(context),
            child: const Text('기타 작업'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTransferActions() {
    if (_instruction == null ||
        !_isInstructionReady ||
        _isInstructionArchived) {
      return const [];
    }

    // Inbox 직접 전달만 — 수동 다운로드와 완전히 분리 (다운로드는 DevWorkDoc 액션에만)
    final failed =
        _activeDoc != null &&
        _execFor(_activeDoc!).primaryStatusLabel == '전송 실패';
    return [
      FilledButton.icon(
        onPressed: (_canTransfer && !_transferBusy) ? _transferToWork : null,
        icon: _transferBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_outlined, size: 18),
        label: Text(
          _transferBusy
              ? '전달 중…'
              : (_contractValidation?.isBlocked == true
                    ? '전달 차단(BLOCKED)'
                    : (failed ? '다시 시도' : '소통24워크 Agent로 전달')),
        ),
      ),
    ];
  }

  List<Widget> _buildActionHints() {
    final hints = <Widget>[];

    if (_instruction == null && _planReady) {
      hints.add(
        _actionHint(
          _canCreateInstruction
              ? (_devWorkDocFolderReady
                    ? '작업지시서 v1을 생성할 준비가 되었습니다.'
                    : 'DevWorkDoc 폴더를 설정하거나 JSON 다운로드로 시작하세요.')
              : '주제·고객 문제·대상·결과·제작 형태를 완성하세요.',
          _canCreateInstruction
              ? '「작업지시서 v1 생성」 또는 「수동 가져오기용 JSON 다운로드」'
              : '마법사를 완료한 뒤 다시 시도하세요.',
        ),
      );
    }

    if (_instruction != null &&
        _isInstructionReady &&
        !_isInstructionArchived) {
      final online = WorkInstructionRemoteDelivery.pickTargetAgent(
        _remoteAgents,
      );
      if (online == null) {
        hints.add(
          _actionHint(
            '연결된 노트북 Agent가 없습니다.',
            '노트북에서 소통24워크 Agent가 켜져 있는지 확인한 뒤 다시 시도하세요.',
          ),
        );
      } else if (!_canTransfer) {
        hints.add(
          _actionHint('전달 전 검증을 통과해야 합니다.', '「기타 작업 → 지시서 검증 보기」에서 이슈를 확인하세요.'),
        );
      }
    }

    if (hints.isEmpty) return const [];
    return [const SizedBox(height: 8), ...hints];
  }

  Widget _actionHint(String reason, String nextAction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reason,
            style: const TextStyle(
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
          Text(
            nextAction,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ControlColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusPrimaryActions() {
    if (_isInstructionArchived) {
      return [
        FilledButton.icon(
          onPressed: _restoreInstruction,
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          label: const Text('복원'),
        ),
      ];
    }
    if (_instruction == null) {
      return [
        FilledButton.icon(
          onPressed: _canCreateInstruction ? _createOrPromptInstruction : null,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('작업지시서 v1 생성'),
        ),
      ];
    }
    if (_needsVersionRecovery) {
      return [
        FilledButton.icon(
          onPressed: _openVersionDiagnoseAndRecover,
          icon: const Icon(Icons.healing_outlined, size: 18),
          label: const Text('기존 버전 확인 및 복구'),
        ),
      ];
    }
    if (_isInstructionReady && _folderVersionConfirmed) {
      return [
        OutlinedButton.icon(
          onPressed: _canCreateInstruction ? _createNewVersion : null,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: Text('작업지시서 v${_version + 1} 생성'),
        ),
      ];
    }
    if (_isInstructionReady) {
      return [
        FilledButton.icon(
          onPressed: (_canCreateInstruction && _devWorkDocFolderReady)
              ? _editInstruction
              : null,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('DevWorkDoc에 다시 저장'),
        ),
      ];
    }
    return const [];
  }

  Future<void> _createOrPromptInstruction() async {
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
    if (_devWorkDocFolderReady) {
      await _createInstruction();
      return;
    }
    // 폴더 미설정: 지시서는 생성하되 DevWorkDoc 직접 저장과 구분 (다운로드)
    await _downloadInstructionJson();
  }

  List<Widget> _buildDevWorkDocSaveActions() {
    if (!_planReady || _isInstructionArchived) return const [];

    return [
      FilledButton.icon(
        onPressed: (_canCreateInstruction && _devWorkDocFolderReady)
            ? () => _instruction == null
                  ? _createInstruction()
                  : _editInstruction()
            : null,
        icon: const Icon(Icons.save, size: 18),
        label: Text(
          _instruction == null ? 'DevWorkDoc에 저장' : 'DevWorkDoc에 다시 저장',
        ),
      ),
      if (_instruction != null && _devWorkDocFolderReady)
        OutlinedButton.icon(
          onPressed: _openVersionDiagnoseAndRecover,
          icon: const Icon(Icons.troubleshoot_outlined, size: 18),
          label: Text(_needsVersionRecovery ? '기존 버전 확인 및 복구' : 'Versions 진단'),
        ),
      OutlinedButton.icon(
        onPressed: (_canCreateInstruction && !_transferBusy)
            ? _downloadInstructionJson
            : null,
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('수동 가져오기용 JSON 다운로드'),
      ),
    ];
  }

  Widget _buildWorkspaceStatusStrip() {
    final width = MediaQuery.sizeOf(context).width;
    final fsaSupported = _devDocState?.supported == true;
    final showPcFolderControls = showPcLocalFolderSettings(
      fsaSupported: fsaSupported,
      widthPx: width,
    );

    final onlineAgents = _remoteAgents.where((a) => a.isOnline()).toList();
    final agentOnline = onlineAgents.isNotEmpty;
    final copy = resolvePcWorkspaceStatusCopy(
      fsaSupported: fsaSupported,
      agentOnline: agentOnline,
      hasAnyAgent: _remoteAgents.isNotEmpty,
      devFolderReady: fsaSupported && (_devDocState?.readyToWrite == true),
      inboxReady: _inboxTransferReady,
      onlineAgentCount: onlineAgents.length,
    );

    DateTime? lastHb;
    for (final a in onlineAgents) {
      final t = a.lastHeartbeatAt;
      if (t == null) continue;
      if (lastHb == null || t.isAfter(lastHb)) lastHb = t;
    }
    final syncLine = lastHb == null
        ? '마지막 동기화 : —'
        : '마지막 동기화 : ${formatRelativeKo(lastHb)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.headline,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(copy.agentLine, style: const TextStyle(fontSize: 13)),
            if (copy.devWorkDocLine != null)
              Text(
                copy.devWorkDocLine!,
                style: TextStyle(
                  fontSize: 13,
                  color: copy.devWorkDocLine!.contains('재연결') && agentOnline
                      ? ControlColors.textMuted
                      : (copy.devWorkDocLine!.contains('재연결')
                            ? ControlColors.accentWarm
                            : ControlColors.textPrimary),
                  fontWeight:
                      copy.devWorkDocLine!.contains('재연결') && !agentOnline
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            if (copy.showInboxUnconnectedWarning)
              const Text(
                'Inbox 로컬 폴더 : 미연결',
                style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
              ),
            Text(
              syncLine,
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
            if (showPcFolderControls) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(
                  () => _pcWorkspaceExpanded = !_pcWorkspaceExpanded,
                ),
                icon: Icon(
                  _pcWorkspaceExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _pcWorkspaceExpanded ? 'PC 작업환경 설정 닫기' : '관리 · PC 작업환경 설정',
                ),
              ),
              if (_pcWorkspaceExpanded) ...[
                const SizedBox(height: 8),
                _buildDevWorkDocFolderSettings(),
                const SizedBox(height: 8),
                _buildFolderSettings(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDevWorkDocFolderSettings() {
    final devDoc = _devDocState;
    final ready = devDoc?.readyToWrite == true;
    final reconnect =
        !ready &&
        ((devDoc?.rootFolderName ?? '').trim().isNotEmpty ||
            devDoc?.hasRoot == true);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DevWorkDoc 작업지시서 저장',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'PC 저장폴더 연결됨'
                  : (reconnect ? 'PC 저장폴더 재연결 필요' : 'PC 저장폴더 미연결'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              ready
                  ? '작업지시서를 DevWorkDoc Active에 저장할 수 있습니다.'
                  : '실제 폴더 권한(핸들)이 있을 때만 연결된 것으로 표시합니다.',
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: devDoc?.supported == false
                      ? null
                      : _pickDevWorkDocFolder,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(ready ? '폴더 다시 선택' : 'DevWorkDoc 폴더 연결'),
                ),
                if (devDoc?.selectionKind ==
                    DevWorkDocSelectionKind.repoRootWithDevWorkDoc)
                  OutlinedButton.icon(
                    onPressed: _useNestedDevWorkDocFolder,
                    icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                    label: const Text('DevWorkDoc 하위 폴더 사용'),
                  ),
                ..._buildDevWorkDocSaveActions(),
                OutlinedButton.icon(
                  onPressed: _devWorkDocFolderReady
                      ? _migratePlansToDevWorkDoc
                      : null,
                  icon: const Icon(Icons.sync_alt, size: 18),
                  label: const Text('기존 작업지시서를 DevWorkDoc으로 정리'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSettings() {
    final folder = _folderState;
    final ready = folder?.readyToWrite == true;
    final nameOnly =
        !ready &&
        (folder?.folderName ?? '').trim().isNotEmpty &&
        folder?.hasHandle != true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '소통24워크 Agent Inbox (PC fallback)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              ready
                  ? 'PC Inbox 폴더 연결됨'
                  : (nameOnly ? 'PC Inbox 재연결 필요' : 'PC Inbox 미연결'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              '주 전달 경로는 원격(Firestore Relay)입니다. '
              '로컬 Inbox는 PC에서만 필요한 fallback입니다.',
              style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickTransferFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(ready ? 'Inbox 폴더 다시 선택' : 'Inbox 폴더 연결'),
            ),
            if (_lastTransferDiagnosis != null) ...[
              const SizedBox(height: 10),
              Text(
                _lastTransferDiagnosis!,
                style: const TextStyle(
                  fontSize: 11,
                  color: ControlColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkflowStepDef {
  const _WorkflowStepDef(this.label, this.done);

  final String label;
  final bool done;
}

class _PilotKv extends StatelessWidget {
  const _PilotKv(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
