import 'package:flutter/material.dart';

import '../data/sotong24_workflows.dart';
import '../models/instruction_contract.dart';
import '../models/sotong24_remote_models.dart';
import '../services/sotong24_remote_repository.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/sotong24_production_guide_panel.dart';
import '../widgets/sotong24_stage_widgets.dart';

/// 소통24워크 — PC Sotong24Work 원격 관제·승인 화면.
/// 내부 destination key는 `productWorkshop`을 유지한다.
class ProductWorkshopScreen extends StatefulWidget {
  const ProductWorkshopScreen({super.key, this.repository});

  final Sotong24RemoteRepository? repository;

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
        final focus = _pickFocusProject(projects);
        final anyDemo = projects.any((p) => p.isDemo);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '소통24워크',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '선택된 제품을 실제로 제작하는 곳입니다. PC 소통24워크 상태를 확인하고 승인·보완을 요청합니다.',
              style: TextStyle(
                color: ControlColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (anyDemo) ...[
              const SizedBox(height: 10),
              _InfoBanner(
                text: _repo.usesMemory
                    ? 'Firebase 미연결 — 데모(연동 전) 데이터로 표시합니다. 실제 제품 데이터와 구분됩니다.'
                    : 'Firestore에 프로젝트가 없어 데모(연동 전) 샘플을 함께 표시합니다.',
              ),
            ],
            const SizedBox(height: 14),
            if (focus != null) _CurrentWorkCard(project: focus),
            if (focus == null) const _InfoBanner(text: '진행 중인 제작 프로젝트가 없습니다.'),
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
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '해당 조건의 프로젝트가 없습니다.',
                  style: TextStyle(color: ControlColors.textMuted),
                ),
              )
            else
              for (final p in filtered) ...[
                _ProjectCard(project: p, onOpen: () => _openDetail(p)),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            Sotong24ProductionGuidePanel(focusProject: focus),
          ],
        );
      },
    );
  }

  Sotong24RemoteProject? _pickFocusProject(List<Sotong24RemoteProject> all) {
    for (final p in all) {
      if (p.status == Sotong24WorkStatus.awaitingApproval) return p;
    }
    for (final p in all) {
      if (p.status != Sotong24WorkStatus.completed) return p;
    }
    return all.isEmpty ? null : all.first;
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
          final showApprovalActions =
              project.status == Sotong24WorkStatus.awaitingApproval ||
              project.approvalStatus == ApprovalStatus.pending ||
              (stage != null &&
                  (stage.status == Sotong24WorkStatus.awaitingApproval ||
                      stage.approvalStatus == ApprovalStatus.pending));
          final workflow = Sotong24WorkflowCatalog.forProduct(
            project.productType,
            contentSubtype: project.contentSubtype,
          );
          final stageDef = stage == null
              ? null
              : (workflow.byId(stage.stageId) ??
                    workflow.byOrder(stage.stageNumber));
          final stats = Sotong24StageStats.fromProject(project);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (project.isDemo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _InfoBanner(text: '데모(연동 전) 프로젝트입니다.'),
                ),
              Text(
                project.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                workflow.title,
                style: const TextStyle(
                  color: ControlColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _Kv('제작 종류', project.productTypeLabel),
              _Kv('시작일', _formatTime(project.startedAt)),
              _Kv('현재 상태', Sotong24WorkStatus.labelKo(project.status)),
              _Kv(
                'PC 상태',
                Sotong24PcLinkStatus.labelKo(project.resolvedPcStatus),
              ),
              _Kv('진행', '${project.currentStage} / ${project.totalStages}'),
              _Kv('진행률', '${project.progress}%'),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (project.progress.clamp(0, 100)) / 100,
                  minHeight: 12,
                  backgroundColor: ControlColors.border,
                ),
              ),
              const SizedBox(height: 10),
              Sotong24StatsRow(stats: stats),
              if (showApprovalActions && stage != null) ...[
                const SizedBox(height: 16),
                Sotong24NowTodoPanel(
                  project: project,
                  stage: stage,
                  def: stageDef,
                ),
              ],
              const SizedBox(height: 20),
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
                  fontSize: 13,
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
                const SizedBox(height: 16),
                Text(
                  '결과 확인',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _ResultPanel(stage: stage),
              ],
              if (showApprovalActions && stage != null) ...[
                const SizedBox(height: 20),
                Text(
                  '승인',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '승인해도 배포·판매 등록·Git push는 자동 실행되지 않습니다. PC가 요청을 확인한 뒤 다음 단계를 진행합니다.',
                  style: TextStyle(
                    color: ControlColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _onApprove(project, stage),
                    child: const Text('승인', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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

  String _resolveRequestId(Sotong24RemoteStage stage) {
    if (stage.activeRequestId.isNotEmpty) return stage.activeRequestId;
    return 'req_${stage.stageId}_${DateTime.now().millisecondsSinceEpoch}';
  }

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
        content: Text(err ?? '승인했습니다. PC 소통24워크가 요청을 확인하면 다음 단계로 진행합니다.'),
      ),
    );
  }

  Future<void> _onRevision(
    Sotong24RemoteProject project,
    Sotong24RemoteStage stage,
  ) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('보완 요청'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '보완할 내용을 구체적으로 적어 주세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('요청'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    ).showSnackBar(SnackBar(content: Text(err ?? '보완 요청을 저장했습니다.')));
  }
}

class _CurrentWorkCard extends StatelessWidget {
  const _CurrentWorkCard({required this.project});

  final Sotong24RemoteProject project;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            project.productTypeLabel,
            style: const TextStyle(
              color: ControlColors.teal,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            project.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (project.progress.clamp(0, 100)) / 100,
              minHeight: 12,
              backgroundColor: ControlColors.border,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${project.progress}% · ${project.currentStage} / ${project.totalStages} 단계'
            '${project.currentStageDoc == null ? '' : ' · ${project.currentStageDoc!.stageName}'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Sotong24StatsRow(stats: Sotong24StageStats.fromProject(project)),
          const SizedBox(height: 10),
          _Kv('상태', Sotong24WorkStatus.labelKo(project.status)),
          _Kv('PC상태', Sotong24PcLinkStatus.labelKo(project.resolvedPcStatus)),
          _Kv('마지막 동기화', _formatTime(project.lastHeartbeat)),
          _Kv(
            '워크플로',
            Sotong24WorkflowCatalog.forProduct(
              project.productType,
              contentSubtype: project.contentSubtype,
            ).title,
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onOpen});

  final Sotong24RemoteProject project;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ControlColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (project.isDemo) const _DemoBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${project.productTypeLabel} · '
                '${project.currentStage}/${project.totalStages} · '
                '${project.progress}%',
                style: const TextStyle(
                  color: ControlColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '상태: ${Sotong24WorkStatus.labelKo(project.status)}',
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                '업데이트: ${_formatTime(project.updatedAt)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: ControlColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
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
            if (_http(stage.resultUrl))
              TextButton.icon(
                onPressed: () => _open(stage.resultUrl),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('결과 파일/PDF 열기'),
              ),
            if (_http(stage.previewUrl))
              TextButton.icon(
                onPressed: () => _open(stage.previewUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('미리보기 링크'),
              ),
          ] else
            const Text(
              '열 수 있는 웹/Storage URL이 아직 없습니다. (로컬 경로는 표시하지 않습니다)',
              style: TextStyle(color: ControlColors.textMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  bool _http(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  Future<void> _open(String url) async {
    await ExternalUrl.open(url);
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
        '소통24워크 데이터를 불러오지 못했습니다.\n$message',
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
