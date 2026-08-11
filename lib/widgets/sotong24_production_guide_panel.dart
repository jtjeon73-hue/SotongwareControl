import 'package:flutter/material.dart';

import '../data/sotong24_production_guides.dart';
import '../models/artifact_type.dart';
import '../models/sotong24_guide_models.dart';
import '../models/sotong24_remote_models.dart';
import '../theme/control_theme.dart';

/// 사업별 표준 제작 가이드 패널 (참고용 매뉴얼).
/// 실제 제작 진행률은 원격관제 프로젝트 데이터이며, 이 패널의 체크리스트와 혼동하지 않는다.
class Sotong24ProductionGuidePanel extends StatefulWidget {
  const Sotong24ProductionGuidePanel({super.key, this.focusProject});

  /// 목록의 포커스 프로젝트 — 같은 제품이면 "현재 제작 단계" 표시(데모면 배지).
  final Sotong24RemoteProject? focusProject;

  @override
  State<Sotong24ProductionGuidePanel> createState() =>
      _Sotong24ProductionGuidePanelState();
}

class _Sotong24ProductionGuidePanelState
    extends State<Sotong24ProductionGuidePanel> {
  String _productId = 'ebook';
  String _contentSubtype = ContentSubtype.shorts;
  var _mode = _GuideViewMode.guide;
  final _search = TextEditingController();
  var _productPickerExpanded = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Sotong24ProductGuide get _guide => Sotong24ProductionGuideCatalog.guideFor(
    _productId,
    contentSubtype: _productId == 'contents' ? _contentSubtype : '',
  );

  String? get _highlightStageId {
    final p = widget.focusProject;
    if (p == null) return null;
    final key = p.productType == 'industrial' || p.productType.contains('산업')
        ? 'industrial'
        : (p.productType == ArtifactType.contents
              ? 'contents'
              : ArtifactType.normalize(p.productType));
    if (key != _productId) return null;
    return p.currentStageDoc?.stageId;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 768;
    final guide = _guide;
    final q = _search.text.trim();
    final stages = q.isEmpty ? guide.stages : guide.search(q);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '사업별 표준 제작 가이드',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '제품을 처음 기획하는 단계부터 제작·검사·출시·운영까지 사업별 표준 제작 절차를 확인할 수 있습니다. '
          '가이드는 참고용이며, 실제 진행상태는 원격관제 프로젝트 데이터입니다.',
          style: TextStyle(color: ControlColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 12),
        _buildProductPicker(isMobile),
        if (_productId == 'contents') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in ContentSubtype.allSelectable)
                ChoiceChip(
                  label: Text(ContentSubtype.labelKo(s)),
                  selected: _contentSubtype == s,
                  onSelected: (_) => setState(() => _contentSubtype = s),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '제작 가이드 검색 (예: 저작권, PLC, SEO, CTA)',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('전체 가이드'),
              selected: _mode == _GuideViewMode.guide,
              onSelected: (_) => setState(() => _mode = _GuideViewMode.guide),
            ),
            ChoiceChip(
              label: const Text('체크리스트'),
              selected: _mode == _GuideViewMode.checklist,
              onSelected: (_) =>
                  setState(() => _mode = _GuideViewMode.checklist),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_mode == _GuideViewMode.checklist)
          _ChecklistView(guide: guide)
        else ...[
          _SummaryCard(guide: guide),
          const SizedBox(height: 10),
          _FlowOverview(flow: guide.flowOverview),
          const SizedBox(height: 10),
          if (guide.subtypeExtraNotes(_contentSubtype).isNotEmpty &&
              _productId == 'contents') ...[
            _SubtypeNotes(notes: guide.subtypeExtraNotes(_contentSubtype)),
            const SizedBox(height: 10),
          ],
          Text(
            '단계별 상세 (${stages.length}/${guide.totalStages})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (stages.isEmpty)
            const Text(
              '검색 결과가 없습니다.',
              style: TextStyle(color: ControlColors.textMuted),
            )
          else
            for (final s in stages)
              _StageAccordion(
                stage: s,
                isCurrent: _highlightStageId == s.stageId,
                isDemoFocus: widget.focusProject?.isDemo == true,
              ),
        ],
      ],
    );
  }

  Widget _buildProductPicker(bool isMobile) {
    final chips = [
      for (final id in Sotong24ProductionGuideCatalog.productIds)
        ChoiceChip(
          label: Text(Sotong24ProductionGuideCatalog.labelKo(id)),
          selected: _productId == id,
          onSelected: (_) => setState(() {
            _productId = id;
            _productPickerExpanded = false;
          }),
        ),
    ];

    if (!isMobile) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    final selected = Sotong24ProductionGuideCatalog.labelKo(_productId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(
              () => _productPickerExpanded = !_productPickerExpanded,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _productPickerExpanded ? '사업 선택' : '사업 · $selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    _productPickerExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_productPickerExpanded) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ],
    );
  }
}

enum _GuideViewMode { guide, checklist }

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.guide});

  final Sotong24ProductGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ControlColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ControlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guide.guideTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text('목표', style: _labelStyle),
          Text(guide.goal, style: const TextStyle(height: 1.35)),
          const SizedBox(height: 8),
          Text('전체 단계: ${guide.totalStages}단계', style: _labelStyle),
          const SizedBox(height: 8),
          Text('핵심 결과물', style: _labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in guide.keyDeliverables)
                Chip(
                  label: Text(d, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowOverview extends StatelessWidget {
  const _FlowOverview({required this.flow});

  final List<String> flow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('예상 흐름', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < flow.length; i++) ...[
              Text(
                flow[i],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (i < flow.length - 1)
                const Icon(Icons.arrow_forward, size: 14),
            ],
          ],
        ),
      ],
    );
  }
}

class _SubtypeNotes extends StatelessWidget {
  const _SubtypeNotes({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: ControlColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('유형별 추가 가이드', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('· $n', style: const TextStyle(height: 1.35)),
            ),
        ],
      ),
    );
  }
}

class _ChecklistView extends StatelessWidget {
  const _ChecklistView({required this.guide});

  final Sotong24ProductGuide guide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ControlColors.warningBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ControlColors.accentWarm),
          ),
          child: const Text(
            '이 체크리스트는 참고용입니다. 실제 제작 진행률·승인 상태와 연결되어 있지 않습니다.',
            style: TextStyle(height: 1.35, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${guide.label} 핵심 검사항목',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final item in guide.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('□ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(item, style: const TextStyle(height: 1.35)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StageAccordion extends StatelessWidget {
  const _StageAccordion({
    required this.stage,
    required this.isCurrent,
    required this.isDemoFocus,
  });

  final Sotong24StageGuide stage;
  final bool isCurrent;
  final bool isDemoFocus;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isCurrent ? ControlColors.teal : ControlColors.border,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${stage.order}. ${stage.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isCurrent) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ControlColors.tealSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDemoFocus ? '현재 단계(데모)' : '현재 제작 단계',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ControlColors.teal,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          stage.purpose,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ControlColors.textSecondary),
        ),
        children: [
          _field('단계 목적', stage.purpose),
          _field('왜 필요한가', stage.whyNeeded),
          _bullets('주요 작업', stage.mainTasks),
          _field('AI가 하는 일', stage.aiWork),
          _bullets('사람이 확인할 일', stage.humanChecks),
          _bullets('입력자료', stage.inputs),
          _bullets('생성 결과물', stage.deliverables),
          _bullets('품질검사 기준', stage.qualityCriteria),
          _bullets('승인 기준', stage.approvalCriteria),
          _bullets('자주 발생하는 문제', stage.commonProblems),
          _bullets('주의사항', stage.cautions),
          _bullets('완료 조건', stage.completionConditions),
          _field('다음 단계', stage.nextStep),
          if (stage.approvalTypicallyRequired)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '이 단계는 사용자 승인이 필요한 경우가 많습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: ControlColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          Text(value, style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }

  Widget _bullets(String label, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          for (final i in items)
            Text('· $i', style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 12,
  color: ControlColors.textMuted,
);
