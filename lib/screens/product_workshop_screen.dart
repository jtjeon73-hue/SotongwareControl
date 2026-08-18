import 'package:flutter/material.dart';

import '../data/sotong24_workflows.dart';
import '../models/sotong24_remote_models.dart';
import '../services/sotong24_remote_repository.dart';
import '../services/sotong24_workshop_presentation.dart';
import '../theme/control_theme.dart';
import '../widgets/revision_request_dialog.dart';
import '../widgets/operational_collapsible_section.dart';
import '../widgets/sotong24_stage_widgets.dart';

/// AI 제작공정 — 전송된 작업의 단계 진행·승인·보완 화면.
/// 내부 destination key는 `productWorkshop`을 유지한다.
class ProductWorkshopScreen extends StatefulWidget {
  const ProductWorkshopScreen({
    super.key,
    this.repository,
    this.onStartNewWork,
  });

  final Sotong24RemoteRepository? repository;
  final VoidCallback? onStartNewWork;

  @override
  State<ProductWorkshopScreen> createState() => _ProductWorkshopScreenState();
}

class _ProductWorkshopScreenState extends State<ProductWorkshopScreen> {
  late final Sotong24RemoteRepository _repo;
  var _ownsRepo = false;
  var _filter = Sotong24ProjectFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repo = widget.repository!;
    } else {
      _repo = Sotong24RemoteRepository();
      _ownsRepo = true;
    }
  }

  @override
  void dispose() {
    if (_ownsRepo) _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sotong24RemoteProject>>(
      stream: _repo.watchProjects(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorBody(message: '${snap.error}');
        }
        final projects = snap.data;
        if (projects == null) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        final filtered = projects.where(_filter.matches).toList();
        final primary = filtered
            .where((p) => !p.isDemo && !p.isIncompleteListing)
            .toList();
        final incomplete = filtered
            .where((p) => p.isIncompleteListing && !p.isDemo)
            .toList();
        final realWork = Sotong24WorkshopPresentation.operationalProjects(
          primary,
        );
        final testWork = primary
            .where(Sotong24WorkshopPresentation.isTestProject)
            .toList();
        final awaiting = realWork
            .where(
              (p) => p.userFacingStatus == Sotong24WorkStatus.awaitingApproval,
            )
            .toList();
        final inProgress = realWork
            .where(
              (p) =>
                  p.userFacingStatus != Sotong24WorkStatus.awaitingApproval &&
                  p.userFacingStatus != Sotong24WorkStatus.completed,
            )
            .toList();
        final completed = realWork
            .where((p) => p.userFacingStatus == Sotong24WorkStatus.completed)
            .toList();
        final focus = _pickFocusProject(projects);
        final isEmpty =
            realWork.isEmpty && testWork.isEmpty && incomplete.isEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'AI 제작공정',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '전송된 작업의 진행 상태를 확인하고 승인·보완을 관리합니다.',
              style: TextStyle(
                color: ControlColors.textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (focus != null)
              _CurrentWorkCard(project: focus)
            else if (isEmpty)
              _EmptyWorkshopCard(onStartNewWork: widget.onStartNewWork)
            else
              const _InfoBanner(text: '진행 중인 제작 프로젝트가 없습니다.'),
            if (!isEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '작업 목록',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in Sotong24ProjectFilter.values)
                    ChoiceChip(
                      label: Text(
                        f.labelKo,
                        style: const TextStyle(fontSize: 14),
                      ),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (realWork.isEmpty && testWork.isEmpty && incomplete.isEmpty)
              const SizedBox.shrink()
            else ...[
              if (awaiting.isNotEmpty) ...[
                const _SectionHeader(
                  title: '승인 필요한 작업',
                  subtitle: '결과를 확인하고 승인 또는 보완 요청을 진행하세요.',
                ),
                const SizedBox(height: 8),
                for (final p in awaiting) ...[
                  _ProjectCard(project: p, onOpen: () => _openDetail(p)),
                  const SizedBox(height: 10),
                ],
              ],
              if (inProgress.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionHeader(
                  title: '진행 중',
                  subtitle: 'AI가 작업 중이거나 보완·오류 상태입니다.',
                ),
                const SizedBox(height: 8),
                for (final p in inProgress) ...[
                  _ProjectCard(project: p, onOpen: () => _openDetail(p)),
                  const SizedBox(height: 10),
                ],
              ],
              if (completed.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionHeader(title: '완료', subtitle: '제작이 끝난 작업입니다.'),
                const SizedBox(height: 8),
                for (final p in completed) ...[
                  _ProjectCard(project: p, onOpen: () => _openDetail(p)),
                  const SizedBox(height: 10),
                ],
              ],
              if (testWork.isNotEmpty) ...[
                const SizedBox(height: 8),
                OperationalCollapsibleSection(
                  title: '개발/테스트 작업 보기',
                  subtitle: 'E2E·Agent 검증용 — 데이터는 보존됩니다',
                  sectionKey: const Key('workshop_test_projects'),
                  child: Column(
                    children: [
                      for (final p in testWork) ...[
                        _ProjectCard(project: p, onOpen: () => _openDetail(p)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
              if (incomplete.isNotEmpty) ...[
                const SizedBox(height: 8),
                OperationalCollapsibleSection(
                  title: '진단/불완전 데이터',
                  subtitle: '삭제하지 않은 이전 TEST 항목',
                  sectionKey: const Key('workshop_incomplete_projects'),
                  child: Column(
                    children: [
                      for (final p in incomplete) ...[
                        _ProjectCard(
                          project: p,
                          onOpen: () => _openDetail(p),
                          incomplete: true,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Sotong24RemoteProject? _pickFocusProject(List<Sotong24RemoteProject> all) {
    final real = Sotong24WorkshopPresentation.operationalProjects(all);
    if (real.isEmpty) return null;
    for (final p in real) {
      if (p.userFacingStatus == Sotong24WorkStatus.awaitingApproval) {
        return p;
      }
    }
    for (final p in real) {
      if (p.userFacingStatus != Sotong24WorkStatus.completed) return p;
    }
    return real.first;
  }

  Future<void> _openDetail(Sotong24RemoteProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Sotong24RemoteDetailScreen(
          projectId: project.projectId,
          initialProject: project,
          repository: _repo,
        ),
      ),
    );
  }
}

class Sotong24RemoteDetailScreen extends StatefulWidget {
  const Sotong24RemoteDetailScreen({
    super.key,
    required this.projectId,
    required this.repository,
    this.initialProject,
  });

  final String projectId;
  final Sotong24RemoteRepository repository;
  final Sotong24RemoteProject? initialProject;

  @override
  State<Sotong24RemoteDetailScreen> createState() =>
      _Sotong24RemoteDetailScreenState();
}

class _Sotong24RemoteDetailScreenState
    extends State<Sotong24RemoteDetailScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ControlColors.background,
      appBar: AppBar(title: const Text('제작 상세')),
      body: StreamBuilder<Sotong24RemoteProject?>(
        initialData: widget.initialProject,
        stream: widget.repository.watchProject(widget.projectId),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorBody(message: '${snap.error}');
          }
          final project = snap.data;
          if (project == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final stage = project.currentStageDoc;
          final workflow = Sotong24WorkflowCatalog.forProduct(
            project.productType,
            contentSubtype: project.contentSubtype,
          );
          final stageDef = stage == null
              ? null
              : (workflow.byId(stage.stageId) ??
                    workflow.byOrder(stage.stageNumber));
          final stats = Sotong24StageStats.fromProject(project);
          final testKind = Sotong24WorkshopPresentation.testKind(project);
          final isTest = testKind != WorkshopTestKind.none;
          final displayTitle = Sotong24WorkshopPresentation.displayTitle(
            project,
          );
          final showApprovalActions = project.showApprovalActions;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              if (project.isDemo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _InfoBanner(text: '데모(연동 전) 프로젝트입니다.'),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (isTest)
                    _TestBadge(
                      label: Sotong24WorkshopPresentation.testKindBadgeLabel(
                        testKind,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                project.productTypeLabel,
                style: const TextStyle(
                  color: ControlColors.teal,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              _Kv(
                '현재 단계',
                Sotong24WorkshopPresentation.currentStageLine(project),
              ),
              _Kv('상태', project.userFacingStatusLabel),
              if (Sotong24WorkshopPresentation.revisionLine(project).isNotEmpty)
                _Kv(
                  '결과 버전',
                  Sotong24WorkshopPresentation.revisionLine(
                    project,
                  ).replaceFirst('결과 버전 ', ''),
                ),
              _Kv(
                '전체 진행률',
                Sotong24WorkshopPresentation.overallProgressLine(
                  project,
                ).replaceFirst('전체 진행률 ', ''),
              ),
              if (Sotong24WorkshopPresentation.totalWorkDurationLine(
                project,
              ).isNotEmpty)
                _Kv(
                  '전체 누적 작업시간',
                  Sotong24WorkshopPresentation.totalWorkDurationLine(
                    project,
                  ).replaceFirst('전체 누적 작업시간: ', ''),
                ),
              _Kv('PC', Sotong24PcLinkStatus.labelKo(project.resolvedPcStatus)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (project.overallProgressPercent.clamp(0, 100)) / 100,
                  minHeight: 10,
                  backgroundColor: ControlColors.border,
                ),
              ),
              const SizedBox(height: 8),
              Sotong24StatsRow(stats: stats),
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    '진단정보 보기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ControlColors.textMuted,
                    ),
                  ),
                  children: [
                    _Kv('instructionId', project.projectId),
                    if (stage != null) ...[
                      _Kv('stageId', stage.stageId),
                      _Kv('stage status', stage.status),
                    ],
                    _Kv('project status', project.status),
                    _Kv('approvalStatus', project.approvalStatus),
                    if (project.showReportedProgressDiagnostic)
                      _Kv(
                        'Agent 보고 진행률',
                        '${project.reportedProgressPercent}%',
                      ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '진단정보는 지원·디버깅용입니다. 일반 작업은 위 제목·상태를 기준으로 하세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ControlColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (stage != null) ...[
                const SizedBox(height: 12),
                Sotong24NowTodoPanel(
                  project: project,
                  stage: stage,
                  def: stageDef,
                ),
              ],
              if (project.userFacingStatus == Sotong24WorkStatus.completed) ...[
                const SizedBox(height: 12),
                _CompletedBanner(isTest: isTest),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('목록으로'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '전체 제작 단계 (${workflow.totalStages})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                workflow.summary,
                style: const TextStyle(
                  color: ControlColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              for (final s in project.stages)
                Sotong24ExpandableStageTile(
                  stage: s,
                  isCurrent: s.stageNumber == project.currentStage,
                  def:
                      workflow.byId(s.stageId) ??
                      workflow.byOrder(s.stageNumber),
                ),
              if (stage != null) ...[
                const SizedBox(height: 14),
                Text(
                  '결과 확인',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _ResultPanel(stage: stage),
              ],
              if (showApprovalActions && stage != null) ...[
                const SizedBox(height: 16),
                Text(
                  '승인',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '승인해도 배포·판매 등록·Git push는 자동 실행되지 않습니다.',
                  style: TextStyle(
                    color: ControlColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _onApprove(project, stage),
                    child: const Text('승인', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _onRevision(project, stage),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ControlColors.accentRose,
                      side: const BorderSide(color: ControlColors.accentRose),
                    ),
                    child: const Text('보완 요청', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// preferred hint만 전달. 실제 requestId는 repository.allocateRequestId가
  /// pending 슬롯 재사용 / 처리완료 id면 신규 발급으로 결정한다.
  String _resolveRequestId(Sotong24RemoteStage stage) => stage.activeRequestId;

  Future<void> _onApprove(
    Sotong24RemoteProject project,
    Sotong24RemoteStage stage,
  ) async {
    setState(() => _busy = true);
    final err = await widget.repository.approveStage(
      projectId: project.projectId,
      stageId: stage.stageId,
      requestId: _resolveRequestId(stage),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '승인 요청을 전송했습니다. Agent가 확인하면 다음 단계로 진행합니다.'),
      ),
    );
  }

  Future<void> _onRevision(
    Sotong24RemoteProject project,
    Sotong24RemoteStage stage,
  ) async {
    final message = await showRevisionRequestDialog(context);
    if (message == null || !mounted) return;
    if (message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보완 내용을 입력해 주세요.')));
      return;
    }

    setState(() => _busy = true);
    final err = await widget.repository.requestRevision(
      projectId: project.projectId,
      stageId: stage.stageId,
      requestId: _resolveRequestId(stage),
      message: message,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(err ?? '보완 요청을 전송했습니다.')));
  }
}

class _CurrentWorkCard extends StatelessWidget {
  const _CurrentWorkCard({required this.project});

  final Sotong24RemoteProject project;

  @override
  Widget build(BuildContext context) {
    final testKind = Sotong24WorkshopPresentation.testKind(project);
    final isTest = testKind != WorkshopTestKind.none;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '현재 제작',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (project.isDemo) ...[
                const SizedBox(width: 8),
                const _DemoBadge(),
              ],
              if (!project.isDemo && isTest) ...[
                const SizedBox(width: 8),
                _TestBadge(
                  label: Sotong24WorkshopPresentation.testKindBadgeLabel(
                    testKind,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            project.productTypeLabel,
            style: const TextStyle(
              color: ControlColors.teal,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Sotong24WorkshopPresentation.displayTitle(project),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (project.overallProgressPercent.clamp(0, 100)) / 100,
              minHeight: 10,
              backgroundColor: ControlColors.border,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '현재 단계: ${Sotong24WorkshopPresentation.currentStageLine(project)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(
            Sotong24WorkshopPresentation.overallProgressLine(project),
            style: const TextStyle(
              fontSize: 13,
              color: ControlColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '상태: ${project.userFacingStatusLabel}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (Sotong24WorkshopPresentation.revisionLine(project).isNotEmpty)
            Text(
              Sotong24WorkshopPresentation.revisionLine(project),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          if (project.currentStageDoc != null &&
              Sotong24WorkshopPresentation.stageDurationLine(
                project.currentStageDoc!,
              ).isNotEmpty)
            Text(
              Sotong24WorkshopPresentation.stageDurationLine(
                project.currentStageDoc!,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          Text(
            '마지막 동기화: ${_formatTime(project.lastHeartbeat)}',
            style: const TextStyle(
              fontSize: 12,
              color: ControlColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    this.incomplete = false,
  });

  final Sotong24RemoteProject project;
  final VoidCallback onOpen;
  final bool incomplete;

  @override
  Widget build(BuildContext context) {
    final testKind = Sotong24WorkshopPresentation.testKind(project);
    final isTest = testKind != WorkshopTestKind.none;
    final title = Sotong24WorkshopPresentation.displayTitle(project);
    return Material(
      color: incomplete ? ControlColors.surfaceMuted : ControlColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: incomplete
                  ? ControlColors.border.withValues(alpha: 0.7)
                  : ControlColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: incomplete ? 14 : 15,
                        height: 1.3,
                        color: incomplete
                            ? ControlColors.textSecondary
                            : ControlColors.textPrimary,
                      ),
                    ),
                  ),
                  if (project.isDemo) const _DemoBadge(),
                  if (!project.isDemo && isTest)
                    _TestBadge(
                      label: Sotong24WorkshopPresentation.testKindBadgeLabel(
                        testKind,
                      ),
                    ),
                  if (incomplete)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ControlColors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '진단용',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                incomplete
                    ? (project.productTypeLabel.isEmpty
                          ? '유형 미정'
                          : project.productTypeLabel)
                    : '${project.productTypeLabel}\n'
                          '${Sotong24WorkshopPresentation.listProgressSummary(project)}',
                style: TextStyle(
                  color: ControlColors.textSecondary,
                  fontSize: incomplete ? 12 : 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '상태: ${project.userFacingStatusLabel}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '마지막 동기화: ${_formatTime(project.updatedAt.isNotEmpty ? project.updatedAt : project.lastHeartbeat)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: ControlColors.textMuted,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onOpen, child: const Text('상세보기')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.stage});

  final Sotong24RemoteStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stage.revision > 0) ...[
            Text(
              '최신 결과 r${stage.revision}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
          if (stage.summary.isNotEmpty) ...[
            const Text(
              '단계 결과 요약',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              stage.summary,
              style: const TextStyle(height: 1.4, fontSize: 15),
            ),
            const SizedBox(height: 10),
          ],
          if (stage.workReport.isNotEmpty) ...[
            const Text('작업 보고', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              stage.workReport,
              style: const TextStyle(height: 1.4, fontSize: 15),
            ),
            const SizedBox(height: 10),
          ],
          if (stage.errorMessage.isNotEmpty) ...[
            const Text(
              '오류',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ControlColors.accentRose,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stage.errorMessage,
              style: const TextStyle(height: 1.4, fontSize: 15),
            ),
            const SizedBox(height: 10),
          ],
          if (stage.userAttention.isNotEmpty) ...[
            const Text('확인 필요', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              stage.userAttention,
              style: const TextStyle(height: 1.4, fontSize: 15),
            ),
            const SizedBox(height: 10),
          ],
          if (stage.resultPreview.isNotEmpty) ...[
            const Text(
              '미리보기 설명',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              stage.resultPreview,
              style: const TextStyle(height: 1.4, fontSize: 15),
            ),
            const SizedBox(height: 10),
          ],
          if (stage.hasOpenableResult) ...[
            Sotong24StageResultOpenButtons(stage: stage, compact: true),
          ] else ...[
            const Text(
              '결과 준비 중',
              style: TextStyle(
                color: ControlColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '휴대폰에서 열 수 있는 결과물이 아직 등록되지 않았습니다.',
              style: TextStyle(color: ControlColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: ControlColors.textMuted,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.isTest});

  final bool isTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTest ? 'TEST E2E 완료' : '작업 완료',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '모든 제작 단계가 완료되었습니다.',
            style: TextStyle(fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: ControlColors.textMuted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _TestBadge extends StatelessWidget {
  const _TestBadge({this.label = 'TEST'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2E7D32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1B5E20),
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ControlColors.warningBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ControlColors.accentWarm),
      ),
      child: const Text(
        '데모',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyWorkshopCard extends StatelessWidget {
  const _EmptyWorkshopCard({this.onStartNewWork});

  final VoidCallback? onStartNewWork;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ControlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '현재 진행 중인 작업이 없습니다.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            '작업지시 제작소에서 새 작업을 시작해 주세요.',
            style: TextStyle(
              fontSize: 13.5,
              color: ControlColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (onStartNewWork != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onStartNewWork,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 작업 만들기'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.sandLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ControlColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: ControlColors.textSecondary,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'AI 제작공정 데이터를 불러오지 못했습니다.\n$message',
        style: const TextStyle(color: ControlColors.accentRose, height: 1.4),
      ),
    );
  }
}

String _formatTime(String iso) {
  if (iso.trim().isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
