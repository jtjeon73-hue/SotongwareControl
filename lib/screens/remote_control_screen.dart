import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/artifact_type.dart';
import '../models/commercial/production_review_status_envelope.dart';
import '../models/remote_agent_models.dart';
import '../services/auth_service.dart';
import '../services/remote_agent_repository.dart';
import '../services/remote_control_api.dart';
import '../services/remote_work_instruction_source.dart';
import '../models/remote_e2e_sample.dart';
import '../models/sotong24_remote_models.dart';
import '../services/remote_e2e_sample_service.dart';
import '../services/remote_cursor_autostart_test_service.dart';
import '../services/remote_codex_unattended_test_service.dart';
import '../services/sotong24_remote_repository.dart';
import '../services/production_review_status_repository.dart';
import '../services/production_review_workshop_merge.dart';
import '../widgets/remote_e2e_sample_panel.dart';
import '../widgets/remote_cursor_autostart_panel.dart';
import '../widgets/remote_codex_unattended_panel.dart';
import '../widgets/remote_ops_dashboard.dart';
import '../widgets/operational_collapsible_section.dart';
import '../widgets/ops_health_panel.dart';
import '../widgets/production_review_status_card.dart';
import '../services/ops_health_check.dart';
import '../widgets/sidebar_navigation.dart';
import '../theme/control_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 소통24워크 Agent 원격관제 (Backend V1).
class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({
    super.key,
    this.repository,
    this.api,
    this.instructionSource,
    this.auth,
    this.e2eService,
    this.cursorAutostartService,
    this.codexUnattendedService,
    this.workshopRepository,
    this.productionReviewRepository,
    this.onNavigate,
  });

  final RemoteAgentRepository? repository;
  final RemoteControlApi? api;
  final RemoteWorkInstructionSource? instructionSource;
  final AuthClient? auth;
  final RemoteE2eSampleService? e2eService;
  final RemoteCursorAutostartTestService? cursorAutostartService;
  final RemoteCodexUnattendedTestService? codexUnattendedService;
  final Sotong24RemoteRepository? workshopRepository;
  final ProductionReviewStatusRepository? productionReviewRepository;
  final ValueChanged<ControlDestination>? onNavigate;

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  late final RemoteAgentRepository _repo =
      widget.repository ?? RemoteAgentRepository();
  late final RemoteControlApi _api = widget.api ?? RemoteControlApi();
  late final RemoteE2eSampleService _e2e =
      widget.e2eService ?? RemoteE2eSampleService();
  late final RemoteCursorAutostartTestService _cursor =
      widget.cursorAutostartService ?? RemoteCursorAutostartTestService();
  late final RemoteCodexUnattendedTestService _codex =
      widget.codexUnattendedService ?? RemoteCodexUnattendedTestService();
  late final Sotong24RemoteRepository _workshop =
      widget.workshopRepository ?? Sotong24RemoteRepository();
  late final ProductionReviewStatusRepository _productionReview =
      widget.productionReviewRepository ?? ProductionReviewStatusRepository();
  var _ownsWorkshop = false;
  var _ownsProductionReview = false;

  String _jobFilter = 'all';
  bool _e2eBusy = false;
  bool _cursorBusy = false;
  bool _codexBusy = false;
  bool _diagnosticsOpen = false;
  Key _diagnosticsKey = const ValueKey('remote_diagnostics_closed');
  RemoteE2eSampleSession _e2eSession = const RemoteE2eSampleSession();
  RemoteE2eSampleSession _cursorSession = const RemoteE2eSampleSession();
  RemoteE2eSampleSession _codexSession = const RemoteE2eSampleSession();
  var _dashboardRefreshing = false;

  @override
  void initState() {
    super.initState();
    _ownsWorkshop = widget.workshopRepository == null;
    _ownsProductionReview = widget.productionReviewRepository == null;
    widget.instructionSource;
    _refreshE2eSession();
    _refreshCursorSession();
    _refreshCodexSession();
  }

  @override
  void dispose() {
    if (_ownsWorkshop) _workshop.dispose();
    if (_ownsProductionReview) _productionReview.dispose();
    super.dispose();
  }

  Future<void> _refreshE2eSession() async {
    final loaded = await _e2e.loadSession();
    if (mounted) setState(() => _e2eSession = loaded);
  }

  Future<void> _refreshCursorSession() async {
    final loaded = await _cursor.loadSession();
    if (mounted) setState(() => _cursorSession = loaded);
  }

  Future<void> _refreshCodexSession() async {
    final loaded = await _codex.loadSession();
    if (mounted) setState(() => _codexSession = loaded);
  }

  Future<void> _refreshDashboard() async {
    setState(() => _dashboardRefreshing = true);
    await Future.wait([
      _refreshE2eSession(),
      _refreshCursorSession(),
      _refreshCodexSession(),
    ]);
    if (mounted) setState(() => _dashboardRefreshing = false);
  }

  void _openDiagnostics() {
    setState(() {
      _diagnosticsOpen = true;
      _diagnosticsKey = UniqueKey();
    });
  }

  static const _preferredReviewInstructionId =
      'wi_test_cursor_app_step15_1788441053773';

  /// Prefer STEP15 app test instruction, else any with envelope
  /// (prefer changes_requested).
  ProductionReviewStatusEnvelope? _deriveProductionReview(
    List<Sotong24RemoteProject> workshops,
  ) {
    ProductionReviewStatusEnvelope? preferred;
    ProductionReviewStatusEnvelope? changesRequested;
    ProductionReviewStatusEnvelope? any;
    for (final p in workshops) {
      final e = p.productionReviewStatus;
      if (e == null) continue;
      any ??= e;
      if (p.projectId == _preferredReviewInstructionId ||
          e.instructionId == _preferredReviewInstructionId) {
        preferred = e;
      }
      if (e.ownerReview.decision == 'changes_requested') {
        changesRequested ??= e;
      }
    }
    return preferred ?? changesRequested ?? any;
  }

  void _openProductionReviewR2Draft(ProductionReviewStatusEnvelope envelope) {
    ProductionReviewStatusCard.showR2DraftSheet(context, envelope);
  }

  Sotong24RemoteProject? _matchWorkshop(
    List<Sotong24RemoteProject> workshops,
    String instructionId,
  ) {
    final iid = instructionId.trim();
    if (iid.isEmpty) return null;
    for (final p in workshops) {
      if (p.projectId == iid) return p;
    }
    return null;
  }

  String? get _uid {
    final fromAuth = widget.auth?.currentUser?.uid;
    if (fromAuth != null || widget.auth != null) return fromAuth;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return StreamBuilder<List<RemoteAgentDoc>>(
      stream: _repo.watchAgents(ownerUid: uid),
      builder: (context, agentSnap) {
        final agents = agentSnap.data ?? const <RemoteAgentDoc>[];
        return StreamBuilder<List<RemoteJobDoc>>(
          stream: _repo.watchJobs(ownerUid: uid),
          builder: (context, jobSnap) {
            final jobs = jobSnap.data ?? const <RemoteJobDoc>[];
            return StreamBuilder<List<Sotong24RemoteProject>>(
              stream: _workshop.watchProjects(),
              builder: (context, workshopSnap) {
                final rawWorkshops =
                    workshopSnap.data ?? const <Sotong24RemoteProject>[];
                return StreamBuilder<ProductionReviewStatusQueryResult>(
                  stream: _productionReview.watchRecent(),
                  builder: (context, reviewSnap) {
                    final reviewResult =
                        reviewSnap.data ??
                        const ProductionReviewStatusQueryResult(loading: true);
                    final envelopes = reviewResult.envelopes;
                    final workshops = ProductionReviewWorkshopMerge.merge(
                      projects: rawWorkshops,
                      envelopes: envelopes,
                    );
                    final primaryReview =
                        ProductionReviewWorkshopMerge.pickPrimary(
                          envelopes: envelopes,
                          preferredInstructionId: _preferredReviewInstructionId,
                        ) ??
                        _deriveProductionReview(workshops);
                    final awaiting =
                        ProductionReviewWorkshopMerge.awaitingOwnerReview(
                          envelopes,
                        );
                    final matched = _matchWorkshop(
                      workshops,
                      _e2eSession.instructionId,
                    );
                    final codexMatched = _matchWorkshop(
                      workshops,
                      _codexSession.instructionId,
                    );
                    final e2eView = _e2e.buildView(
                      session: _e2eSession,
                      agents: agents,
                      jobs: jobs,
                      workshopStatus: matched?.status,
                      workshopProgressPercent: matched?.overallProgressPercent,
                      workshopCurrentStage: matched?.currentStage,
                      workshopTotalStages: matched?.totalStages,
                    );
                    final cursorView = _cursor.buildView(
                      session: _cursorSession,
                      agents: agents,
                      jobs: jobs,
                    );
                    final codexView = _codex.buildView(
                      session: _codexSession,
                      agents: agents,
                      jobs: jobs,
                      workshopStatus: codexMatched?.status,
                      workshopProgressPercent:
                          codexMatched?.overallProgressPercent,
                      workshopCurrentStage: codexMatched?.currentStage,
                      workshopTotalStages: codexMatched?.totalStages,
                    );
                    final healthReport = OpsHealthCheck.evaluate(
                      agents: agents,
                      jobs: jobs,
                      workshops: workshops,
                    );
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 900;
                        return ListView(
                          padding: EdgeInsets.fromLTRB(
                            narrow ? 16 : 24,
                            16,
                            narrow ? 16 : 24,
                            32,
                          ),
                          children: [
                            Text(
                              '노트북 원격관제',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '노트북·Agent·AI 작업자의 운영 상태를 확인합니다. '
                              '작업지시 최초 전송은 작업지시 제작소에서 진행하세요.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: ControlColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            RemoteOpsDashboard(
                              agents: agents,
                              workshops: workshops,
                              jobs: jobs,
                              refreshing: _dashboardRefreshing,
                              onRefresh: _refreshDashboard,
                              onOpenWorkshop: widget.onNavigate == null
                                  ? null
                                  : () => widget.onNavigate!(
                                      ControlDestination.productWorkshop,
                                    ),
                              onOpenDiagnostics: _openDiagnostics,
                              productionReview: primaryReview,
                              reviewAwaiting: awaiting,
                              onPrepareR2Draft: () {
                                final envelope = primaryReview;
                                if (envelope == null) return;
                                _openProductionReviewR2Draft(envelope);
                              },
                            ),
                            const SizedBox(height: 16),
                            if (agents.isEmpty)
                              _EmptyAgentsCard(
                                onPair: () => _openPairing(context),
                              )
                            else
                              OperationalCollapsibleSection(
                                title: 'Agent 상태 자세히',
                                subtitle: '연결·heartbeat·현재 작업',
                                sectionKey: const Key('remote_agent_details'),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _openPairing(context),
                                        icon: const Icon(
                                          Icons.add_link,
                                          size: 18,
                                        ),
                                        label: const Text('새 연결'),
                                      ),
                                    ),
                                    for (final a in agents)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _AgentCard(
                                          agent: a,
                                          onDetail: () =>
                                              _openAgentDetail(context, a),
                                          onOpenPlanning:
                                              widget.onNavigate == null
                                              ? null
                                              : () => widget.onNavigate!(
                                                  ControlDestination
                                                      .aiBusinessAnalysis,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            OperationalCollapsibleSection(
                              title: '작업 내역 자세히',
                              subtitle: '원격 Job 목록·필터',
                              sectionKey: const Key('remote_job_history'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _JobFilterChips(
                                    value: _jobFilter,
                                    onChanged: (v) =>
                                        setState(() => _jobFilter = v),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._filteredJobs(jobs).map(
                                    (j) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _JobCard(
                                        job: j,
                                        onOpen: () =>
                                            _openJobDetail(context, j),
                                      ),
                                    ),
                                  ),
                                  if (_filteredJobs(jobs).isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        '표시할 작업이 없습니다.',
                                        style: TextStyle(
                                          color: ControlColors.textMuted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            OperationalCollapsibleSection(
                              title: '개발/진단 도구',
                              subtitle: '버튼으로 점검 · 운영 작업은 만들지 않습니다',
                              initiallyExpanded: _diagnosticsOpen,
                              sectionKey: _diagnosticsKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  OpsHealthPanel(
                                    report: healthReport,
                                    onRunAll: () {
                                      setState(() {});
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            healthReport.overallLabelKo,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '개발자 TEST 전송',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '샘플 작업 생성 — 운영에 사용하지 마세요',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: ControlColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  RemoteE2eSamplePanel(
                                    view: e2eView,
                                    busy: _e2eBusy,
                                    onCreateSample: _e2eCreateSample,
                                    onViewContent: () =>
                                        showRemoteE2eJsonDialog(
                                          context,
                                          _e2eSession.jsonText,
                                        ),
                                    onSendToAgent: () => _e2eSend(e2eView),
                                    onViewStatus: () => _e2eViewStatus(e2eView),
                                    onReset: _e2eReset,
                                    onOpenProductWorkshop:
                                        widget.onNavigate == null
                                        ? null
                                        : () => widget.onNavigate!(
                                            ControlDestination.productWorkshop,
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  RemoteCursorAutostartPanel(
                                    view: cursorView,
                                    busy: _cursorBusy,
                                    onCreate: _cursorCreate,
                                    onViewContent: () =>
                                        showRemoteE2eJsonDialog(
                                          context,
                                          _cursorSession.jsonText,
                                        ),
                                    onSendToAgent: () =>
                                        _cursorSend(cursorView),
                                    onReset: _cursorReset,
                                  ),
                                  const SizedBox(height: 16),
                                  RemoteCodexUnattendedPanel(
                                    view: codexView,
                                    busy: _codexBusy,
                                    onCreate: _codexCreate,
                                    onViewContent: () =>
                                        showRemoteE2eJsonDialog(
                                          context,
                                          _codexSession.jsonText,
                                        ),
                                    onSendToAgent: () => _codexSend(codexView),
                                    onViewStatus: () =>
                                        _codexViewStatus(codexView),
                                    onReset: _codexReset,
                                    onOpenProductWorkshop:
                                        widget.onNavigate == null
                                        ? null
                                        : () => widget.onNavigate!(
                                            ControlDestination.productWorkshop,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<RemoteJobDoc> _filteredJobs(List<RemoteJobDoc> jobs) {
    switch (_jobFilter) {
      case 'running':
        return jobs
            .where(
              (j) =>
                  j.status == 'running' ||
                  j.status == 'claimed' ||
                  j.status == 'queued',
            )
            .toList();
      case 'waiting':
        return jobs
            .where(
              (j) =>
                  j.status == 'waiting_approval' ||
                  j.status == 'revision_requested',
            )
            .toList();
      case 'done':
        return jobs.where((j) => j.status == 'completed').toList();
      case 'error':
        return jobs
            .where((j) => j.status == 'failed' || j.status == 'cancelled')
            .toList();
      default:
        return jobs;
    }
  }

  Future<void> _openPairing(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PairingSheet(api: _api, repo: _repo),
    );
  }

  Future<void> _openAgentDetail(BuildContext context, RemoteAgentDoc agent) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _AgentDetailPage(agent: agent)),
    );
  }

  Future<void> _openJobDetail(BuildContext context, RemoteJobDoc job) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _JobDetailPage(repo: _repo, jobId: job.jobId),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _e2eCreateSample() async {
    setState(() => _e2eBusy = true);
    try {
      final session = await _e2e.createSample(ownerUid: _uid);
      if (!mounted) return;
      setState(() => _e2eSession = session);
      _toast(context, '샘플 작업지시서를 생성했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast(context, '생성 실패: $e');
    } finally {
      if (mounted) setState(() => _e2eBusy = false);
    }
  }

  Future<void> _e2eReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('테스트 초기화'),
        content: const Text(
          '새 instructionId로 샘플을 다시 만듭니다.\n'
          '기존 전송·Job 기록은 삭제하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _e2eBusy = true);
    try {
      final session = await _e2e.resetSample(ownerUid: _uid);
      if (!mounted) return;
      setState(() => _e2eSession = session);
      _toast(context, '새 테스트 샘플이 준비되었습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast(context, '초기화 실패: $e');
    } finally {
      if (mounted) setState(() => _e2eBusy = false);
    }
  }

  Future<void> _e2eViewStatus(RemoteE2eSampleView fallback) async {
    RemoteE2eSampleView view = fallback;
    try {
      final results = await Future.wait([
        _repo.watchAgents(ownerUid: _uid).first,
        _repo.watchJobs(ownerUid: _uid).first,
        _workshop.watchProjects().first,
      ]);
      final agents = results[0] as List<RemoteAgentDoc>;
      final jobs = results[1] as List<RemoteJobDoc>;
      final workshops = results[2] as List<Sotong24RemoteProject>;
      Sotong24RemoteProject? matched;
      final iid = _e2eSession.instructionId.trim();
      if (iid.isNotEmpty) {
        for (final p in workshops) {
          if (p.projectId == iid) {
            matched = p;
            break;
          }
        }
      }
      view = _e2e.buildView(
        session: _e2eSession,
        agents: agents,
        jobs: jobs,
        workshopStatus: matched?.status,
        workshopProgressPercent: matched?.overallProgressPercent,
        workshopCurrentStage: matched?.currentStage,
        workshopTotalStages: matched?.totalStages,
      );
    } catch (_) {
      view = fallback;
    }
    if (!mounted) return;
    await showRemoteE2eStatusSheet(context, view);
  }

  Future<void> _e2eSend(RemoteE2eSampleView view) async {
    final agent = view.targetAgent;
    if (agent == null) {
      _toast(
        context,
        view.sendBlockedReason.isNotEmpty
            ? view.sendBlockedReason
            : 'Online Agent가 없습니다.',
      );
      return;
    }
    setState(() => _e2eBusy = true);
    try {
      final jobs = await _repo.watchJobs(ownerUid: _uid).first;
      final updated = await _e2e.sendToAgent(
        session: _e2eSession,
        agent: agent,
        api: _api,
        jobs: jobs,
        ownerUid: _uid,
      );
      if (!mounted) return;
      setState(() => _e2eSession = updated);
      _toast(context, '전송 완료 · ${agent.deviceName} · Job ${updated.sentJobId}');
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _toast(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      _toast(context, '전송 실패: $e');
    } finally {
      if (mounted) setState(() => _e2eBusy = false);
    }
  }

  Future<void> _cursorCreate() async {
    setState(() => _cursorBusy = true);
    try {
      final session = await _cursor.createSample(ownerUid: _uid);
      if (!mounted) return;
      setState(() => _cursorSession = session);
      _toast(context, 'Cursor 자동실행 TEST 생성 · ${session.instructionId}');
    } catch (e) {
      if (!mounted) return;
      _toast(context, '생성 실패: $e');
    } finally {
      if (mounted) setState(() => _cursorBusy = false);
    }
  }

  Future<void> _cursorReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cursor TEST 초기화'),
        content: const Text(
          '새 instructionId로 Cursor 자동실행 TEST를 다시 만듭니다.\n'
          '기존 E2E 샘플·Job은 변경하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cursorBusy = true);
    try {
      final session = await _cursor.resetSample(ownerUid: _uid);
      if (!mounted) return;
      setState(() => _cursorSession = session);
      _toast(context, '새 Cursor TEST가 준비되었습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast(context, '초기화 실패: $e');
    } finally {
      if (mounted) setState(() => _cursorBusy = false);
    }
  }

  Future<void> _cursorSend(RemoteE2eSampleView view) async {
    final agent = view.targetAgent;
    if (agent == null) {
      _toast(
        context,
        view.sendBlockedReason.isNotEmpty
            ? view.sendBlockedReason
            : 'Online Agent가 없습니다.',
      );
      return;
    }
    setState(() => _cursorBusy = true);
    try {
      final jobs = await _repo.watchJobs(ownerUid: _uid).first;
      final updated = await _cursor.sendToAgent(
        session: _cursorSession,
        agent: agent,
        api: _api,
        jobs: jobs,
        ownerUid: _uid,
      );
      if (!mounted) return;
      setState(() => _cursorSession = updated);
      _toast(
        context,
        'Cursor TEST 전송 완료 · ${agent.deviceName} · Job ${updated.sentJobId}',
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _toast(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      _toast(context, '전송 실패: $e');
    } finally {
      if (mounted) setState(() => _cursorBusy = false);
    }
  }

  Future<void> _codexCreate() async {
    setState(() => _codexBusy = true);
    try {
      final session = await _codex.createSample(ownerUid: _uid);
      if (!mounted) return;
      setState(() => _codexSession = session);
      _toast(context, 'Codex 무인작업 TEST 생성 · ${session.instructionId}');
    } catch (e) {
      if (!mounted) return;
      _toast(context, '생성 실패: $e');
    } finally {
      if (mounted) setState(() => _codexBusy = false);
    }
  }

  Future<void> _codexReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Codex TEST 초기화'),
        content: const Text(
          '새 instructionId로 Codex 무인작업 TEST를 다시 만듭니다.\n'
          '기존 E2E·Cursor 샘플·Job은 변경하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _codexBusy = true);
    try {
      final session = await _codex.resetSample(ownerUid: _uid);
      if (!mounted) return;
      setState(() => _codexSession = session);
      _toast(context, '새 Codex TEST가 준비되었습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast(context, '초기화 실패: $e');
    } finally {
      if (mounted) setState(() => _codexBusy = false);
    }
  }

  Future<void> _codexViewStatus(RemoteE2eSampleView view) async {
    if (!mounted) return;
    await showRemoteE2eStatusSheet(context, view);
  }

  Future<void> _codexSend(RemoteE2eSampleView view) async {
    final agent = view.targetAgent;
    if (agent == null) {
      _toast(
        context,
        view.sendBlockedReason.isNotEmpty
            ? view.sendBlockedReason
            : 'Online Agent가 없습니다.',
      );
      return;
    }
    setState(() => _codexBusy = true);
    try {
      final jobs = await _repo.watchJobs(ownerUid: _uid).first;
      final updated = await _codex.sendToAgent(
        session: _codexSession,
        agent: agent,
        api: _api,
        jobs: jobs,
        ownerUid: _uid,
      );
      if (!mounted) return;
      setState(() => _codexSession = updated);
      _toast(
        context,
        'Codex TEST 전송 완료 · ${agent.deviceName} · Job ${updated.sentJobId}',
      );
    } on RemoteControlApiException catch (e) {
      if (!mounted) return;
      _toast(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      _toast(context, '전송 실패: $e');
    } finally {
      if (mounted) setState(() => _codexBusy = false);
    }
  }
}

class _EmptyAgentsCard extends StatelessWidget {
  const _EmptyAgentsCard({required this.onPair});
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '연결된 노트북 Agent가 없습니다',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '휴대폰에서 연결 코드를 만들고, 노트북 Sotong24Work Agent에 입력하세요.',
            style: TextStyle(color: ControlColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPair,
            icon: const Icon(Icons.link),
            label: const Text('노트북 Agent 연결하기'),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.onDetail,
    this.onOpenPlanning,
  });

  final RemoteAgentDoc agent;
  final VoidCallback onDetail;
  final VoidCallback? onOpenPlanning;

  @override
  Widget build(BuildContext context) {
    final kind = agent.uiKind;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_dot(kind), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.deviceName.isEmpty ? '소통24워크 Agent' : agent.deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('상태: ${agent.stateLabelKo}'),
          Text('장치: ${agent.deviceName}'),
          if (agent.appVersion.isNotEmpty) Text('앱 버전: ${agent.appVersion}'),
          Text('마지막 연결: ${formatRelativeKo(agent.lastHeartbeatAt)}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onOpenPlanning != null)
                FilledButton(
                  onPressed: onOpenPlanning,
                  child: const Text('작업지시 제작소로 이동'),
                ),
              OutlinedButton(onPressed: onDetail, child: const Text('상세 보기')),
            ],
          ),
        ],
      ),
    );
  }

  String _dot(RemoteAgentUiKind kind) {
    switch (kind) {
      case RemoteAgentUiKind.online:
        return '🟢';
      case RemoteAgentUiKind.offline:
        return '⚪';
      case RemoteAgentUiKind.running:
        return '🔵';
      case RemoteAgentUiKind.waitingApproval:
        return '🟠';
      case RemoteAgentUiKind.error:
        return '🔴';
    }
  }
}

class _JobFilterChips extends StatelessWidget {
  const _JobFilterChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('all', '전체'),
      ('running', '진행 중'),
      ('waiting', '승인 대기'),
      ('done', '완료'),
      ('error', '오류'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (id, label) in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: value == id,
                onSelected: (_) => onChanged(id),
              ),
            ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onOpen});

  final RemoteJobDoc job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ControlColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ArtifactType.labelKo(job.type),
              style: TextStyle(color: ControlColors.textMuted, fontSize: 12),
            ),
            Text(
              job.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('단계: ${job.currentStage.isEmpty ? '—' : job.currentStage}'),
            Text('상태: ${job.statusLabelKo}'),
            if (jobCompletedDurationLabel(job) != null)
              Text('소요시간: ${jobCompletedDurationLabel(job)}'),
            Text('업데이트: ${formatRelativeKo(job.updatedAt)}'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onOpen, child: const Text('상세 보기')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairingSheet extends StatefulWidget {
  const _PairingSheet({required this.api, required this.repo});
  final RemoteControlApi api;
  final RemoteAgentRepository repo;

  @override
  State<_PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends State<_PairingSheet> {
  RemotePairingResult? _pairing;
  String? _error;
  bool _loading = false;
  Timer? _tick;
  StreamSubscription<RemoteAgentDoc?>? _sub;
  RemoteAgentDoc? _linked;

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
      _linked = null;
    });
    try {
      final p = await widget.api.createPairing();
      _sub?.cancel();
      _sub = widget.repo.watchPairingCompletion(sessionId: p.sessionId).listen((
        a,
      ) {
        if (a != null && mounted) {
          setState(() => _linked = a);
        }
      });
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _pairing = p);
    } on RemoteControlApiException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(() => _error = '연결 코드를 만들지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pairing;
    final remain = p == null
        ? Duration.zero
        : p.expiresAt.difference(DateTime.now().toUtc());
    final expired = p != null && remain.isNegative;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '노트북 Agent 연결',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_linked != null) ...[
            Text(
              '연결 완료: ${_linked!.deviceName}',
              style: TextStyle(
                color: ControlColors.accentGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ] else if (p == null) ...[
            Text(
              '새 연결 코드를 만들면 노트북 Agent에 입력할 수 있습니다.',
              style: TextStyle(color: ControlColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('새 연결 코드 만들기'),
            ),
          ] else ...[
            const Text('노트북 Agent 연결 코드'),
            const SizedBox(height: 8),
            SelectableText(
              p.pairingCode,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              expired
                  ? '코드가 만료되었습니다.'
                  : '유효시간: ${_fmt(p.expiresAt.toLocal())} · 남은시간: ${_remain(remain)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: p.pairingCode));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('코드를 복사했습니다.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('코드 복사'),
                ),
                FilledButton(
                  onPressed: _loading ? null : _create,
                  child: const Text('새 코드 만들기'),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: ControlColors.accentRose)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _remain(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

class _AgentDetailPage extends StatelessWidget {
  const _AgentDetailPage({required this.agent});
  final RemoteAgentDoc agent;

  @override
  Widget build(BuildContext context) {
    final shortId = agent.agentId.length <= 12
        ? agent.agentId
        : '${agent.agentId.substring(0, 12)}…';
    return Scaffold(
      appBar: AppBar(title: const Text('Agent 상세')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _kv('상태', agent.stateLabelKo),
          _kv('온라인', agent.isOnline() ? '예' : '아니오'),
          _kv('heartbeat', formatRelativeKo(agent.lastHeartbeatAt)),
          _kv(
            'Relay',
            agent.isOnline()
                ? 'heartbeat 갱신됨 (간접 확인)'
                : '확인 필요 — 전용 Relay 필드 없음',
          ),
          _kv('현재 작업', agent.currentJobId.isEmpty ? '없음' : agent.currentJobId),
          _kv('현재 단계', agent.currentStage.isEmpty ? '—' : agent.currentStage),
          _kv(
            '최근 오류',
            agent.lastError.trim().isEmpty ? '없음' : agent.lastError.trim(),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                '진단정보 보기',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              children: [
                _kv('장치명', agent.deviceName),
                _kv('Agent ID', shortId),
                _kv('앱 버전', agent.appVersion.isEmpty ? '—' : agent.appVersion),
                _kv('프로토콜', agent.protocolVersion),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Agent token은 표시하지 않습니다.',
                    style: TextStyle(
                      color: ControlColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: TextStyle(color: ControlColors.textMuted)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _JobDetailPage extends StatelessWidget {
  const _JobDetailPage({required this.repo, required this.jobId});
  final RemoteAgentRepository repo;
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('작업 상세')),
      body: StreamBuilder<RemoteJobDoc?>(
        stream: repo.watchJob(jobId),
        builder: (context, jobSnap) {
          final job = jobSnap.data;
          if (job == null) {
            return const Center(child: Text('작업을 찾을 수 없습니다.'));
          }
          return StreamBuilder<List<RemoteStageDoc>>(
            stream: repo.watchStages(jobId),
            builder: (context, stageSnap) {
              final stages = stageSnap.data ?? const <RemoteStageDoc>[];
              final pct = job.totalStages <= 0
                  ? 0.0
                  : (job.progress.clamp(0, 100) / 100.0);
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text('상태: ${job.statusLabelKo}'),
                  Text(
                    '단계: ${job.currentStage.isEmpty ? '—' : job.currentStage}',
                  ),
                  if (jobCompletedDurationLabel(job) != null)
                    Text('소요시간: ${jobCompletedDurationLabel(job)}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: pct == 0 ? null : pct),
                  Text('전체 진행률 ${job.progress}%'),
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        '진단정보 보기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Text('jobId: ${job.jobId}'),
                        Text(
                          'instructionId: ${job.instructionId.isEmpty ? '—' : job.instructionId}',
                        ),
                        Text(
                          'assignedAgentId: ${job.assignedAgentId.isEmpty ? '—' : job.assignedAgentId}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '승인·보완은 AI 제작공정에서 진행합니다.',
                    style: TextStyle(
                      color: ControlColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '단계',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (stages.isEmpty)
                    Text(
                      '단계 보고가 아직 없습니다.',
                      style: TextStyle(color: ControlColors.textMuted),
                    )
                  else
                    ...stages.map((s) {
                      final mark = s.status == 'completed'
                          ? '✅'
                          : (s.status == 'running' ||
                                s.status == 'waiting_approval')
                          ? '🔵'
                          : '⚪';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '$mark ${s.stageNumber.toString().padLeft(2, '0')} ${s.stageName.isEmpty ? s.stageId : s.stageName}',
                        ),
                        subtitle: s.summary.isEmpty
                            ? Text(s.status)
                            : Text('${s.status} · ${s.summary}'),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
