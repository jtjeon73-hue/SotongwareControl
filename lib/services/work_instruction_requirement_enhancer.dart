import '../models/artifact_type.dart';
import '../models/project_design_state.dart';

/// 사용자 입력을 구조화·보완하는 규칙 기반 제안(원격 LLM 없이 로컬 생성).
class WorkInstructionRequirementEnhancer {
  WorkInstructionRequirementEnhancer._();

  static RequirementEnhancementResult enhance(ProjectDesignState state) {
    final artifact = ArtifactType.normalize(state.artifactType ?? '');
    final topic = state.topic.trim();
    final problem = state.customerProblem.trim();
    final audience = _audienceText(state);
    final outcome = state.desiredOutcome.trim();
    final memo = state.designMemo.trim();

    final sections = <RequirementEnhancementSection>[];
    sections.add(
      RequirementEnhancementSection(
        title: '프로젝트 개요',
        bullets: [
          '프로젝트명: ${topic.isEmpty ? "(입력 필요)" : topic}',
          '제작 유형: ${ArtifactType.labelKo(artifact)}',
          if (artifact == ArtifactType.contents &&
              (state.contentSubtype ?? '').isNotEmpty)
            '콘텐츠 하위유형: ${ContentSubtype.labelKo(state.contentSubtype!)}',
          '목표: ${outcome.isEmpty ? "상용 배포·판매 가능한 품질의 결과물" : outcome}',
        ],
      ),
    );

    sections.add(
      RequirementEnhancementSection(
        title: '대상 사용자',
        bullets: [
          if (audience.isNotEmpty) audience else '대상 사용자를 구체화하세요.',
          '사용 맥락·숙련도·접근 환경을 명시하면 제작 품질이 올라갑니다.',
        ],
      ),
    );

    sections.addAll(_artifactSections(artifact, state, problem, memo));

    sections.add(
      const RequirementEnhancementSection(
        title: '상용 품질 기준',
        bullets: [
          '단순 MVP가 아닌 실제 배포·판매 가능한 완성도를 목표로 합니다.',
          '로딩·빈 상태·오류 상태·접근성·모바일 대응을 포함합니다.',
          'placeholder/debug/TODO UI 없이 최종 소비 가능한 결과물을 요구합니다.',
        ],
      ),
    );

    final suggestedNotes = _buildSuggestedNotes(sections);
    return RequirementEnhancementResult(
      sections: sections,
      suggestedNotes: suggestedNotes,
      suggestedProblem: problem.isEmpty
          ? _defaultProblem(artifact, topic)
          : problem,
      suggestedOutcome: outcome.isEmpty ? _defaultOutcome(artifact) : outcome,
    );
  }

  static List<RequirementEnhancementSection> _artifactSections(
    String artifact,
    ProjectDesignState state,
    String problem,
    String memo,
  ) {
    switch (artifact) {
      case ArtifactType.app:
        return [
          RequirementEnhancementSection(
            title: '앱 핵심 시나리오',
            bullets: [
              if (problem.isNotEmpty) problem else '핵심 사용 시나리오를 정의하세요.',
              '오프라인/온라인 필요 여부, 데이터 저장, 알림, 로그인 요구를 명시합니다.',
              'Android 우선 Flutter 릴리스 APK를 기본 산출물로 합니다.',
            ],
          ),
          RequirementEnhancementSection(
            title: '기능·품질',
            bullets: [
              '필수 기능 / 제외 기능 / 성공 기준을 분리합니다.',
              '오류 처리·빈 상태·권한·보안 기본 검토를 포함합니다.',
              if (memo.isNotEmpty) '추가 메모: $memo',
            ],
          ),
        ];
      case ArtifactType.site:
      case ArtifactType.promoSite:
        return [
          RequirementEnhancementSection(
            title: '사이트 목적·구조',
            bullets: [
              if (problem.isNotEmpty) problem else '사이트 목적과 주요 방문자를 정의하세요.',
              '주요 메뉴·핵심 CTA·회원/결제/검색/SEO 필요 여부를 명시합니다.',
              '반응형·관리자 기능·배포 환경을 포함합니다.',
            ],
          ),
        ];
      case ArtifactType.contents:
        return [
          RequirementEnhancementSection(
            title: '콘텐츠 제작 계약',
            bullets: [
              if (problem.isNotEmpty) problem else '콘텐츠 주제와 전달 목적을 정의하세요.',
              _contentSubtypeHint(state.contentSubtype),
              '최종 소비 가능한 품질(음질·영상·자막·표지 등)을 명시합니다.',
            ],
          ),
        ];
      case ArtifactType.ebook:
      default:
        return [
          RequirementEnhancementSection(
            title: '전자책 구성',
            bullets: [
              if (problem.isNotEmpty) problem else '독자 문제와 해결 방법을 정의하세요.',
              '목표 분량·문체·난이도·판매/무료·가격·표지·PDF/ePub 형식을 명시합니다.',
              if (memo.isNotEmpty) '추가 메모: $memo',
            ],
          ),
        ];
    }
  }

  static String _contentSubtypeHint(String? subtype) {
    final id = ContentSubtype.normalize(subtype ?? '');
    return switch (id) {
      ContentSubtype.shorts => '쇼츠: 세로 9:16, 15~60초, 훅·자막·CTA 포함.',
      ContentSubtype.song => '노래: 가사·멜로디 방향·길이·배포 채널 명시.',
      ContentSubtype.video => '영상: 길이·구성·자막·썸네일·업로드 채널 명시.',
      ContentSubtype.songAndShorts => '노래+쇼츠: 음원과 숏폼 홍보 세트로 기획.',
      _ => '콘텐츠 하위유형별 산출물 형식을 선택하세요.',
    };
  }

  static String _audienceText(ProjectDesignState state) {
    if (state.customAudience.trim().isNotEmpty) {
      return state.customAudience.trim();
    }
    if (state.selectedAudiences.isEmpty) return '';
    return state.selectedAudiences.join(', ');
  }

  static String _defaultProblem(String artifact, String topic) {
    final name = topic.isEmpty ? '이 프로젝트' : topic;
    return switch (artifact) {
      ArtifactType.app => '$name이 해결할 현장/사용자 문제를 정의합니다.',
      ArtifactType.site ||
      ArtifactType.promoSite => '$name 방문자의 핵심 니즈와 전환 목표를 정의합니다.',
      ArtifactType.contents => '$name 콘텐츠가 전달할 메시지와 반응 목표를 정의합니다.',
      _ => '$name 독자가 겪는 문제와 학습 목표를 정의합니다.',
    };
  }

  static String _defaultOutcome(String artifact) {
    return switch (artifact) {
      ArtifactType.app => 'Android 릴리스 APK와 상용 품질 앱을 배포 가능한 상태로 완성',
      ArtifactType.site || ArtifactType.promoSite => '반응형 웹사이트를 배포 가능한 상태로 완성',
      ArtifactType.contents => '최종 소비 가능한 콘텐츠 패키지 완성',
      _ => '판매·배포 가능한 전자책(PDF 등) 완성',
    };
  }

  static String _buildSuggestedNotes(
    List<RequirementEnhancementSection> sections,
  ) {
    final buf = StringBuffer('[AI 요구사항 보완]\n');
    for (final section in sections) {
      buf.writeln('## ${section.title}');
      for (final bullet in section.bullets) {
        buf.writeln('- $bullet');
      }
      buf.writeln();
    }
    return buf.toString().trim();
  }
}

class RequirementEnhancementSection {
  const RequirementEnhancementSection({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}

class RequirementEnhancementResult {
  const RequirementEnhancementResult({
    required this.sections,
    required this.suggestedNotes,
    required this.suggestedProblem,
    required this.suggestedOutcome,
  });

  final List<RequirementEnhancementSection> sections;
  final String suggestedNotes;
  final String suggestedProblem;
  final String suggestedOutcome;
}
