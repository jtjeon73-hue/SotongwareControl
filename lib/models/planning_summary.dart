/// 기획 마법사 최종 확인용 순수 요약 데이터.
library;

import '../data/artifact_question_catalog.dart';
import '../services/planning_sentence_composer.dart';
import 'business_planning.dart';
import 'planning_wizard_state.dart';

class PlanningSummaryField {
  const PlanningSummaryField({required this.label, required this.value});

  final String label;
  final String value;

  bool get isEmpty => value.trim().isEmpty || value.trim() == '—';
}

class PlanningSummarySection {
  const PlanningSummarySection({required this.title, required this.fields});

  final String title;
  final List<PlanningSummaryField> fields;

  List<PlanningSummaryField> get nonEmptyFields =>
      fields.where((f) => !f.isEmpty).toList();
}

class PlanningSummary {
  const PlanningSummary({
    required this.sections,
    required this.deliverableItems,
  });

  final List<PlanningSummarySection> sections;
  final List<String> deliverableItems;

  /// 레거시·테스트 호환 getter
  String get artifactLabel => _fieldValue('기본 기획', '제작 형태') ?? '—';
  String get primaryTrack => _fieldValue('기본 기획', '주 트랙') ?? '—';
  String get targetUser => _fieldValue('기본 기획', '대상 고객') ?? '—';
  String get purpose => _fieldValue('기본 기획', '사업 주제') ?? '—';
  String get monetization =>
      _fieldValue('제작·판매 계획', '수익화·판매') ??
      _fieldValue('제작·판매 계획', '판매·배포') ??
      '—';
  String get mainDeliverables =>
      deliverableItems.isEmpty ? '—' : deliverableItems.join(', ');
  String get transferReadyLabel => _fieldValue('작업지시·전달 상태', '상태') ?? '—';

  String? _fieldValue(String sectionTitle, String label) {
    for (final section in sections) {
      if (section.title != sectionTitle) continue;
      for (final field in section.fields) {
        if (field.label == label && !field.isEmpty) return field.value;
      }
    }
    return null;
  }

  /// 모든 섹션 필드 값 (중복 검사·테스트용).
  List<String> get allFieldValues =>
      sections.expand((s) => s.fields.map((f) => f.value.trim())).toList();

  factory PlanningSummary.fromWizard(
    PlanningWizardState state, {
    PlanningSentenceComposer composer = const PlanningSentenceComposer(),
    bool hasInstruction = false,
  }) {
    final input = composer.toBusinessPlanInput(state);
    final artifact = state.effectiveArtifactType ?? ArtifactType.undecided;
    final deliverables = _buildDeliverableItems(state, input, artifact);

    final sections = <PlanningSummarySection>[
      PlanningSummarySection(
        title: '기본 기획',
        fields: [
          PlanningSummaryField(label: '사업 주제', value: input.topic.trim()),
          PlanningSummaryField(
            label: '제작 형태',
            value: ArtifactType.labelKo(artifact),
          ),
          PlanningSummaryField(
            label: '주 트랙',
            value: ArtifactType.primaryTrack(artifact),
          ),
          PlanningSummaryField(
            label: '대상 고객',
            value: input.targetCustomer.trim(),
          ),
          PlanningSummaryField(
            label: '고객 문제',
            value: input.customerProblem.trim(),
          ),
          PlanningSummaryField(
            label: '원하는 결과',
            value: input.desiredOutcome.trim(),
          ),
        ],
      ),
      if (artifact == ArtifactType.ebook)
        PlanningSummarySection(
          title: '전자책 구성',
          fields: [
            _labeledAnswer(state, artifact, 'ebookKind', '전자책 종류'),
            _labeledAnswer(state, artifact, 'readerLevel', '독자 수준'),
            _labeledAnswer(state, artifact, 'pageVolume', '분량'),
            _labeledAnswer(state, artifact, 'outputFormat', '출력 형식'),
            _labeledAnswer(state, artifact, 'tone', '글 톤'),
            _labeledAnswer(state, artifact, 'needCover', '표지'),
            _labeledAnswer(state, artifact, 'needIllustrations', '삽화·도표'),
          ],
        ),
      PlanningSummarySection(
        title: '제작·판매 계획',
        fields: [
          _labeledAnswer(state, artifact, 'schedule', '일정'),
          PlanningSummaryField(
            label: '예산',
            value: input.budgetEstimate.trim().isNotEmpty
                ? input.budgetEstimate.trim()
                : _answerText(state, artifact, 'budget'),
          ),
          _labeledAnswer(state, artifact, 'salesDeploy', '판매·배포'),
          _labeledAnswer(state, artifact, 'salesMode', '판매 방식'),
          _labeledAnswer(state, artifact, 'salesChannel', '판매 채널'),
          _labeledAnswer(state, artifact, 'followPromo', '후속 홍보'),
          PlanningSummaryField(
            label: '수익화·판매',
            value: _monetizationText(state, input, artifact),
          ),
        ],
      ),
      PlanningSummarySection(
        title: '주요 결과물',
        fields: [
          PlanningSummaryField(label: '산출물', value: deliverables.join(', ')),
        ],
      ),
      PlanningSummarySection(
        title: '작업지시·전달 상태',
        fields: [
          PlanningSummaryField(
            label: '상태',
            value: hasInstruction
                ? '작업지시서 생성됨 — 소통24워크 전달 가능'
                : '작업지시서 미생성 — 전달 준비 전',
          ),
        ],
      ),
    ];

    return PlanningSummary(sections: sections, deliverableItems: deliverables);
  }

  static PlanningSummaryField _labeledAnswer(
    PlanningWizardState state,
    String artifact,
    String questionId,
    String label,
  ) {
    return PlanningSummaryField(
      label: label,
      value: _answerText(state, artifact, questionId),
    );
  }

  static String _answerText(
    PlanningWizardState state,
    String artifact,
    String questionId,
  ) {
    final labels = _answerLabels(state, artifact, questionId);
    if (labels.isEmpty) return '—';
    return labels.join(', ');
  }

  static String _monetizationText(
    PlanningWizardState state,
    BusinessPlanInput input,
    String artifact,
  ) {
    if (input.revenueModel.trim().isNotEmpty) {
      return input.revenueModel.trim();
    }
    for (final qId in const ['salesDeploy', 'salesMode', 'monetization']) {
      final labels = _answerLabels(state, artifact, qId);
      if (labels.isNotEmpty) return labels.join(', ');
    }
    return '—';
  }

  static List<String> _buildDeliverableItems(
    PlanningWizardState state,
    BusinessPlanInput input,
    String artifact,
  ) {
    final items = <String>[];
    final outcome = input.desiredOutcome.toLowerCase();

    if (artifact == ArtifactType.ebook) {
      if (!_outcomeMentionsManuscript(outcome)) {
        items.add('전자책 원고');
      }

      final formats = _answerLabels(state, artifact, 'outputFormat');
      final formatIds = state.artifactAnswers['outputFormat'] ?? const [];
      if (formatIds.contains('pdf') ||
          formatIds.contains('both') ||
          formats.any((l) => l.contains('PDF'))) {
        if (!items.contains('PDF')) items.add('PDF');
      }
      if (formatIds.contains('epub') ||
          formatIds.contains('both') ||
          formats.any((l) => l.contains('EPUB'))) {
        if (!items.contains('EPUB')) items.add('EPUB');
      }
      if (formats.isEmpty && items.length == 1) {
        items.addAll(['PDF', 'EPUB']);
      }

      if (outcome.contains('체크리스트') ||
          outcome.contains('checklist') ||
          _answerLabels(
            state,
            artifact,
            'deliverables',
          ).any((l) => l.contains('체크'))) {
        if (!items.contains('실천 체크리스트')) {
          items.add('실천 체크리스트');
        }
      }
      if (outcome.contains('90일') ||
          outcome.contains('실행계획') ||
          outcome.contains('실행 계획')) {
        if (!items.contains('90일 실행계획')) {
          items.add('90일 실행계획');
        }
      }

      if (items.length <= 2 &&
          (outcome.contains('실천') || outcome.contains('실행'))) {
        if (!items.contains('실천 체크리스트')) {
          items.add('실천 체크리스트');
        }
        if (!items.contains('90일 실행계획')) {
          items.add('90일 실행계획');
        }
      }
    } else if (artifact != ArtifactType.undecided) {
      for (final qId in const ['deliverables', 'outputFormat', 'formats']) {
        items.addAll(_answerLabels(state, artifact, qId));
      }
      if (input.desiredOutcome.trim().isNotEmpty &&
          !items.contains(input.desiredOutcome.trim())) {
        items.add(input.desiredOutcome.trim());
      }
    }

    if (items.isEmpty && input.desiredOutcome.trim().isNotEmpty) {
      items.add(input.desiredOutcome.trim());
    }

    return items.toSet().toList();
  }

  static bool _outcomeMentionsManuscript(String outcomeLower) {
    return outcomeLower.contains('원고') ||
        outcomeLower.contains('전자책') && outcomeLower.contains('완성');
  }

  static List<String> _answerLabels(
    PlanningWizardState state,
    String artifact,
    String questionId,
  ) {
    if (artifact == ArtifactType.undecided) return const [];

    final ids = state.artifactAnswers[questionId];
    if (ids == null || ids.isEmpty) return const [];

    final questions = questionsFor(
      artifact: artifact,
      contentSubtype: state.contentSubtype,
    );
    final question = questions.where((q) => q.id == questionId).firstOrNull;
    if (question == null) return const [];

    return ids
        .map((id) {
          if (id == 'custom') {
            return state.customTexts[questionId]?.trim() ?? '직접 입력';
          }
          return question.options.where((o) => o.id == id).firstOrNull?.label ??
              id;
        })
        .where((l) => l.isNotEmpty && l != '아직 모름' && l != '아직 결정하지 않음')
        .toList();
  }
}

extension _FirstOrNullSummary<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
