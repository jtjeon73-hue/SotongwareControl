import '../models/business_planning.dart';
import 'work_instruction_workshop_presentation.dart';

class InstructionDocumentField {
  const InstructionDocumentField({required this.label, required this.value});

  final String label;
  final String value;
}

class InstructionDocumentSection {
  const InstructionDocumentSection({required this.title, required this.fields});

  final String title;
  final List<InstructionDocumentField> fields;
}

/// 작업지시 내용 보기 — 실제 schema 필드만, 빈 값은 생략.
class WorkInstructionDocumentPresentation {
  WorkInstructionDocumentPresentation._();

  static const specLabels = <String, String>{
    'pages': '분량/규모',
    'format': '파일 형식',
    'tone': '스타일',
    'level': '난이도',
    'pricing': '가격 정책',
    'platform': '플랫폼',
    'monetization': '수익 모델',
    'language': '제작 언어',
    'locale': '로컬라이징',
    'channel': '채널',
  };

  static List<InstructionDocumentSection> sections(WorkInstruction wi) {
    final c = wi.contract;
    final basics = <InstructionDocumentField>[
      _field('사업유형', _artifactLabel(wi)),
      _field('작업 제목', _title(wi)),
    ].where(_hasValue).toList();

    final audience = <InstructionDocumentField>[
      _field(
        '대상 고객',
        WorkInstructionWorkshopPresentation.humanizeAudienceOrField(
          wi.targetCustomer,
        ),
      ),
      _field('해결하려는 문제', wi.customerProblem),
    ].where(_hasValue).toList();

    final core = _coreContent(wi);
    final value = wi.valueProposition.trim();
    final goals = <InstructionDocumentField>[
      _field('제작 목적', wi.businessPurpose),
      _field('핵심 내용', core),
      if (core.isNotEmpty && value.isNotEmpty && core != value)
        _field('핵심 가치', value),
    ].where(_hasValue).toList();

    final conditions = <InstructionDocumentField>[
      if (c != null)
        for (final e in c.productionSpec.spec.entries)
          _field(_specLabel(e.key), _specValue('${e.value}')),
      _field('품질 기준', _quality(wi)),
      _field('승인 방식', wi.approvalItems.join(' · ')),
      _field('특별 요구사항', _special(wi)),
    ].where(_hasValue).toList();

    return [
      if (basics.isNotEmpty)
        InstructionDocumentSection(title: '기본', fields: basics),
      if (audience.isNotEmpty)
        InstructionDocumentSection(title: '대상과 문제', fields: audience),
      if (goals.isNotEmpty)
        InstructionDocumentSection(title: '제작 목표', fields: goals),
      if (conditions.isNotEmpty)
        InstructionDocumentSection(title: '제작 조건', fields: conditions),
    ];
  }

  static String copyText(WorkInstruction wi) {
    final buf = StringBuffer()..writeln('작업지시 내용');
    for (final section in sections(wi)) {
      buf.writeln();
      buf.writeln('[${section.title}]');
      for (final field in section.fields) {
        buf.writeln(field.label);
        buf.writeln(field.value);
        buf.writeln();
      }
    }
    return buf.toString().trim();
  }

  static bool _hasValue(InstructionDocumentField f) =>
      f.value.trim().isNotEmpty;

  static InstructionDocumentField _field(String label, String value) =>
      InstructionDocumentField(label: label, value: value.trim());

  static String _title(WorkInstruction wi) {
    final contractTitle =
        wi.contract?.projectDefinition.title.value.trim() ?? '';
    if (contractTitle.isNotEmpty) return contractTitle;
    return wi.businessIdea.trim();
  }

  static String _artifactLabel(WorkInstruction wi) {
    final a = ArtifactType.labelKo(wi.artifactType);
    if (wi.contentSubtype.trim().isEmpty) return a;
    return '$a · ${ContentSubtype.labelKo(wi.contentSubtype)}';
  }

  static String _coreContent(WorkInstruction wi) {
    final topics = wi.contract?.projectDefinition.selectedTopics ?? const [];
    if (topics.isNotEmpty) {
      return topics
          .map(WorkInstructionWorkshopPresentation.humanizeAudienceOrField)
          .where((e) => e.trim().isNotEmpty)
          .join('\n');
    }
    return wi.valueProposition.trim();
  }

  static String _quality(WorkInstruction wi) {
    final criteria = wi.contract?.qualityCriteria ?? const [];
    if (criteria.isNotEmpty) {
      return criteria
          .map((q) => q.label.trim().isEmpty ? q.description : q.label)
          .where((e) => e.trim().isNotEmpty)
          .join('\n');
    }
    return wi.qualityChecks.where((e) => e.trim().isNotEmpty).join('\n');
  }

  static String _special(WorkInstruction wi) {
    final memo = wi.contract?.projectDefinition.userMemo.trim() ?? '';
    final notes = wi.notes.trim();
    if (memo.isNotEmpty && notes.isNotEmpty && memo != notes) {
      return '$memo\n$notes';
    }
    if (memo.isNotEmpty) return memo;
    return notes;
  }

  static String _specLabel(String key) => specLabels[key] ?? key;

  static String _specValue(String raw) {
    final token = raw.trim();
    if (token.isEmpty) return '';
    return WorkInstructionWorkshopPresentation.humanizeAudienceOrField(token);
  }
}
