import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/business_planning.dart';
import '../models/dev_work_doc_status.dart';
import '../models/planning_wizard_state.dart';
import '../services/business_planning_service.dart';
import '../services/business_planning_store.dart';
import '../services/dev_work_doc_paths.dart';
import '../services/dev_work_doc_service.dart';
import '../services/dev_work_doc_verify.dart';
import '../services/instruction_transfer_service.dart';
import '../services/plan_progress_status.dart';
import '../services/planning_sentence_composer.dart';
import '../services/work_instruction_filename.dart';
import '../services/work_instruction_validator.dart';
import '../theme/control_theme.dart';
import '../widgets/ops_ui.dart';
import '../widgets/planning_wizard_panel.dart';

/// AI 사업분석 내 「사업 기획·작업지시」 탭 (로컬 규칙 기반, 외부 AI 없음).
class BusinessPlanningTab extends StatefulWidget {
  const BusinessPlanningTab({super.key});

  @override
  State<BusinessPlanningTab> createState() => _BusinessPlanningTabState();
}

class _BusinessPlanningTabState extends State<BusinessPlanningTab> {
  final _service = BusinessPlanningService();
  final _store = BusinessPlanningStore();
  final _transfer = InstructionTransferService();
  final _devWorkDoc = DevWorkDocService();
  final _validator = WorkInstructionValidator();
  final _composer = const PlanningSentenceComposer();

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
  bool _inputModeQuick = true;
  String _statusFilter = 'all';
  FolderPermissionState? _folderState;
  DevWorkDocState? _devDocState;
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
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _wizardTimer?.cancel();
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
      final results = await Future.wait([
        _store.loadPlans(),
        _store.loadDraftInput(),
        _transfer.currentState(),
        _devWorkDoc.currentState(),
      ]);
      final plans = results[0] as List<BusinessPlanDocument>;
      final draft = results[1] as BusinessPlanInput?;
      final folder = results[2] as FolderPermissionState;
      final devDoc = results[3] as DevWorkDocState;
      if (!mounted) return;
      setState(() {
        _allPlans = BusinessPlanningStore.dedupeById(plans);
        _folderState = folder;
        _devDocState = devDoc;
        _loading = false;
        if (draft != null) {
          _applyInput(draft);
          if (draft.wizardSelections != null) {
            _wizardState = PlanningWizardState.fromJson(
              draft.wizardSelections!,
            );
            _inputModeQuick = _wizardState.mode != 'advanced';
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  BusinessPlanInput get _currentInput {
    if (_inputModeQuick) {
      final composed = _composer.toBusinessPlanInput(_wizardState);
      final artifact = _wizardState.effectiveArtifactType;
      if (artifact != null && artifact != ArtifactType.undecided) {
        return composed.copyWith(
          artifactType: artifact,
          contentSubtype: _wizardState.contentSubtype == null
              ? ''
              : ContentSubtype.normalize(_wizardState.contentSubtype!),
          artifactAnswers: Map<String, List<String>>.from(
            _wizardState.artifactAnswers,
          ),
          deliverableTypes: [artifact],
          wizardSelections: _wizardState.toJson(),
        );
      }
      return composed.copyWith(
        wizardSelections: _wizardState.toJson(),
        artifactAnswers: Map<String, List<String>>.from(
          _wizardState.artifactAnswers,
        ),
      );
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
      return sub != ContentSubtype.undecided;
    }
    return true;
  }

  bool get _canTransfer =>
      _instruction != null &&
      _validator.validate(input: _currentInput, instruction: _instruction!).ok;

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

  void _onWizardChanged(PlanningWizardState state) {
    _wizardState = state;
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
    _allPlans = BusinessPlanningStore.dedupeById(await _store.loadPlans());
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
  }) {
    final iid = instructionId ?? _instructionId ?? _stableInstructionId(id);
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
      versionHistory: versionHistory ?? _activeDoc?.versionHistory ?? const [],
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

  DevWorkDocStatus get _devWorkDocStatus => DevWorkDocStatus.resolve(
    devDocState: _devDocState,
    lastSaveResult: _lastDevWorkDocResult,
    instruction: _instruction,
    activeDoc: _activeDoc,
    transferFolder: _folderState,
    input: _currentInput,
  );

  bool get _devWorkDocFolderReady => _devDocState?.readyToWrite == true;

  String _selectionKindLabel(DevWorkDocSelectionKind kind) {
    switch (kind) {
      case DevWorkDocSelectionKind.devWorkDocRoot:
        return 'DevWorkDoc 루트 (권장)';
      case DevWorkDocSelectionKind.repoRootWithDevWorkDoc:
        return '저장소 루트 — DevWorkDoc 하위 필요';
      case DevWorkDocSelectionKind.ambiguous:
        return '확인 필요';
      case DevWorkDocSelectionKind.none:
        return '미선택';
    }
  }

  String _boolLabel(bool? value) {
    if (value == null) return '—';
    return value ? '완료' : '미완료';
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
    if (!_canCreateInstruction) {
      _snack('주제·고객 문제·대상·결과·제작 형태를 먼저 완성하세요.');
      return;
    }
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

    var instruction = _service.buildInstruction(
      planId: id,
      input: input,
      analysis: analysis,
      now: now,
      instructionId: iid,
      version: version,
      createdAt: preserveCreatedAt,
      updatedAt: preserveUpdatedAt,
      status: PlanningStatus.instructionReady,
    );

    // 동일 버전 재저장: 핵심 내용이 같으면 기존 스냅샷 JSON을 재사용 (메타데이터 드리프트 방지)
    if (!isNewVersion &&
        existingInstruction != null &&
        existingInstruction.instructionVersion == '$version' &&
        compareInstructionContent(
              existingInstruction.toJson(),
              instruction.toJson(),
            ) ==
            InstructionContentRelation.sameCore) {
      instruction = existingInstruction;
    } else {
      final provisionalMap = Map<String, dynamic>.from(instruction.toJson())
        ..remove('checksum');
      final checksum = stableContentChecksum(provisionalMap);
      final sourceFileName =
          'WI_${DevWorkDocPaths.sanitizeInstructionId(iid)}.json';
      instruction = _service.buildInstruction(
        planId: id,
        input: input,
        analysis: analysis,
        now: now,
        instructionId: iid,
        version: version,
        createdAt: instruction.createdAt,
        updatedAt: instruction.updatedAt,
        checksum: checksum,
        sourceFileName: sourceFileName,
        status: PlanningStatus.instructionReady,
      );
    }

    final jsonText = const JsonEncoder.withIndent(
      '  ',
    ).convert(instruction.toJson());
    final artifact = input.resolvedArtifactType;
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

    final validation = _validator.validate(
      input: input,
      instruction: instruction,
    );
    final status = isDownloadComplete
        ? PlanningStatus.downloadedPendingImport
        : validation.ok
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
        '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님). '
        'v$version · ${saveResult.fileName ?? ''}',
      );
    } else if (saveResult.isFolderCompleteSuccess ||
        saveResult.outcome == DevWorkDocSaveOutcome.recoveredFromPartial) {
      _snack(
        saveResult.outcome == DevWorkDocSaveOutcome.recoveredFromPartial
            ? '부분 저장 복구 완료. v$version\n'
                  'Active: ${saveResult.activeBytes}B · Versions: ${saveResult.versionsBytes}B'
            : 'DevWorkDoc에 저장했습니다. v$version\n'
                  'Active: 저장·검증 완료 (${saveResult.activeBytes}B)\n'
                  'Versions: v$version 저장·검증 완료 (${saveResult.versionsBytes}B)',
      );
    } else if (saveResult.outcome == DevWorkDocSaveOutcome.alreadyExists) {
      _snack(
        'DevWorkDoc 기존 파일 확인 (동일 핵심 checksum). v$version\n'
        'Active·Versions v$version 검증 완료',
      );
    } else if (validation.ok) {
      _snack('작업지시서를 생성했습니다. (v$version)');
    } else {
      _snack('작업지시서를 생성했으나 검증 이슈가 있습니다. 「기타 작업」에서 확인하세요.');
    }
  }

  Future<void> _transferToWork() async {
    if (_transferBusy) return;
    if (_instruction == null) {
      _snack('먼저 작업지시서를 생성하세요.');
      return;
    }

    final validation = _validator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
    if (!validation.ok) {
      _snack('전달 전 검증 오류: ${validation.issues.first.reason}');
      return;
    }

    setState(() => _transferBusy = true);
    try {
      await _savePlan(silent: true);

      final jsonText = const JsonEncoder.withIndent(
        '  ',
      ).convert(_instruction!.toJson());
      final checksum = contentChecksum(jsonText);
      final seq = _allPlans.where((p) => p.lastTransferAt != null).length + 1;
      final fileName = WorkInstructionFilename.build(
        now: DateTime.now(),
        sequence: seq,
        topic: _currentInput.topic,
        deliverableType: _currentInput.primaryDeliverable,
        version: _version,
      );

      final result = await _transfer.writeJsonFile(
        fileName: fileName,
        jsonText: jsonText,
      );

      if (!result.ok) {
        _snack(result.message ?? '전달에 실패했습니다.');
        return;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final newStatus = PlanProgressStatus.statusAfterTransferAttempt(
        mode: result.mode,
      );

      final id = _activePlanId!;
      final existing = _allPlans.firstWhere((p) => p.id == id);
      final doc = existing.copyWith(
        status: newStatus,
        updatedAt: now,
        instruction: _instruction,
        lastTransferAt: now,
        lastTransferFileName: result.fileName ?? fileName,
        lastTransferChecksum: checksum,
        lastTransferMode: result.mode,
      );

      await _store.upsertPlan(doc);
      await _refreshPlans();
      if (!mounted) return;
      final folder = await _transfer.currentState();
      if (!mounted) return;
      setState(() {
        _activeDoc = doc;
        _folderState = folder;
      });

      if (result.mode == PlanProgressStatus.folderMode) {
        _snack('소통24워크 Inbox 전달 완료');
      } else {
        _snack('수동 가져오기용 JSON 다운로드');
      }
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _pickTransferFolder() async {
    final state = await _transfer.pickFolder();
    if (!mounted) return;
    setState(() => _folderState = state);
    if (state.hasHandle) {
      _snack('전달 폴더: ${state.folderName ?? '선택됨'}');
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
    final doc = BusinessPlanDocument(
      id: id,
      input: input,
      status: PlanningStatus.draft,
      createdAt: now,
      updatedAt: now,
      analysis: analysis,
      instructionId: _stableInstructionId(id),
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
            '${_activeDoc?.wasTransferred == true ? '\n\n소통24워크 쪽 파일은 자동 삭제되지 않습니다.' : ''}',
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
      if (plan.input.wizardSelections != null) {
        _wizardState = PlanningWizardState.fromJson(
          plan.input.wizardSelections!,
        );
        _inputModeQuick = _wizardState.mode != 'advanced';
      } else {
        _inputModeQuick = false;
        _wizardState = PlanningWizardState(mode: 'advanced', step: 4);
      }
    });
    _persistDraft();
    _snack(
      '「${plan.input.topic.isEmpty ? '제목 없음' : plan.input.topic}」을(를) 불러왔습니다.',
    );
  }

  void _startNewPlan() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _activePlanId = null;
      _instructionId = null;
      _version = 1;
      _analysis = null;
      _instruction = null;
      _activeDoc = null;
      _inputModeQuick = true;
      _wizardState = PlanningWizardState(mode: 'quick');
      _applyInput(const BusinessPlanInput());
    });
    _persistDraft();
  }

  void _showValidationIssues() {
    if (_instruction == null) {
      _snack('작업지시서가 없습니다.');
      return;
    }
    final result = _validator.validate(
      input: _currentInput,
      instruction: _instruction!,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.ok ? '검증 통과' : '검증 이슈'),
        content: SingleChildScrollView(
          child: result.ok
              ? const Text('소통24워크 전달에 필요한 항목이 모두 충족됩니다.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final issue in result.issues) ...[
                      Text(
                        issue.field,
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
    final text = _service.buildReadableInstruction(_instruction!);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('작업지시서 v${_instruction!.instructionVersion}'),
        content: SingleChildScrollView(child: Text(text)),
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

  String _formatIso(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  PlanProgressView _progressFor(BusinessPlanDocument? plan) {
    return PlanProgressStatus.resolve(
      plan,
      hasDevWorkDocRoot: _devWorkDocFolderReady,
      hasTransferFolder: _folderState?.hasHandle == true,
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
    return _progressFor(plan).badgeLabel;
  }

  Color _planListBadgeColor(BusinessPlanDocument plan) {
    return _progressBadgeColor(_progressFor(plan));
  }

  List<BusinessPlanDocument> get _latestPlans {
    var list = BusinessPlanningStore.latestByInstructionId(_allPlans);
    if (_statusFilter != 'all') {
      list = list
          .where((p) => PlanningStatus.normalize(p.status) == _statusFilter)
          .toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.input.topic.toLowerCase().contains(q) ||
                p.input.customerProblem.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
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
          if (_planReady || _activeDoc != null) ...[
            const SizedBox(height: 10),
            _buildProgressBanner(),
          ],
          const SizedBox(height: 12),
          _buildModeToggle(),
          const SizedBox(height: 12),
          if (_inputModeQuick)
            PlanningWizardPanel(
              initial: _wizardState,
              onChanged: _onWizardChanged,
              onSavePlan: () => _savePlan(),
            )
          else
            _buildAdvancedForm(),
          if (_planReady) ...[
            const SizedBox(height: 12),
            _buildReviewCard(),
            const SizedBox(height: 12),
            _buildWorkflowStepStrip(),
            const SizedBox(height: 12),
            _buildMainActions(),
          ],
          const SizedBox(height: 12),
          _buildDevWorkDocFolderSettings(),
          const SizedBox(height: 12),
          _buildFolderSettings(),
          const SizedBox(height: 20),
          _buildSavedPlansSection(),
        ],
      ),
    );
  }

  Widget _buildProgressBanner() {
    final view = _activeProgressView;
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
                    view.statusLine,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ControlColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    view.nextAction,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ControlColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              label: view.badgeLabel,
              color: _progressBadgeColor(view),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStepStrip() {
    final view = _activeProgressView;
    final steps = [
      _WorkflowStepDef('기획안 완성', _planReady),
      _WorkflowStepDef('작업지시서 생성', _instruction != null),
      _WorkflowStepDef(
        'DevWorkDoc 저장',
        _lastDevWorkDocResult?.mode == PlanProgressStatus.folderMode ||
            (_activeDoc?.hasInstruction == true && _devWorkDocFolderReady),
      ),
      _WorkflowStepDef('소통24워크 전달', view.isTrulyTransferred),
      _WorkflowStepDef('가져오기 확인', view.kind == PlanProgressKind.imported),
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
        '로컬 규칙 기반 기획 도우미입니다. 외부 AI 생성·자동 실행은 없으며, '
        '실제 제작·배포는 소통24워크에서 진행합니다.',
        style: TextStyle(fontSize: 12.5, color: ControlColors.textSecondary),
      ),
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('빠른 선택')),
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
                  label: progress.badgeLabel,
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
          children: [
            if (!_isInstructionArchived)
              FilledButton.icon(
                onPressed: _hasSomeContent ? () => _savePlan() : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('임시 저장'),
              ),
            ..._buildStatusPrimaryActions(),
            if (!_isInstructionArchived) ..._buildTransferActions(),
          ],
        ),
        ..._buildActionHints(),
        if (_instruction != null ||
            _isInstructionArchived ||
            _hasSomeContent) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _showOtherActionsMenu(context),
              icon: const Icon(Icons.more_horiz, size: 18),
              label: const Text('기타 작업'),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildTransferActions() {
    if (_instruction == null ||
        !_isInstructionReady ||
        _isInstructionArchived) {
      return const [];
    }

    final hasFolder = _folderState?.hasHandle == true;
    return [
      if (hasFolder)
        FilledButton.icon(
          onPressed: (_canTransfer && !_transferBusy) ? _transferToWork : null,
          icon: _transferBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined, size: 18),
          label: Text(_transferBusy ? '전달 중…' : '소통24워크 Inbox로 전달'),
        )
      else
        OutlinedButton.icon(
          onPressed: (_canTransfer && !_transferBusy) ? _transferToWork : null,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('수동 가져오기용 JSON 다운로드'),
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
      final hasFolder = _folderState?.hasHandle == true;
      if (!hasFolder) {
        hints.add(
          _actionHint(
            '소통24워크 전달 폴더가 선택되지 않았습니다.',
            '「전달 폴더 선택」 후 Inbox로 전달하거나, '
                '「수동 가져오기용 JSON 다운로드」를 사용하세요.',
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

  Widget _buildDevWorkDocStatusBanner() {
    final status = _devWorkDocStatus;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(status.icon, size: 18, color: ControlColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.displayLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ControlColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.nextAction,
            style: const TextStyle(
              fontSize: 12,
              color: ControlColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
        onPressed: _canCreateInstruction ? _downloadInstructionJson : null,
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('수동 가져오기용 JSON 다운로드'),
      ),
    ];
  }

  Widget _buildDevWorkDocFolderSettings() {
    final devDoc = _devDocState;
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
            _buildDevWorkDocStatusBanner(),
            const SizedBox(height: 10),
            const Text(
              '폴더 선택 시 DevWorkDoc 폴더 자체를 선택하세요 '
              '(저장소 루트나 상위 폴더가 아닙니다). '
              '경로 힌트만으로는 저장 성공으로 간주하지 않습니다.',
              style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
            ),
            const SizedBox(height: 8),
            if (devDoc != null && devDoc.rootFolderName != null)
              Text(
                '선택된 폴더: ${devDoc.rootFolderName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            else if (devDoc != null && !devDoc.supported)
              const Text(
                '이 환경에서는 폴더 직접 저장을 지원하지 않습니다. '
                '「JSON 다운로드」로 파일을 받은 뒤 수동으로 배치하세요.',
                style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
              )
            else
              const Text(
                '폴더가 선택되지 않았습니다.',
                style: TextStyle(color: ControlColors.textMuted),
              ),
            if (devDoc != null) ...[
              const SizedBox(height: 8),
              _buildDevWorkDocReadinessRows(devDoc),
              if (devDoc.statusMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  devDoc.statusMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ControlColors.textSecondary,
                  ),
                ),
              ],
            ],
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
                  label: const Text('작업지시서 관리 폴더 설정'),
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

  Widget _buildDevWorkDocReadinessRows(DevWorkDocState devDoc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _devWorkDocReadinessRow(
          '선택 기준',
          _selectionKindLabel(devDoc.selectionKind),
        ),
        _devWorkDocReadinessRow(
          '쓰기 권한',
          devDoc.permissionGranted ? '허용' : '미허용',
        ),
        _devWorkDocReadinessRow('경로 구조', _boolLabel(devDoc.structureOk)),
        _devWorkDocReadinessRow('실제 저장 준비', _boolLabel(devDoc.readyToWrite)),
      ],
    );
  }

  Widget _devWorkDocReadinessRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: ControlColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFolderSettings() {
    final folder = _folderState;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('소통24워크 전달 폴더', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (folder != null && folder.hasHandle && folder.folderName != null)
              Text(
                '선택된 폴더: ${folder.folderName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            else
              const Text(
                '폴더가 선택되지 않았습니다.',
                style: TextStyle(color: ControlColors.textMuted),
              ),
            const SizedBox(height: 4),
            const Text(
              '권장 위치: Documents\\Sotong24Work\\Instructions\\Inbox',
              style: TextStyle(fontSize: 12, color: ControlColors.textMuted),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickTransferFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('전달 폴더 선택'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlansSection() {
    final visible = _latestPlans;
    final dupTopics = _duplicateTopics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '저장된 기획안',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _startNewPlan,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 기획'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: '주제·문제 검색',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tab in PlanningStatus.filterTabs)
              FilterChip(
                label: Text(PlanningStatus.filterLabel(tab)),
                selected: _statusFilter == tab,
                onSelected: (_) => setState(() => _statusFilter = tab),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const EmptyStatePanel(
            title: '저장된 기획안 없음',
            message: '기획 저장 후 목록에 표시됩니다.',
          )
        else
          for (final plan in visible) _buildPlanTile(plan, dupTopics),
      ],
    );
  }

  Widget _buildPlanTile(BusinessPlanDocument plan, Set<String> dupTopics) {
    final isDup = dupTopics.contains(plan.input.topic.trim().toLowerCase());
    final isActive = plan.id == _activePlanId;
    final history = plan.versionHistory;
    final progress = _progressFor(plan);

    return Card(
      key: ValueKey('plan-${plan.id}'),
      color: isActive ? ControlColors.tealSoft.withValues(alpha: 0.35) : null,
      child: Column(
        children: [
          ListTile(
            onTap: () => _onPlanTileTap(plan),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    plan.input.topic.isEmpty ? '(주제 미입력)' : plan.input.topic,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDup)
                  const StatusBadge(
                    label: '유사 주제',
                    color: ControlColors.accentWarm,
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ArtifactType.labelKo(plan.input.resolvedArtifactType)} · v${plan.version}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                Text(
                  progress.devWorkDocLine,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  progress.transferLine,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '수정: ${_formatIso(plan.updatedAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ControlColors.textMuted,
                  ),
                ),
                Text(
                  progress.nextAction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ControlColors.textSecondary,
                  ),
                ),
              ],
            ),
            isThreeLine: false,
            trailing: StatusBadge(
              label: progress.badgeLabel,
              color: _planListBadgeColor(plan),
            ),
          ),
          if (history.isNotEmpty)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('버전 이력', style: TextStyle(fontSize: 13)),
              children: [
                for (final snap in history.reversed)
                  ListTile(
                    dense: true,
                    title: Text(
                      'v${snap.version} · ${PlanningStatus.labelKo(snap.status)}',
                    ),
                    subtitle: Text(
                      '${_formatIso(snap.createdAt)}'
                      '${snap.transferFileName != null ? ' · ${snap.transferFileName}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WorkflowStepDef {
  const _WorkflowStepDef(this.label, this.done);

  final String label;
  final bool done;
}
