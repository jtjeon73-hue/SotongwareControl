import '../models/business_planning.dart';

/// 로컬 규칙 기반 사업 기획 분석. 외부 AI API를 사용하지 않는다.
class BusinessPlanningService {
  BusinessPlanningService();

  static const standardWorkflowTitles = <(String, String)>[
    ('idea_clarify', '아이디어 정리'),
    ('problem_validate', '고객 문제 검증'),
    ('materials_prep', '자료 준비'),
    ('planning', '기획'),
    ('project_setup', '프로젝트 생성 또는 불러오기'),
    ('prompt_generate', 'AI/Cursor 작업 프롬프트 생성'),
    ('draft', '초안 제작'),
    ('build_test', '실행 및 기능 검사'),
    ('user_review', '사용자 확인'),
    ('revise', '보완 수정'),
    ('quality', '품질 검사'),
    ('publish_prep', '등록 준비'),
    ('deploy', '배포'),
    ('promo', '홍보자료 제작'),
    ('launch', '공개 및 공유'),
    ('measure', '성과 확인'),
    ('iterate', '재보완'),
    ('maintain', '유지관리'),
  ];

  PlanningAnalysisResult analyze(BusinessPlanInput input) {
    final criteria = _scoreCriteria(input);
    final average =
        criteria.map((c) => c.score).reduce((a, b) => a + b) / criteria.length;
    final verdict = _verdict(average, criteria, input);
    final recommendations = recommendDeliverables(input, criteria);
    final summary = _summary(input, average, verdict, criteria);

    return PlanningAnalysisResult(
      criteria: criteria,
      verdict: verdict,
      summary: summary,
      recommendations: recommendations,
      averageScore: double.parse(average.toStringAsFixed(2)),
    );
  }

  List<DeliverableRecommendation> recommendDeliverables(
    BusinessPlanInput input,
    List<CriterionScore> criteria,
  ) {
    final problem = input.customerProblem.toLowerCase();
    final outcome = input.desiredOutcome.toLowerCase();
    final topic = input.topic.toLowerCase();
    final skills = input.experienceSkills.toLowerCase();
    final text = '$topic $problem $outcome $skills ${input.notes}';

    final scores = <String, int>{
      DeliverableType.ebook: 10,
      DeliverableType.youtubeShorts: 10,
      DeliverableType.webMarketing: 10,
      DeliverableType.app: 8,
      DeliverableType.contentMusic: 6,
    };

    void bump(String type, int delta) {
      scores[type] = (scores[type] ?? 0) + delta;
    }

    if (_containsAny(text, ['방법', '가이드', '노하우', '체크리스트', '정리', '공부'])) {
      bump(DeliverableType.ebook, 8);
      bump(DeliverableType.youtubeShorts, 4);
    }
    if (_containsAny(text, ['홍보', '문의', '랜딩', '사이트', '고객 확보', '소개'])) {
      bump(DeliverableType.webMarketing, 9);
    }
    if (_containsAny(text, ['앱', '알림', '기록', '관리', '모바일', '반복 사용'])) {
      bump(DeliverableType.app, 10);
    }
    if (_containsAny(text, ['쇼츠', '유튜브', '영상', '짧게', '바이럴', '콘텐츠'])) {
      bump(DeliverableType.youtubeShorts, 9);
      bump(DeliverableType.contentMusic, 3);
    }
    if (_containsAny(text, ['노래', '음악', '음원', '브금'])) {
      bump(DeliverableType.contentMusic, 12);
    }
    if (_containsAny(skills, ['산업', '자동화', 'plc', '현장', '개발', 'flutter'])) {
      bump(DeliverableType.app, 3);
      bump(DeliverableType.ebook, 2);
    }
    if (input.existingMaterials.trim().isNotEmpty) {
      bump(DeliverableType.ebook, 3);
      bump(DeliverableType.youtubeShorts, 2);
    }
    // 정보 신뢰성이 약하면 전자책 단독 확정을 피한다.
    final clarity = criteria.firstWhere((c) => c.id == 'problem_clarity').score;
    final pay = criteria.firstWhere((c) => c.id == 'paid_willingness').score;
    if (clarity < 3 || pay < 3) {
      bump(DeliverableType.youtubeShorts, 4);
      bump(DeliverableType.webMarketing, 2);
      bump(DeliverableType.ebook, -3);
    }

    final selected = input.deliverableTypes
        .where((t) => t != DeliverableType.undecided)
        .toSet();
    if (selected.isNotEmpty) {
      for (final type in selected) {
        bump(type, 6);
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var i = 0; i < ranked.length; i++)
        _recommendationFor(ranked[i].key, i + 1, input),
    ];
  }

  WorkInstruction buildInstruction({
    required String planId,
    required BusinessPlanInput input,
    required PlanningAnalysisResult analysis,
    DateTime? now,
  }) {
    final stamp = (now ?? DateTime.now()).toUtc();
    final iso = stamp.toIso8601String();
    final types = analysis.recommendations.take(3).map((r) => r.type).toList();
    final primary = types.isEmpty ? DeliverableType.ebook : types.first;
    final steps = _workflowFor(primary);

    return WorkInstruction(
      schemaVersion: '1.0',
      instructionId: 'wi_${planId}_${stamp.millisecondsSinceEpoch}',
      projectId: planId,
      instructionVersion: '1',
      createdAt: iso,
      updatedAt: iso,
      businessIdea: input.topic.trim(),
      businessPurpose: input.desiredOutcome.trim(),
      customerProblem: input.customerProblem.trim(),
      targetCustomer: input.targetCustomer.trim(),
      deliverableTypes: types,
      recommendedSequence: types,
      valueProposition:
          '${input.targetCustomer.trim()}의 ${input.customerProblem.trim()}을(를) '
          '줄이기 위해 ${DeliverableType.labelKo(primary)}부터 검증한다.',
      requiredMaterials: [
        if (input.existingMaterials.trim().isNotEmpty)
          input.existingMaterials.trim()
        else
          '고객 문제·대상·결과물 설명을 문장으로 정리한 기획 메모',
        '사례·근거 자료(실제 경험·출처·수치) 목록',
        '수익 방식 후보와 가격 가설',
      ],
      workflowSteps: steps,
      completionCriteria: [
        '고객 문제·대상·결과물이 한 페이지로 설명 가능',
        '최소 결과물 1개가 초안 수준으로 존재',
        '사용자 확인 항목이 체크리스트로 남아 있음',
      ],
      qualityChecks: [
        '사실·경험·출처를 과장하지 않았는가',
        '성공·매출 보장 표현이 없는가',
        '모바일에서 읽기·문의·다운로드 경로가 끊기지 않는가',
      ],
      risks: analysis.criteria
          .where((c) => c.score <= 2)
          .map((c) => '${c.label}: ${c.risks}')
          .toList(),
      monetizationOptions: [
        if (input.revenueModel.trim().isNotEmpty) input.revenueModel.trim(),
        '단품 판매',
        '문의·맞춤 의뢰 연계',
        '시리즈·구독 검토(검증 후)',
      ],
      deploymentTargets: [
        if (types.contains(DeliverableType.app)) '앱 스토어 또는 내부 배포 채널',
        if (types.contains(DeliverableType.ebook)) '전자책 판매 채널',
        if (types.contains(DeliverableType.webMarketing))
          'Firebase Hosting 웹사이트',
        if (types.contains(DeliverableType.youtubeShorts)) '유튜브',
        '소통사이트매니저 등록 검토',
      ],
      promotionChannels: ['웹마케팅 사이트 CTA', '쇼츠·콘텐츠 유입', '기존 고객·현장 네트워크'],
      approvalItems: [
        '최종 가격·판매 채널',
        '공개 문구·과장 표현 검토',
        '저작권·출처·개인정보 확인',
        '소통24워크 실행 전 사용자 승인',
      ],
      executionStatus: '지시서 준비',
      notes: input.notes.trim(),
    );
  }

  String buildReadableInstruction(WorkInstruction instruction) {
    final buffer = StringBuffer()
      ..writeln('【소통24워크 표준 작업지시서】')
      ..writeln('schemaVersion: ${instruction.schemaVersion}')
      ..writeln('지시서 ID: ${instruction.instructionId}')
      ..writeln('프로젝트 ID: ${instruction.projectId}')
      ..writeln('실행 상태: ${instruction.executionStatus}')
      ..writeln('생성: ${instruction.createdAt}')
      ..writeln()
      ..writeln('■ 사업 주제')
      ..writeln(instruction.businessIdea)
      ..writeln()
      ..writeln('■ 고객 문제')
      ..writeln(instruction.customerProblem)
      ..writeln()
      ..writeln('■ 대상 고객')
      ..writeln(instruction.targetCustomer)
      ..writeln()
      ..writeln('■ 핵심 가치 제안')
      ..writeln(instruction.valueProposition)
      ..writeln()
      ..writeln('■ 추천 제작 순서')
      ..writeln(
        instruction.recommendedSequence
            .map(DeliverableType.labelKo)
            .join(' → '),
      )
      ..writeln()
      ..writeln('■ 작업 단계');
    for (final step in instruction.workflowSteps) {
      buffer.writeln(
        '${step.order}. ${step.title} '
        '(${step.applicable ? '적용' : '해당 없음'}) — ${step.completionCriteria}',
      );
    }
    buffer
      ..writeln()
      ..writeln('■ 품질 검사')
      ..writeln(instruction.qualityChecks.map((e) => '- $e').join('\n'))
      ..writeln()
      ..writeln('■ 사용자 승인 필요')
      ..writeln(instruction.approvalItems.map((e) => '- $e').join('\n'))
      ..writeln()
      ..writeln(
        '※ 본 지시서는 로컬 규칙 기반 기획 도우미가 생성했습니다. '
        '외부 AI가 내용을 만들어 낸 것이 아니며, 소통24워크 자동 실행은 포함하지 않습니다.',
      );
    return buffer.toString();
  }

  String buildCursorPrompt({
    required BusinessPlanInput input,
    required WorkInstruction instruction,
  }) {
    return '''
당신은 소통웨어 실행 보조다. 아래 작업지시서를 바탕으로 초안 제작만 돕는다.
매출·성공을 보장하는 문장을 쓰지 말고, 사실과 검증 가능한 단계만 제안한다.

주제: ${input.topic}
고객 문제: ${input.customerProblem}
대상 고객: ${input.targetCustomer}
원하는 결과: ${input.desiredOutcome}
제작 순서: ${instruction.recommendedSequence.map(DeliverableType.labelKo).join(' → ')}

다음을 출력하라:
1) 최소 결과물 정의
2) 필요한 자료 체크리스트
3) 첫 번째 적용 단계의 구체 작업 목록
4) 품질 검사 항목
5) 사용자가 승인해야 할 항목

지시서 ID: ${instruction.instructionId}
실행 상태: ${instruction.executionStatus} (자동 실행 금지)
''';
  }

  List<CriterionScore> _scoreCriteria(BusinessPlanInput input) {
    int lengthScore(String text, {int good = 40, int fair = 18}) {
      final n = text.trim().length;
      if (n >= good) return 4;
      if (n >= fair) return 3;
      if (n >= 8) return 2;
      return 1;
    }

    CriterionScore build({
      required String id,
      required String label,
      required int score,
      required String rationale,
      required String missing,
      required String risks,
      required String improvement,
    }) {
      return CriterionScore(
        id: id,
        label: label,
        score: score.clamp(1, 5),
        rationale: rationale,
        missingInfo: missing,
        risks: risks,
        improvement: improvement,
      );
    }

    final problemScore = lengthScore(input.customerProblem);
    final customerScore = lengthScore(input.targetCustomer, good: 30, fair: 12);
    final outcomeScore = lengthScore(input.desiredOutcome);
    final skillScore = input.experienceSkills.trim().isEmpty
        ? 2
        : lengthScore(input.experienceSkills, good: 30, fair: 10);
    final paidHints = _containsAny(input.desiredOutcome + input.revenueModel, [
      '판매',
      '유료',
      '결제',
      '구독',
      '문의',
      '견적',
      '광고',
    ]);
    final paidScore = paidHints
        ? (input.revenueModel.trim().isEmpty ? 3 : 4)
        : (input.revenueModel.trim().isEmpty ? 2 : 3);
    final repeatScore =
        _containsAny(input.desiredOutcome + input.topic, [
          '반복',
          '시리즈',
          '템플릿',
          '구독',
          '재사용',
          '표준',
        ])
        ? 4
        : 2;
    final autoScore =
        _containsAny(input.experienceSkills + input.desiredOutcome, [
          '자동',
          '템플릿',
          '표준',
          '시스템',
          'AI',
        ])
        ? 4
        : 2;
    final costScore = input.expectedDuration.trim().isEmpty ? 2 : 3;
    final maintainScore = input.deliverableTypes.contains(DeliverableType.app)
        ? 2
        : 3;
    final linkScore =
        _containsAny(input.experienceSkills + input.notes, [
          '산업',
          '앱',
          '전자책',
          '콘텐츠',
          '마케팅',
          '사이트',
          '자동화',
        ])
        ? 4
        : 2;
    final diffScore = input.experienceSkills.trim().length > 20 ? 3 : 2;
    final difficultyScore = input.deliverableTypes.contains(DeliverableType.app)
        ? 2
        : 3;

    return [
      build(
        id: 'problem_clarity',
        label: '고객 문제의 명확성',
        score: problemScore,
        rationale: problemScore >= 3
            ? '불편·손실이 문장으로 드러난다.'
            : '문제가 추상적이거나 너무 짧다.',
        missing: problemScore < 4 ? '누가 언제 어떤 손해를 보는지 구체 사례' : '추가 정보 없음',
        risks: '문제가 흐리면 제작물이 기능 나열이 된다.',
        improvement: '최근 실제 사례 1건을 숫자·상황과 함께 적는다.',
      ),
      build(
        id: 'customer_specificity',
        label: '대상 고객의 구체성',
        score: customerScore,
        rationale: customerScore >= 3 ? '대상이 어느 정도 구분된다.' : '대상이 “모두”에 가깝다.',
        missing: customerScore < 4 ? '직업·지역·상황 조건' : '추가 정보 없음',
        risks: '대상이 넓으면 메시지와 가격이 흔들린다.',
        improvement: '첫 고객 10명을 상상해 공통점을 적는다.',
      ),
      build(
        id: 'paid_willingness',
        label: '유료 구매 가능성',
        score: paidScore,
        rationale: paidHints ? '유료·문의 관련 단서가 있다. 확정은 아니다.' : '유료 전환 단서가 부족하다.',
        missing: '실제 지불 의사 확인(대화·사전예약·유사 상품)',
        risks: '관심과 지불을 동일시하면 재고·시간만 소비한다.',
        improvement: '유료로 살 이유를 한 문장으로 쓰고 2명에게 확인해 본다.',
      ),
      build(
        id: 'differentiation',
        label: '차별화 가능성',
        score: diffScore,
        rationale: diffScore >= 3 ? '보유 경험 단서가 있어 차별화 여지가 있다.' : '차별화 근거가 약하다.',
        missing: '경쟁 대비 “나만이 줄일 수 있는 손해”',
        risks: '일반론 콘텐츠는 가격 경쟁에 끌려간다.',
        improvement: '현장·앱·콘텐츠 중 실제 경험 증거를 하나 붙인다.',
      ),
      build(
        id: 'skill_fit',
        label: '보유 기술 활용도',
        score: skillScore,
        rationale: skillScore >= 3
            ? '기술·경험 입력이 있어 연계 가능하다.'
            : '기술 입력이 비어 평가가 보수적이다.',
        missing: skillScore < 3 ? '보유 기술·도구·현장 경험' : '추가 정보 없음',
        risks: '익숙하지 않은 영역부터 시작하면 제작비가 커진다.',
        improvement: '이미 할 수 있는 일과 배워야 할 일을 나눈다.',
      ),
      build(
        id: 'build_difficulty',
        label: '제작 난이도',
        score: difficultyScore,
        rationale: difficultyScore >= 3
            ? '비교적 가벼운 형태부터 시작할 여지가 있다.'
            : '앱 등 난이도 높은 형태가 포함되어 있다.',
        missing: '첫 버전에 넣을 기능/분량의 상한',
        risks: '처음부터 완성품을 노리면 중단 위험이 커진다.',
        improvement: '2주 안에 만들 최소 결과물만 남긴다.',
      ),
      build(
        id: 'repeat_sales',
        label: '반복 판매 가능성',
        score: repeatScore,
        rationale: repeatScore >= 3 ? '시리즈·재사용 단서가 있다.' : '단발 판매 가능성이 높다.',
        missing: '재구매·시리즈 확장 가설',
        risks: '단발이면 마케팅 비용 대비 회수가 어렵다.',
        improvement: '같은 문제를 단계별로 나눈 시리즈 구조를 스케치한다.',
      ),
      build(
        id: 'automation',
        label: '자동화 가능성',
        score: autoScore,
        rationale: autoScore >= 3 ? '표준화·자동화 키워드가 있다.' : '수작업 비중이 클 수 있다.',
        missing: '반복 가능한 체크리스트·템플릿',
        risks: '모든 주문을 맞춤으로 받으면 확장되지 않는다.',
        improvement: '공통 70%를 템플릿으로 고정한다.',
      ),
      build(
        id: 'initial_cost',
        label: '초기 비용 부담',
        score: costScore,
        rationale: costScore >= 3 ? '기간 입력이 있어 일정 가설이 있다.' : '기간·비용 정보가 부족하다.',
        missing: '유료 도구·광고·외주 예상 비용',
        risks: '고정비를 먼저 올리면 검증 전에 현금이 샌다.',
        improvement: '유료 지출 없이 검증할 최소 경로를 정한다.',
      ),
      build(
        id: 'maintenance',
        label: '유지관리 부담',
        score: maintainScore,
        rationale: maintainScore >= 3
            ? '상대적으로 유지관리가 가벼운 형태다.'
            : '앱·지속 운영 부담이 클 수 있다.',
        missing: '업데이트 주기와 담당',
        risks: '출시 후 방치되면 신뢰가 떨어진다.',
        improvement: '월 1회 점검 항목을 미리 적는다.',
      ),
      build(
        id: 'scalability',
        label: '확장 가능성',
        score: outcomeScore >= 3 ? 3 : 2,
        rationale: '결과물 설명이 구체할수록 확장 설계가 쉽다.',
        missing: '1차 결과물 이후 2차 상품',
        risks: '확장을 먼저 그리면 1차가 끝나지 않는다.',
        improvement: '1차 검증 기준을 숫자로 정한다.',
      ),
      build(
        id: 'sotongware_link',
        label: '소통웨어 기존 사업과의 연계성',
        score: linkScore,
        rationale: linkScore >= 3
            ? '기존 사업 키워드와 연결 단서가 있다.'
            : '기존 사업 연계가 명확하지 않다.',
        missing: '어느 사업부 자산·고객을 재사용할지',
        risks: '신규만 추가하면 선택과 집중이 깨진다.',
        improvement: '기존 6개 사업부 중 연결 1곳을 지정한다.',
      ),
    ];
  }

  String _verdict(
    double average,
    List<CriterionScore> criteria,
    BusinessPlanInput input,
  ) {
    final lowCount = criteria.where((c) => c.score <= 2).length;
    if (!input.hasRequiredFields || average < 2.2 || lowCount >= 5) {
      return PlanningVerdict.hold;
    }
    if (average < 2.8 || lowCount >= 3) {
      return PlanningVerdict.needsRefine;
    }
    if (average < 3.5 ||
        criteria.any((c) => c.id == 'paid_willingness' && c.score <= 2)) {
      return PlanningVerdict.validateFirst;
    }
    return PlanningVerdict.readyToBuild;
  }

  String _summary(
    BusinessPlanInput input,
    double average,
    String verdict,
    List<CriterionScore> criteria,
  ) {
    final lows = criteria
        .where((c) => c.score <= 2)
        .map((c) => c.label)
        .toList();
    return '로컬 규칙 기반 평가(외부 AI 생성 아님). 평균 ${average.toStringAsFixed(1)}/5, '
        '판단: ${PlanningVerdict.labelKo(verdict)}. '
        '${lows.isEmpty ? '치명적으로 낮은 항목은 없다.' : '보완 우선: ${lows.take(3).join(', ')}. '} '
        '성공·매출을 보장하지 않으며, 입력되지 않은 사실은 점수를 올리지 않았다.';
  }

  DeliverableRecommendation _recommendationFor(
    String type,
    int rank,
    BusinessPlanInput input,
  ) {
    switch (type) {
      case DeliverableType.app:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '반복 기록·알림·관리가 핵심이면 앱이 적합하다. 단, 초기 제작·유지 비용이 크다.',
          minimumOutput: '핵심 화면 3개와 저장 기능만 있는 최소 앱',
          requiredMaterials: '사용자 흐름, 데이터 항목, 테스트 계정',
          workSteps: '문제 정의 → 화면 스케치 → Flutter 초안 → 테스트 → 사용자 확인',
          nextExpansion: '웹 홍보 사이트와 쇼츠로 유입을 붙인다.',
          monetizationOptions: '앱 내 유료·광고·맞춤 구축 연계',
          risks: '기능 과다·스토어 심사·지속 업데이트 부담',
        );
      case DeliverableType.ebook:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '방법·체크리스트형 지식 전달에 적합하다. 근거와 경험이 있어야 신뢰가 생긴다.',
          minimumOutput: '목차+핵심 3장+실행 체크리스트 PDF 초안',
          requiredMaterials: '실제 사례, 출처, 금지 표현 목록',
          workSteps: '독자 문제 → 목차 → 초고 → 편집 → 판매 페이지',
          nextExpansion: '쇼츠로 핵심만 쪼개고, 웹사이트로 판매를 연결한다.',
          monetizationOptions: '단품 판매, 시리즈, 상담 연계',
          risks: '일반론·과장 시 환불·신뢰 하락',
        );
      case DeliverableType.youtubeShorts:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '관심 검증과 유입에 빠르다. 판매 확정이 아니라 수요 신호 확인에 쓴다.',
          minimumOutput: '60초 이내 문제-해결 힌트 영상 3편',
          requiredMaterials: '스크립트, 썸네일 문구, 출처',
          workSteps: '주제 분해 → 스크립트 → 촬영/생성 → 업로드 → 반응 확인',
          nextExpansion: '반응 좋은 주제를 전자책·사이트로 확장한다.',
          monetizationOptions: '유입 → 사이트 문의/전자책',
          risks: '조회와 매출을 동일시하는 착각',
        );
      case DeliverableType.contentMusic:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '브랜드·분위기 자산에 유리하다. 직접 매출보다 유입·차별화 보조에 가깝다.',
          minimumOutput: '테마곡 1곡+사용 장면 설명',
          requiredMaterials: '저작권 확인, 사용 범위',
          workSteps: '콘셉트 → 초안 → 검수 → 채널/사이트 배치',
          nextExpansion: '쇼츠·앱 오프닝과 결합한다.',
          monetizationOptions: '콘텐츠 유입, 제작 의뢰',
          risks: '저작권·취향 의존·단독 수익화 난이도',
        );
      case DeliverableType.webMarketing:
      default:
        return DeliverableRecommendation(
          type: type,
          rank: rank,
          reason: '신뢰·문의·판매 연결의 허브다. 다른 제작물의 착륙점으로 유용하다.',
          minimumOutput: '문제-해결-사례-CTA 1페이지',
          requiredMaterials: '연락 수단, 사례, 가격 가설',
          workSteps: '메시지 → 와이어 → Hosting 배포 → CTA 점검',
          nextExpansion: '전자책/앱 링크와 쇼츠를 연결한다.',
          monetizationOptions: '문의 전환, 상품 판매 페이지',
          risks: '예쁜 페이지만 있고 제안이 없으면 문의가 없다',
        );
    }
  }

  List<WorkflowStep> _workflowFor(String primary) {
    // 1순위 제작 형태를 기준으로 해당 없는 단계를 남긴다(삭제하지 않음).
    return [
      for (var i = 0; i < standardWorkflowTitles.length; i++)
        WorkflowStep(
          order: i + 1,
          id: standardWorkflowTitles[i].$1,
          title: standardWorkflowTitles[i].$2,
          applicable: _stepApplicable(
            standardWorkflowTitles[i].$1,
            primary: primary,
          ),
          completionCriteria: _stepCriteria(standardWorkflowTitles[i].$1),
          notes: _stepApplicable(standardWorkflowTitles[i].$1, primary: primary)
              ? ''
              : '해당 없음',
        ),
    ];
  }

  bool _stepApplicable(String id, {required String primary}) {
    // 작업지시서의 1순위 제작 형태 기준으로 단계 적용 여부를 결정한다.
    switch (id) {
      case 'build_test':
        return primary == DeliverableType.app;
      case 'deploy':
        return primary == DeliverableType.app ||
            primary == DeliverableType.webMarketing;
      case 'promo':
      case 'measure':
      case 'iterate':
      case 'maintain':
        return true;
      default:
        return true;
    }
  }

  String _stepCriteria(String id) {
    switch (id) {
      case 'idea_clarify':
        return '주제·문제·고객·결과가 한 페이지로 정리됨';
      case 'problem_validate':
        return '실제 대상 2명 이상에게 문제 공감 여부를 확인함';
      case 'materials_prep':
        return '필요 자료 목록과 확보 상태가 체크됨';
      case 'planning':
        return '최소 결과물과 비범위가 명시됨';
      case 'project_setup':
        return '저장소/프로젝트 폴더가 준비됨';
      case 'prompt_generate':
        return 'Cursor용 시작 프롬프트가 복사 가능함';
      case 'draft':
        return '초안 파일이 존재함';
      case 'build_test':
        return '핵심 기능 테스트 통과 또는 해당 없음';
      case 'user_review':
        return '사용자 확인 의견이 기록됨';
      case 'revise':
        return '피드백 반영 또는 보류 사유 기록';
      case 'quality':
        return '품질 체크리스트 통과';
      case 'publish_prep':
        return '등록 정보·가격·약관 초안 준비';
      case 'deploy':
        return '배포 URL/채널 기록 또는 해당 없음';
      case 'promo':
        return '홍보 문구·채널 초안 준비';
      case 'launch':
        return '공개 시점과 채널이 기록됨';
      case 'measure':
        return '1주 관찰 지표가 정의됨';
      case 'iterate':
        return '개선 항목이 다음 지시서로 연결됨';
      case 'maintain':
        return '월간 점검 항목이 지정됨';
      default:
        return '완료 조건 확인';
    }
  }

  bool _containsAny(String text, List<String> keys) {
    final lower = text.toLowerCase();
    return keys.any(lower.contains);
  }
}
