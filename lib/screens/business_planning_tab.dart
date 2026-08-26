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
import '../services/instruction_contract_validator.dart';
import '../models/sotong24_remote_models.dart';
import '../services/plan_execution_index.dart';
import '../services/plan_execution_status.dart';
import '../services/plan_progress_status.dart';
import '../services/project_design_engine.dart';
import '../services/remote_agent_repository.dart';
import '../services/remote_work_instruction_mirror.dart';
import '../services/sotong24_remote_repository.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../services/work_instruction_concept_occupancy.dart';
import '../services/work_instruction_delivery_presentation.dart';
import '../services/work_instruction_remote_delivery.dart';
import '../services/work_instruction_validator.dart';
import '../services/work_instruction_wizard_session.dart';
import '../services/work_instruction_workshop_presentation.dart';
import '../services/transferred_work_reconciliation.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/project_design/instruction_preview_panel.dart';
import '../widgets/operational_collapsible_section.dart';
import '../widgets/project_design/step7_delivery_panel.dart';
import '../widgets/project_design/project_design_wizard.dart';

/// 작업지시 제작소 본문 (로컬 규칙 기반).
/// Production AI는 새 ebook WI에만 opt-in `aiExecution`으로 연결한다.
class BusinessPlanningTab extends StatefulWidget {
  const BusinessPlanningTab({
    super.key,
    this.ideaSeed,
    this.onOpenProductWorkshop,
    this.onOpenRemoteDiagnostics,
  });

  /// 뉴 아이디어 뱅크에서 전달. 새 기획으로만 적용(기존 active 덮어쓰지 않음).
  final IdeaToPlanningSeed? ideaSeed;
  final void Function({String? instructionId})? onOpenProductWorkshop;
  final VoidCallback? onOpenRemoteDiagnostics;

  @override
  State<BusinessPlanningTab> createState() => _BusinessPlanningTabState();
}

class _BusinessPlanningTabState extends State<BusinessPlanningTab> {
  final _service = BusinessPlanningService();
  final _store = BusinessPlanningStore();
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
  bool _agentRefreshBusy = false;
  RemoteDeliveryResult? _lastTransferResult;
  bool _inputModeQuick = true;

  /// 새 ebook WI에만 Codex 1단계 pilot 정책 부착. 기존 WI에는 자동 삽입하지 않음.
  bool _aiProductionPilot = true;
  String _approvalMode = 'manual';
  DevWorkDocState? _devDocState;
  List<RemoteAgentDoc> _remoteAgents = const [];
  List<RemoteJobDoc> _remoteJobs = const [];
  List<Sotong24RemoteProject> _remoteProjects = const [];
  bool _remoteEvidenceLoaded = false;
  bool _remoteRefreshBusy = false;
  StreamSubscription<List<Sotong24RemoteProject>>? _remoteProjectsSub;
  StreamSubscription<List<RemoteJobDoc>>? _remoteJobsSub;
  StreamSubscription<List<RemoteAgentDoc>>? _remoteAgentsSub;
  bool _orphanRepairStarted = false;
  DevWorkDocWriteResult? _lastDevWorkDocResult;
  Timer? _draftTimer;
  Timer? _wizardTimer;
  bool _showResumeBanner = false;
  BusinessPlanInput? _resumeInput;
  String? _resumePlanId;

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
      setState(() {
        _remoteProjects = projects;
        _remoteEvidenceLoaded = true;
      });
      unawaited(_reconcileLocalTransfers());
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      _remoteJobsSub = _agentRepo.watchJobs(ownerUid: uid).listen((jobs) {
        if (!mounted) return;
        setState(() {
          _remoteJobs = jobs;
          _remoteEvidenceLoaded = true;
        });
        unawaited(_reconcileLocalTransfers());
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

  RemoteOperationalEvidence get _remoteEvidence =>
      RemoteOperationalEvidence.fromRemote(
        jobs: _remoteJobs,
        projects: _remoteProjects,
        remoteLoaded: _remoteEvidenceLoaded,
      );

  ConceptOccupancyIndex get _conceptOccupancy => ConceptOccupancyIndex.build(
    plans: _allPlans,
    projects: _remoteProjects,
    jobs: _remoteJobs,
    execution: _executionIndex,
  );

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
  }

  Future<void> _loadInitial() async {
    try {
      // Active context MUST be restored before cleanup (see bootstrapSession).
      final boot = await BusinessPlanningStore.bootstrapSession(_store);
      final draft = await _store.loadDraftInput();
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
      final plans = BusinessPlanningStore.dedupeById(boot.plans);
      final currentResumable = WorkInstructionWizardSession.isUnsentResumable(
        draft,
        plans,
      );
      final parked = await _store.loadParkedDraftInput();
      if (!mounted) return;
      final parkedResumable = WorkInstructionWizardSession.isUnsentResumable(
        parked,
        plans,
      );
      BusinessPlanInput? resumeInput;
      String? resumePlanId;
      if (currentResumable) {
        resumeInput = draft;
      } else if (parkedResumable) {
        resumeInput = parked;
      }
      if (boot.activePlanId != null) {
        final match = plans.where((p) => p.id == boot.activePlanId);
        if (match.isNotEmpty && !match.first.wasTransferred) {
          resumePlanId = boot.activePlanId;
          resumeInput ??= match.first.input;
        }
      }
      setState(() {
        _allPlans = plans;
        _devDocState = devDoc;
        _remoteAgents = agents;
        _loading = false;
        _resetWizardToNewSession();
        _resumeInput = resumeInput;
        _resumePlanId = resumePlanId;
        _showResumeBanner =
            resumeInput != null &&
            WorkInstructionWizardSession.isUnsentResumable(resumeInput, plans);
      });
      _consumeIdeaSeedIfNeeded();
      unawaited(_maybeRepairOrphan());
      unawaited(_refreshRemoteOperationalState(fromServer: true));
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

  ContractValidationResult? get _contractValidation {
    if (_instruction == null) return null;
    return _contractValidator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
  }

  RemoteDeliveryResult? get _effectiveLastTransferResult {
    if (_activeDoc?.wasTransferred == true) return null;
    if (_lastTransferResult != null) return _lastTransferResult;
    final doc = _activeDoc;
    if (doc == null) return null;
    if (PlanningStatus.normalize(doc.status) != PlanningStatus.transferFailed) {
      return null;
    }
    return RemoteDeliveryResult.failed(
      userMessage: doc.lastDeliveryErrorLabel ?? '',
      errorCode: doc.lastDeliveryErrorCode,
      jobId: doc.lastRemoteJobId ?? '',
      commandId: doc.lastRemoteCommandId ?? '',
    );
  }

  DeliveryStep7View get _step7DeliveryView {
    return WorkInstructionDeliveryPresentation.resolve(
      plan: _activeDoc,
      validation: _contractValidation,
      agents: _remoteAgents,
      transferBusy: _transferBusy || _agentRefreshBusy || _remoteRefreshBusy,
      lastResult: _effectiveLastTransferResult,
      operationalProjectReady: _operationalProjectReady,
      remoteEvidence: _remoteEvidence,
    );
  }

  bool get _operationalProjectReady {
    final id = (_instruction?.instructionId ?? _instructionId ?? '').trim();
    return Sotong24WorkshopPresentation.projectForInstruction(
          _remoteProjects,
          id,
        ) !=
        null;
  }

  bool get _instructionMatchesCurrentInput {
    if (_instruction == null) return false;
    final saved = _activeDoc?.input;
    if (saved != null) {
      return _planningInputMatchesInstruction(saved, _instruction!) &&
          _planningInputMatchesInstruction(_currentInput, _instruction!);
    }
    return _planningInputMatchesInstruction(_currentInput, _instruction!);
  }

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

  Future<void> _refreshRemoteOperationalState({bool fromServer = false}) async {
    if (_remoteRefreshBusy) return;
    _remoteRefreshBusy = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (fromServer) {
        final results = await Future.wait([
          _agentRepo.fetchJobsFromServer(ownerUid: uid),
          _remoteRepo.fetchProjectsFromServer(),
        ]);
        if (!mounted) return;
        setState(() {
          _remoteJobs = results[0] as List<RemoteJobDoc>;
          _remoteProjects = results[1] as List<Sotong24RemoteProject>;
          _remoteEvidenceLoaded = true;
        });
      } else if (mounted) {
        setState(() => _remoteEvidenceLoaded = true);
      }
      await _reconcileLocalTransfers();
    } catch (_) {
      if (mounted) setState(() => _remoteEvidenceLoaded = true);
      await _reconcileLocalTransfers();
    } finally {
      _remoteRefreshBusy = false;
    }
  }

  Future<void> _reconcileLocalTransfers() async {
    if (!_remoteEvidenceLoaded) return;
    final evidence = _remoteEvidence;
    final result = TransferredWorkReconciliation.reconcilePlans(
      _allPlans,
      evidence,
    );
    if (!result.changed) return;
    await _store.savePlans(result.plans);
    if (!mounted) return;
    setState(() => _allPlans = BusinessPlanningStore.dedupeById(result.plans));
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
    final expectedApproval = _resolveAiExecutionForBuild(input)?.approvalMode;
    return input.topic.trim() == wi.businessIdea.trim() &&
        input.customerProblem.trim() == wi.customerProblem.trim() &&
        input.targetCustomer.trim() == wi.targetCustomer.trim() &&
        input.desiredOutcome.trim() == wi.businessPurpose.trim() &&
        ArtifactType.normalize(artifact) == wiArtifact &&
        input.notes.trim() == wi.notes.trim() &&
        (expectedApproval == null ||
            wi.aiExecution?.approvalMode == expectedApproval);
  }

  /// 새 ebook/app + pilot 토글 ON일 때만 고정 정책. 기존 WI 자동 migration 없음.
  AiExecutionPolicy? _resolveAiExecutionForBuild(BusinessPlanInput input) {
    if (!_aiProductionPilot) return null;
    final artifact = input.resolvedArtifactType == ArtifactType.undecided
        ? ArtifactType.ebook
        : ArtifactType.normalize(input.resolvedArtifactType);
    if (artifact == ArtifactType.ebook) {
      return AiExecutionPolicy.productionEbook(approvalMode: _approvalMode);
    }
    if (artifact == ArtifactType.app) {
      return AiExecutionPolicy.productionApp(approvalMode: _approvalMode);
    }
    return null;
  }

  Future<void> _createOrPromptInstruction() async {
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
    if (_instruction != null) {
      _snack(InstructionCreateUx.alreadyCreatedMessage);
      return;
    }
    await _saveInstructionInternal(
      version: 1,
      isNewVersion: false,
      appendPreviousToHistory: false,
      saveTarget: _devWorkDocFolderReady
          ? DevWorkDocSaveTarget.folder
          : DevWorkDocSaveTarget.localOnly,
    );
  }

  Future<void> _recreateInstructionFromChanges() async {
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
    if (_instruction == null) {
      await _createOrPromptInstruction();
      return;
    }
    if (_instructionMatchesCurrentInput) {
      _snack(InstructionCreateUx.alreadyCreatedMessage);
      return;
    }
    await _saveInstructionInternal(
      version: _version + 1,
      isNewVersion: true,
      appendPreviousToHistory: true,
      saveTarget: _devWorkDocFolderReady
          ? DevWorkDocSaveTarget.folder
          : DevWorkDocSaveTarget.localOnly,
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
    } else if (saveTarget == DevWorkDocSaveTarget.localOnly) {
      saveResult = DevWorkDocWriteResult(
        ok: true,
        mode: 'local',
        outcome: DevWorkDocSaveOutcome.completeSuccess,
        instructionId: iid,
        version: version,
        checksum: instruction.checksum,
        message: InstructionCreateUx.createdMessage,
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
    final isLocalSuccess =
        saveTarget == DevWorkDocSaveTarget.localOnly && saveResult.ok;
    final isFolderSuccess =
        !isDownloadTarget &&
        !isLocalSuccess &&
        (saveResult.isFolderCompleteSuccess ||
            (saveResult.outcome == DevWorkDocSaveOutcome.alreadyExists &&
                saveResult.activeVerified &&
                saveResult.versionsVerified) ||
            saveResult.outcome == DevWorkDocSaveOutcome.recoveredFromPartial);
    final isDownloadComplete =
        isDownloadTarget &&
        saveResult.mode == 'download' &&
        saveResult.outcome == DevWorkDocSaveOutcome.downloadOnly;

    if (!isFolderSuccess && !isDownloadComplete && !isLocalSuccess) {
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
      _snack(InstructionCreateUx.jsonDownloadedMessage);
    } else if (isFolderSuccess ||
        isLocalSuccess ||
        saveResult.outcome == DevWorkDocSaveOutcome.alreadyExists) {
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
        validation.canTransfer
            ? InstructionCreateUx.createdMessage
            : '작업지시를 보내기 전에 확인이 필요합니다. 아래 안내를 확인하세요.',
      );
    } else if (validation.canTransfer) {
      _snack(InstructionCreateUx.createdMessage);
    } else {
      _snack('작업지시를 보내기 전에 확인이 필요합니다. 아래 안내를 확인하세요.');
    }
  }

  Future<void> _transferToWork() async {
    if (_transferBusy || _agentRefreshBusy) return;
    if (_activeDoc?.wasTransferred == true) return;
    if (_instruction == null) {
      _snack('먼저 작업지시서를 생성하세요.');
      return;
    }

    final step7 = _step7DeliveryView;
    if (step7.buttonState == DeliveryButtonState.failed &&
        !step7.failure!.allowRetry) {
      await _reconcileTransferStatus();
      return;
    }
    if (step7.buttonState == DeliveryButtonState.blocked) {
      _showValidationIssues();
      return;
    }
    if (!step7.buttonEnabled) return;
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
      _showValidationIssues();
      _snack('작업지시를 보내기 전에 확인이 필요합니다.');
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
      if (plan.wasTransferred) {
        if (!silent) {
          _snack('이미 전달된 작업지시입니다.');
        }
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final reconciled = await _delivery.reconcileExisting(
        instructionId: instructionId,
        ownerUid: uid,
      );
      if (reconciled != null && reconciled.delivered) {
        final instruction = plan.instruction!;
        final existing = _allPlans.firstWhere(
          (p) => p.id == plan!.id,
          orElse: () => plan!,
        );
        final doc = WorkInstructionRemoteDelivery.markDelivered(
          plan: existing,
          result: reconciled,
          instruction: instruction,
        );
        await _store.upsertPlan(doc);
        await _refreshPlans();
        if (!mounted) return;
        if (_activePlanId == plan.id) {
          setState(() {
            _activeDoc = doc;
            _instruction = instruction;
            _lastTransferResult = null;
          });
        }
        if (!silent) _snack('소통24워크 Agent로 전달했습니다.');
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
          _lastTransferResult = result.delivered ? null : result;
        });
      } else if (!result.delivered && !silent) {
        setState(() => _lastTransferResult = result);
      }
      if (result.delivered) {
        if (!silent) {
          _snack('소통24워크 Agent로 전달했습니다.');
        } else if (result.outcome == 'created' ||
            result.outcome == 'command_repaired') {
          _snack('기존 작업을 Agent로 복구 전송했습니다.');
        }
      } else if (!silent) {
        final ambiguous =
            result.errorCode == 'timeout' || result.errorCode == 'network';
        if (ambiguous) {
          await _reconcileTransferStatus(silent: true);
        }
      } else {
        _snack(result.userMessage);
      }
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _refreshAgentStatus() async {
    if (_agentRefreshBusy) return;
    setState(() => _agentRefreshBusy = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final agents = await _agentRepo
          .watchAgents(ownerUid: uid)
          .first
          .timeout(const Duration(seconds: 4), onTimeout: () => _remoteAgents);
      if (!mounted) return;
      setState(() => _remoteAgents = agents);
    } catch (_) {
      if (mounted) _snack('Agent 상태를 다시 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _agentRefreshBusy = false);
    }
  }

  Future<void> _reconcileTransferStatus({bool silent = false}) async {
    final plan = _activeDoc;
    final iid = _instruction?.instructionId.trim().isNotEmpty == true
        ? _instruction!.instructionId
        : plan?.stableInstructionId;
    if (plan == null || iid == null || iid.isEmpty) return;
    if (plan.wasTransferred) {
      await _refreshRemoteOperationalState(fromServer: true);
      if (!silent && mounted) {
        final evidence = _remoteEvidence;
        if (evidence.remoteLoaded &&
            !TransferredWorkReconciliation.hasRemoteDeliveryEvidence(
              plan,
              evidence,
            )) {
          _snack('원격 작업 기록을 찾지 못했습니다.');
        } else if (_operationalProjectReady) {
          _snack('제작공정 등록 완료');
        } else {
          _snack('AI 제작공정을 준비하고 있습니다.');
        }
      }
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await _refreshAgentStatus();
      final reconciled = await _delivery.reconcileExisting(
        instructionId: iid,
        ownerUid: uid,
      );
      if (reconciled != null &&
          reconciled.delivered &&
          plan.instruction != null) {
        final doc = WorkInstructionRemoteDelivery.markDelivered(
          plan: plan,
          result: reconciled,
          instruction: plan.instruction,
        );
        await _store.upsertPlan(doc);
        await _refreshPlans();
        if (!mounted) return;
        setState(() {
          _activeDoc = doc;
          _lastTransferResult = null;
        });
        if (!silent) _snack('이미 전달된 작업으로 확인되었습니다.');
        return;
      }
      if (!silent) {
        _snack('아직 전달 완료로 확인되지 않았습니다. 진단 도구에서 추가 확인하세요.');
      }
    } catch (_) {
      if (!silent) _snack('상태 확인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _copyDeliveryGptMemo() async {
    final step7 = _step7DeliveryView;
    final memo = WorkInstructionDeliveryPresentation.transferGptMemo(
      failure: step7.failure,
      agentStatus: step7.agentStatus,
      plan: _activeDoc,
      validation: _contractValidation,
      lastResult: _effectiveLastTransferResult,
    );
    await Clipboard.setData(ClipboardData(text: memo));
    _snack('문제 해결 메모를 복사했습니다.');
  }

  void _onDeliveryDiagnosticAction(DeliveryDiagnosticAction action) {
    switch (action) {
      case DeliveryDiagnosticAction.recheckStatus:
        _reconcileTransferStatus();
      case DeliveryDiagnosticAction.agentLinkTest:
      case DeliveryDiagnosticAction.relayTest:
      case DeliveryDiagnosticAction.deliveryPathTest:
      case DeliveryDiagnosticAction.openRemoteControl:
        widget.onOpenRemoteDiagnostics?.call();
      case DeliveryDiagnosticAction.validationReview:
        _showValidationIssues();
      case DeliveryDiagnosticAction.openWorkshop:
        _openWorkshopForCurrent();
      case DeliveryDiagnosticAction.copyGptMemo:
        _copyDeliveryGptMemo();
    }
  }

  void _openWorkshopForCurrent() {
    final id = (_instruction?.instructionId ?? _instructionId ?? '').trim();
    _openWorkshopFor(id);
  }

  void _openWorkshopFor(String instructionId) {
    widget.onOpenProductWorkshop?.call(instructionId: instructionId);
  }

  void _recheckWorkshopStatus() {
    unawaited(_recheckWorkshopStatusAsync());
  }

  Future<void> _recheckWorkshopStatusAsync() async {
    await _refreshRemoteOperationalState(fromServer: true);
    if (!mounted) return;
    final id = (_instruction?.instructionId ?? _instructionId ?? '').trim();
    final evidence = _remoteEvidence;
    if (id.isNotEmpty &&
        evidence.remoteLoaded &&
        !evidence.hasJobFor(id) &&
        !evidence.hasProjectFor(id)) {
      _snack('원격 작업 기록을 찾지 못했습니다.');
      return;
    }
    _snack(_operationalProjectReady ? '제작공정 등록 완료' : 'AI 제작공정을 준비하고 있습니다.');
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

  void _loadPlan(BusinessPlanDocument plan, {bool silent = false}) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _activePlanId = plan.id;
      _instructionId = plan.stableInstructionId;
      _version = plan.version;
      _applyInput(plan.input);
      _analysis = plan.analysis;
      _instruction = plan.instruction;
      _activeDoc = plan;
      _lastTransferResult = null;
      _aiProductionPilot = plan.instruction?.aiExecution?.enabled == true;
      _approvalMode = plan.instruction?.aiExecution?.approvalMode == 'auto'
          ? 'auto'
          : 'manual';
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
    if (!silent) {
      _snack(
        '「${plan.input.topic.isEmpty ? '제목 없음' : plan.input.topic}」을(를) 불러왔습니다.',
      );
    }
  }

  void _resetWizardToNewSession() {
    _activePlanId = null;
    _instructionId = null;
    _version = 1;
    _analysis = null;
    _instruction = null;
    _activeDoc = null;
    _lastTransferResult = null;
    _resumeInput = null;
    _resumePlanId = null;
    _aiProductionPilot = true;
    _approvalMode = 'manual';
    _inputModeQuick = true;
    _wizardState = PlanningWizardState(mode: 'quick');
    _designState = WorkInstructionWizardSession.emptyDesign();
    _applyInput(const BusinessPlanInput());
  }

  Future<void> _parkCurrentDraftIfNeeded() async {
    final current = _currentInput;
    if (!WorkInstructionWizardSession.isUnsentResumable(current, _allPlans)) {
      return;
    }
    await _store.saveParkedDraftInput(current);
    _resumeInput = current;
    if (_activePlanId != null &&
        _activeDoc != null &&
        !_activeDoc!.wasTransferred) {
      _resumePlanId = _activePlanId;
    }
  }

  Future<void> _startNewPlan({IdeaToPlanningSeed? seed}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _parkCurrentDraftIfNeeded();
    if (!mounted) return;
    final s = seed ?? widget.ideaSeed;
    setState(() {
      _resetWizardToNewSession();
      _showResumeBanner = false;
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
      }
    });
    unawaited(_store.persistActivePlanId(null));
    _persistDraft();
    if (s != null && s.title.trim().isNotEmpty) {
      _snack('아이디어「${s.title}」을(를) 새 기획으로 불러왔습니다.');
    }
  }

  void _resumeDraft() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_resumePlanId != null) {
      final match = _allPlans.where(
        (p) => p.id == _resumePlanId && !p.wasTransferred,
      );
      if (match.isNotEmpty) {
        _loadPlan(match.first, silent: true);
        setState(() => _showResumeBanner = false);
        unawaited(_store.saveParkedDraftInput(null));
        return;
      }
    }
    final input = _resumeInput;
    if (input == null || !WorkInstructionWizardSession.hasProgress(input)) {
      setState(() => _showResumeBanner = false);
      return;
    }
    setState(() {
      _applyInput(input);
      _designState = WorkInstructionWizardSession.restoreDesign(input);
      _wizardState = _designState.toWizardState();
      _inputModeQuick = _wizardState.mode != 'advanced';
      _activePlanId = null;
      _instructionId = null;
      _version = 1;
      _analysis = null;
      _instruction = null;
      _activeDoc = null;
      _lastTransferResult = null;
      _showResumeBanner = false;
    });
    unawaited(_store.saveParkedDraftInput(null));
    _persistDraft();
  }

  void _onOccupiedConcept(ConceptOccupancyView view) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(view.guidance),
        action: widget.onOpenProductWorkshop == null
            ? null
            : SnackBarAction(
                label: 'AI 제작공정에서 보기',
                onPressed: () => widget.onOpenProductWorkshop?.call(),
              ),
      ),
    );
  }

  String? _appliedIdeaSeedId;

  void _consumeIdeaSeedIfNeeded() {
    final s = widget.ideaSeed;
    if (s == null || s.title.trim().isEmpty) return;
    final key = '${s.title}|${s.targetCustomer}|${s.memo}';
    if (_appliedIdeaSeedId == key) return;
    _appliedIdeaSeedId = key;
    unawaited(_startNewPlan(seed: s));
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
        title: Text(
          WorkInstructionWorkshopPresentation.validationHeadline(result),
        ),
        content: SingleChildScrollView(
          child: result.ok && result.warnings.isEmpty
              ? const Text('소통24워크 Agent로 보낼 준비가 되었습니다.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (WorkInstructionWorkshopPresentation.validationProblemLines(
                      result,
                    ).isNotEmpty)
                      for (final line
                          in WorkInstructionWorkshopPresentation.validationProblemLines(
                            result,
                          ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(line),
                        ),
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

  Future<void> _showInstructionViewer({BusinessPlanDocument? plan}) async {
    if (plan != null) {
      _loadPlan(plan, silent: true);
    }
    if (_instruction == null) {
      _snack('작업지시서가 없습니다.');
      return;
    }
    await showWorkInstructionViewer(
      context,
      instruction: _instruction!,
      validation: _contractValidation,
    );
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
          if (_showResumeBanner) ...[
            const SizedBox(height: 10),
            _buildResumeDraftBanner(),
          ],
          if (_showWorkshopEmptyPrep) ...[
            const SizedBox(height: 10),
            _buildEmptyWorkshopPrepBanner(),
          ],
          const SizedBox(height: 12),
          _buildTransferredInstructionList(),
          const SizedBox(height: 12),
          if (_inputModeQuick)
            ProjectDesignWizard(
              key: ValueKey(_designState.wizardSessionId),
              initial: _designState,
              occupancy: _conceptOccupancy,
              onChanged: _onDesignChanged,
              onRequestSavePlan: () => _savePlan(),
              onRequestCreateInstruction: () => _createOrPromptInstruction(),
              onRequestRecreateInstruction: _recreateInstructionFromChanges,
              onRequestNewWork: _startNewPlan,
              onOccupiedConcept: _onOccupiedConcept,
              instructionGenerated: _instruction != null,
              instructionStale:
                  _instruction != null && !_instructionMatchesCurrentInput,
            )
          else
            _buildAdvancedForm(),
          if (_showApprovalModeChoice) ...[
            const SizedBox(height: 12),
            _buildApprovalModeCard(),
          ],
          if (_instruction != null) ...[
            const SizedBox(height: 12),
            _buildSendSummaryCard(),
            const SizedBox(height: 12),
            _buildMainActions(),
          ],
          const SizedBox(height: 12),
          OperationalCollapsibleSection(
            title: '기타 작업',
            subtitle: '직접 입력·제작 설정·원문',
            initiallyExpanded: false,
            sectionKey: const Key('planning_other_actions'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeToggle(),
                const SizedBox(height: 12),
                _buildProductionSettingsCard(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _instruction != null
                          ? _showValidationIssues
                          : null,
                      child: const Text('확인 항목 보기'),
                    ),
                    OutlinedButton(
                      onPressed: _instruction != null
                          ? () => _showInstructionViewer()
                          : null,
                      child: const Text('작업지시 원문/고급'),
                    ),
                    OutlinedButton(
                      onPressed: _canCreateInstruction || _instruction != null
                          ? _downloadInstructionJson
                          : null,
                      child: const Text('JSON 다운로드'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BusinessPlanDocument> get _transferredPlans =>
      WorkInstructionWorkshopPresentation.successfulTransfers(
        _allPlans,
        evidence: _remoteEvidence,
        execution: _executionIndex,
      );

  String _formatTransferTime(String? iso) =>
      WorkInstructionWorkshopPresentation.formatTransferTime(iso);

  String _transferStatusLabel(BusinessPlanDocument plan) {
    final exec = _execFor(plan);
    return TransferredWorkReconciliation.transferListStatusLabel(
      exec: exec,
      evidence: _remoteEvidence,
      instructionId: plan.stableInstructionId,
    );
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
          'Sotong24Work로 전송에 성공한 작업지시만 표시합니다. 진행·승인은 AI 제작공정에서 관리합니다.',
          style: TextStyle(fontSize: 12.5, color: ControlColors.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final plan in sent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: ControlColors.surface,
              borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 0,
                      children: [
                        TextButton(
                          onPressed: plan.instruction == null
                              ? null
                              : () => _showInstructionViewer(plan: plan),
                          child: const Text('작업지시 내용 보기'),
                        ),
                        if (widget.onOpenProductWorkshop != null)
                          TextButton(
                            onPressed: () =>
                                _openWorkshopFor(plan.stableInstructionId),
                            child: Text(
                              Sotong24WorkshopPresentation.projectForInstruction(
                                        _remoteProjects,
                                        plan.stableInstructionId,
                                      ) ==
                                      null
                                  ? 'AI 제작공정 준비 중'
                                  : 'AI 제작공정에서 보기',
                            ),
                          ),
                      ],
                    ),
                  ],
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
    final isAiProductionPilot =
        _aiProductionPilot &&
        (ArtifactType.normalize(input.resolvedArtifactType) ==
                ArtifactType.ebook ||
            ArtifactType.normalize(input.resolvedArtifactType) ==
                ArtifactType.app);
    final validation = _contractValidation;

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
              '사업유형',
              ArtifactType.labelKo(input.resolvedArtifactType),
            ),
            _sendSummaryRow(
              '제목',
              input.topic.trim().isEmpty ? '(미입력)' : input.topic.trim(),
            ),
            _sendSummaryRow(
              '대상',
              WorkInstructionWorkshopPresentation.humanizeAudienceOrField(
                input.targetCustomer.trim().isEmpty
                    ? '(미입력)'
                    : input.targetCustomer.trim(),
              ),
            ),
            _sendSummaryRow(
              '제작 목적',
              input.desiredOutcome.trim().isEmpty
                  ? '(미입력)'
                  : input.desiredOutcome.trim(),
            ),
            _sendSummaryRow(
              '핵심 내용',
              input.customerProblem.trim().isEmpty
                  ? '(미입력)'
                  : input.customerProblem.trim(),
              maxLines: 3,
            ),
            _sendSummaryRow(
              '제작 방식',
              WorkInstructionWorkshopPresentation.productionMethodLabel(
                aiPilotEnabled: isEbookPilot,
                artifactType: input.resolvedArtifactType,
              ),
            ),
            _sendSummaryRow(
              '승인 방식',
              WorkInstructionWorkshopPresentation.approvalModeLabel(
                approvalRequired:
                    isAiProductionPilot && _approvalMode == 'manual',
              ),
            ),
            if (input.constraints.trim().isNotEmpty)
              _sendSummaryRow(
                '주요 제작 조건',
                input.constraints.trim(),
                maxLines: 3,
              ),
            if (input.extraRequests.trim().isNotEmpty)
              _sendSummaryRow(
                '특별 요구사항',
                input.extraRequests.trim(),
                maxLines: 3,
              ),
            if (validation != null && !validation.canTransfer) ...[
              const SizedBox(height: 8),
              Text(
                WorkInstructionWorkshopPresentation.validationHeadline(
                  validation,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ControlColors.accentWarm,
                ),
              ),
              for (final line
                  in WorkInstructionWorkshopPresentation.validationProblemLines(
                    validation,
                  ).take(4))
                Text(
                  line,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ControlColors.textSecondary,
                  ),
                ),
              TextButton(
                onPressed: _showValidationIssues,
                child: const Text('문제 항목 확인'),
              ),
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

  Widget _sendSummaryRow(String label, String value, {int maxLines = 2}) {
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
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeDraftBanner() {
    return Material(
      key: const Key('planning_resume_draft_banner'),
      elevation: 1,
      borderRadius: BorderRadius.circular(10),
      color: ControlColors.warningBg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ControlColors.accentWarm.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이전에 작성하던 작업이 있습니다.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('planning_resume_draft_button'),
                  onPressed: _resumeDraft,
                  child: const Text('이어하기'),
                ),
                OutlinedButton(
                  key: const Key('planning_new_work_button'),
                  onPressed: () => unawaited(_startNewPlan()),
                  child: const Text('새 작업 시작'),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildProductionSettingsCard() {
    final isEbook =
        _artifactType == ArtifactType.undecided ||
        ArtifactType.normalize(_artifactType) == ArtifactType.ebook;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('제작 설정', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI 자동 제작 (전자책)'),
          subtitle: const Text(
            '검증을 통과한 제작 단계를 순서대로 진행합니다. 외부 등록·출시는 실행하지 않습니다.',
            style: TextStyle(fontSize: 12.5),
          ),
          value: _aiProductionPilot && isEbook,
          onChanged: !isEbook
              ? null
              : (v) => setState(() => _aiProductionPilot = v),
        ),
        const Divider(height: 16),
        _sendSummaryRow(
          '제작 방식',
          WorkInstructionWorkshopPresentation.productionMethodLabel(
            aiPilotEnabled: _aiProductionPilot && isEbook,
            artifactType: _artifactType,
          ),
        ),
        _sendSummaryRow(
          '승인 방식',
          WorkInstructionWorkshopPresentation.approvalModeLabel(
            approvalRequired:
                _aiProductionPilot && isEbook && _approvalMode == 'manual',
          ),
        ),
        _sendSummaryRow('제작 언어', '한국어 (영어는 향후 locale 확장 예정)'),
        _sendSummaryRow(
          '품질 수준',
          WorkInstructionWorkshopPresentation.qualityLevelLabel(() {
            final levelSel = _designState.productionSelections['level'];
            if (levelSel == null || levelSel.isEmpty) return null;
            return levelSel.first;
          }()),
        ),
      ],
    );
  }

  bool get _showApprovalModeChoice {
    final artifact = ArtifactType.normalize(
      _artifactType == ArtifactType.undecided
          ? _currentInput.resolvedArtifactType
          : _artifactType,
    );
    return _aiProductionPilot &&
        (artifact == ArtifactType.ebook || artifact == ArtifactType.app);
  }

  Widget _buildApprovalModeCard() {
    final instructionMode = _instruction?.aiExecution?.approvalMode;
    final needsRecreate =
        instructionMode != null && instructionMode != _approvalMode;
    return Card(
      key: const Key('planning_approval_mode_card'),
      color: ControlColors.warningBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '승인 방식',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '작업지시를 최종 생성·전송하기 전에 반드시 확인해 주세요.',
              style: TextStyle(
                fontSize: 12.5,
                color: ControlColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              key: const Key('planning_approval_mode_selector'),
              segments: const [
                ButtonSegment(value: 'manual', label: Text('수동 승인')),
                ButtonSegment(value: 'auto', label: Text('자동 승인')),
              ],
              selected: {_approvalMode},
              onSelectionChanged: (value) {
                setState(() => _approvalMode = value.first);
              },
            ),
            const SizedBox(height: 12),
            const _ApprovalModeDescription(
              icon: Icons.touch_app_outlined,
              title: '수동 승인',
              description: '각 단계 검증 PASS 후 기다립니다. 결과를 보고 승인 또는 보완 요청할 수 있습니다.',
            ),
            const SizedBox(height: 8),
            const _ApprovalModeDescription(
              icon: Icons.auto_awesome_outlined,
              title: '자동 승인',
              description:
                  'validator와 단계 계약을 통과한 결과만 다음 단계로 진행합니다. 오류·지연·quota·보안 문제는 자동 승인하지 않습니다.',
            ),
            if (needsRecreate) ...[
              const SizedBox(height: 10),
              const Text(
                '승인 방식이 바뀌었습니다. 전송 전에 작업지시를 새 버전으로 다시 생성해 값과 요약을 일치시키세요.',
                key: Key('planning_approval_mode_recreate_notice'),
                style: TextStyle(
                  color: ControlColors.accentWarm,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
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

  Widget _buildMainActions() {
    if (_instruction == null ||
        !_isInstructionReady ||
        _isInstructionArchived) {
      return const SizedBox.shrink();
    }
    return _buildStep7DeliveryPanel();
  }

  Widget _buildStep7DeliveryPanel() {
    return Step7DeliveryPanel(
      view: _step7DeliveryView,
      onTransfer: _transferToWork,
      onOpenRemoteDiagnostics: widget.onOpenRemoteDiagnostics,
      onOpenProductWorkshop: widget.onOpenProductWorkshop == null
          ? null
          : _openWorkshopForCurrent,
      onViewInstruction: _instruction != null
          ? () => _showInstructionViewer()
          : null,
      onDiagnosticAction: _onDeliveryDiagnosticAction,
      onCopyGptMemo: _copyDeliveryGptMemo,
      onShowValidation: _showValidationIssues,
      onRecheckWorkshop: _recheckWorkshopStatus,
    );
  }
}

class _ApprovalModeDescription extends StatelessWidget {
  const _ApprovalModeDescription({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ControlColors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title\n',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: description,
                  style: const TextStyle(
                    color: ControlColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
