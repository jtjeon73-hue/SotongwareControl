class BusinessStudyLesson {
  const BusinessStudyLesson({
    required this.id,
    required this.title,
    required this.coreConcept,
    required this.detail,
    required this.caseStudy,
    required this.sotongApplication,
    required this.question,
    required this.action,
    required this.summary,
  });

  final String id;
  final String title;
  final String coreConcept;
  final String detail;
  final String caseStudy;
  final String sotongApplication;
  final String question;
  final String action;
  final String summary;
}

class BusinessStudyDomain {
  const BusinessStudyDomain({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final List<BusinessStudyLesson> lessons;
}

class BusinessStudyContent {
  BusinessStudyContent._();

  static const domains = <BusinessStudyDomain>[
    BusinessStudyDomain(
      id: 'mindset',
      title: '사업자의 마인드와 자세',
      description: '혼자서 여러 사업을 지속적으로 운영하기 위한 책임감, 실행력, 판단 기준을 학습합니다.',
      lessons: [
        BusinessStudyLesson(
          id: 'mindset_execution',
          title: '완벽보다 검증 가능한 실행',
          coreConcept:
              '사업의 실행은 많이 만드는 것이 아니라 고객에게 확인할 수 있는 작은 결과를 반복해서 내는 것입니다.',
          detail:
              '개발자는 기능 완성도를 높이는 데 집중하기 쉽지만, 사업자는 그 기능이 누구의 어떤 문제를 해결하고 실제 사용·문의·구매로 이어지는지 확인해야 합니다. 작은 범위를 정하고 완료 기준과 확인 날짜를 함께 둡니다.',
          caseStudy:
              '앱의 모든 부가기능을 만들기 전에 로그인, 핵심 기능, 데이터 저장, 배포까지 한 흐름을 완성하면 실제 사용 가능성을 먼저 검증할 수 있습니다.',
          sotongApplication:
              '5개 사업마다 이번 주 검증할 결과를 하나만 정합니다. 예: 앱 AAB 테스트, 산업자동화 통신 샘플, 전자책 목차 검토, 콘텐츠 1편 공개, 마케팅 문의 버튼 확인.',
          question: '현재 가장 오래 준비만 하고 실제 검증하지 않은 작업은 무엇입니까?',
          action: '오늘 60분 안에 확인 가능한 결과물 하나와 완료 기준을 작업 로그에 등록합니다.',
          summary: '작게 완성하고 실제로 확인하는 반복이 사업의 속도와 품질을 함께 높입니다.',
        ),
        BusinessStudyLesson(
          id: 'mindset_priority',
          title: '집중과 우선순위',
          coreConcept: '모든 사업을 동시에 같은 강도로 진행하면 중요한 일이 늦어집니다.',
          detail:
              '우선순위는 하고 싶은 순서가 아니라 고객 가치, 매출 연결 가능성, 위험, 소요 시간, 선행 조건을 기준으로 정합니다. 진행 중 작업 수를 제한하고 끝낸 뒤 다음 작업을 시작합니다.',
          caseStudy:
              '배포 직전 앱의 오류 수정과 아직 고객이 없는 신규 아이디어 개발이 동시에 있다면, 전자는 고객 가치와 완료 가능성이 더 높습니다.',
          sotongApplication:
              '소통총관제의 실제 프로젝트 중 다음 단계가 명확하고 7일 안에 완료 가능한 프로젝트를 최우선 후보로 봅니다.',
          question: '지금 하지 않아도 되는 작업을 멈추면 어떤 핵심 작업에 집중할 수 있습니까?',
          action: '진행 중 작업을 3개 이하로 줄이고 각 작업의 다음 행동을 한 문장으로 적습니다.',
          summary: '우선순위는 더 많이 하는 기술이 아니라 덜 중요한 일을 중단하는 기술입니다.',
        ),
        BusinessStudyLesson(
          id: 'mindset_resilience',
          title: '실패와 감정을 사업 판단에서 분리하기',
          coreConcept: '실패한 시도는 개인의 실패가 아니라 다음 판단을 위한 사업 데이터입니다.',
          detail:
              '반응이 없거나 오류가 발생했을 때 즉시 사업 전체를 포기하거나 감정적으로 기능을 늘리지 않습니다. 가설, 실행, 결과, 원인, 다음 실험으로 나누어 기록하면 실패 비용이 학습 자산이 됩니다.',
          caseStudy:
              '홍보 사이트 문의가 없다면 디자인만 탓하지 않고 방문 수, CTA 노출, 신뢰 요소, 고객 대상부터 확인합니다.',
          sotongApplication:
              '배포·테스트 실패를 작업 로그와 이슈로 남기고 재발 방지 항목을 다음 작업에 연결합니다.',
          question: '최근 실패에서 실제로 확인된 사실과 아직 추정인 내용은 무엇입니까?',
          action: '최근 실패 한 건을 사실·판단·다음 실험의 세 칸으로 정리합니다.',
          summary: '감정은 인정하되 사업 결정은 기록된 사실과 작은 실험을 기준으로 합니다.',
        ),
      ],
    ),
    BusinessStudyDomain(
      id: 'essentials',
      title: '사업자의 필수 지식',
      description: '돈, 고객, 계약, 세금, 유지관리 등 사업 운영에 필요한 공통 기초를 학습합니다.',
      lessons: [
        BusinessStudyLesson(
          id: 'essential_cashflow',
          title: '매출·이익·현금흐름 구분',
          coreConcept: '매출이 발생해도 입금 시점과 비용 지급 시점에 따라 현금이 부족할 수 있습니다.',
          detail:
              '매출은 판매액, 이익은 매출에서 비용을 뺀 결과, 현금흐름은 실제 돈이 들어오고 나간 시점입니다. 프로젝트 계약금·중도금·잔금과 구독·광고·판매 수익은 유입 구조가 다릅니다.',
          caseStudy:
              '산업자동화 납품 잔금이 검수 후 들어오는데 장비·출장 비용을 먼저 내면 장부상 이익과 실제 현금이 다릅니다.',
          sotongApplication:
              '앱 수익, 산업자동화 대금, 전자책 판매, 콘텐츠 수익, 마케팅 사이트 제작비를 사업별·입금 예정일별로 구분합니다.',
          question: '현재 확정된 매출과 실제 입금된 현금은 각각 얼마입니까?',
          action: '추정 금액을 만들지 말고 실제 계약·입금·비용만 날짜와 함께 기록합니다.',
          summary: '성장은 매출 숫자뿐 아니라 현금이 언제 들어오고 나가는지 관리할 때 지속됩니다.',
        ),
        BusinessStudyLesson(
          id: 'essential_price',
          title: '가격과 견적의 기본',
          coreConcept: '가격은 개발 시간만이 아니라 고객 가치, 범위, 위험, 유지관리 책임을 반영합니다.',
          detail:
              '견적에는 작업 범위, 제외 범위, 납기, 검수 기준, 수정 횟수, 지급 조건, 유지보수 조건이 포함되어야 합니다. 낮은 가격으로 모호한 책임을 떠안으면 장기적으로 손실이 커집니다.',
          caseStudy:
              '웹사이트 제작에서 도메인, 콘텐츠 작성, 사진, 유지보수, 추가 페이지를 구분하지 않으면 무제한 수정 문제가 발생합니다.',
          sotongApplication: '5개 사업별 표준 견적 항목과 선택 옵션을 만들어 반복 사용합니다.',
          question: '현재 서비스 가격에 사후 대응 시간과 위험 비용이 포함되어 있습니까?',
          action: '한 사업을 골라 기본 제공·추가 옵션·제외 사항을 작성합니다.',
          summary: '좋은 견적은 가격표이면서 고객과 제작자의 기대를 맞추는 품질 문서입니다.',
        ),
        BusinessStudyLesson(
          id: 'essential_compliance',
          title: '세무·계약·개인정보의 확인 원칙',
          coreConcept: '기본 구조는 이해하되 개별 사안은 세무사·변호사 등 전문가에게 확인해야 합니다.',
          detail:
              '부가가치세, 종합소득세, 법인, 계약, 저작권, 개인정보는 사업에 영향을 주지만 상황별 적용이 다릅니다. 확정적인 자문처럼 판단하지 말고 증빙과 질문을 준비해 전문가 확인을 받습니다.',
          caseStudy:
              '앱에서 개인정보를 수집하면 기능 구현 외에도 수집 목적, 보관 기간, 삭제, 접근 권한을 검토해야 합니다.',
          sotongApplication:
              '소통웨어 서비스별 수집 데이터·결제·저작물·계약 형태를 목록으로 만들고 확인 필요 항목을 표시합니다.',
          question: '현재 서비스에서 전문가 확인이 필요한 법률·세무 항목은 무엇입니까?',
          action: '확정 사실과 전문가 확인 필요 사항을 분리한 체크리스트를 만듭니다.',
          summary: '기초 지식은 위험을 발견하기 위한 것이며, 개별 판단은 적절한 전문가 확인이 필요합니다.',
        ),
      ],
    ),
    BusinessStudyDomain(
      id: 'strategy',
      title: '사업자의 전략',
      description: '시장 선택, 차별화, 제품화, 반복 수익, 투자 우선순위를 학습합니다.',
      lessons: [
        BusinessStudyLesson(
          id: 'strategy_niche',
          title: '넓은 시장보다 구체적인 문제',
          coreConcept: '작은 사업은 모든 고객보다 명확한 문제를 가진 고객에게 집중할 때 경쟁력이 생깁니다.',
          detail:
              '시장 규모만 보지 말고 고객 접근 가능성, 문제의 빈도와 비용, 기존 대안의 불편, 소통웨어의 경험을 함께 평가합니다.',
          caseStudy: '일반 모니터링보다 특정 설비의 Modbus 데이터 수집·알람·CSV 저장 패키지가 제안하기 쉽습니다.',
          sotongApplication: '각 사업부에서 가장 구체적으로 설명할 수 있는 고객과 문제를 하나씩 정의합니다.',
          question: '소통웨어가 다른 제작자보다 더 잘 이해하는 고객 문제는 무엇입니까?',
          action: '고객·상황·문제·제공 결과를 한 문장으로 작성합니다.',
          summary: '차별화는 기능 수가 아니라 특정 고객의 문제를 더 정확히 해결하는 능력입니다.',
        ),
        BusinessStudyLesson(
          id: 'strategy_productize',
          title: '맞춤 개발을 제품으로 바꾸기',
          coreConcept: '반복되는 요구를 표준 범위와 옵션으로 정리하면 납품 속도와 이익 구조가 개선됩니다.',
          detail:
              '모든 프로젝트를 처음부터 만들지 않고 공통 코어, 설정, 템플릿, 검수표, 문서를 재사용합니다. 고객별 차이는 옵션으로 관리합니다.',
          caseStudy:
              '마케팅 사이트의 소개·서비스·실적·문의 구조를 템플릿화하면 디자인과 콘텐츠만 조정해 반복 제작할 수 있습니다.',
          sotongApplication:
              '산업자동화 통신 모듈, Flutter 인증 골격, 전자책 템플릿, 콘텐츠 제작표, 웹 랜딩 템플릿을 자산화합니다.',
          question: '최근 세 프로젝트에서 반복해서 만든 것은 무엇입니까?',
          action: '반복 요소 하나를 코드·문서·체크리스트 중 하나의 재사용 자산으로 정리합니다.',
          summary: '제품화는 맞춤성을 없애는 것이 아니라 반복 부분을 표준화하는 일입니다.',
        ),
        BusinessStudyLesson(
          id: 'strategy_portfolio',
          title: '여러 사업의 포트폴리오 관리',
          coreConcept: '사업마다 역할과 투자 기준을 달리해 전체 위험을 관리합니다.',
          detail:
              '현금 창출 사업, 성장 실험, 브랜드 구축, 장기 기술 자산을 구분합니다. 모두 같은 KPI로 평가하지 않되 중단 기준은 명확히 둡니다.',
          caseStudy:
              '웹 제작은 단기 현금흐름, 앱은 제품 자산, 콘텐츠는 유입, 전자책은 반복 판매, 산업자동화는 고가 B2B 역할을 할 수 있습니다.',
          sotongApplication: '5개 사업 각각의 현재 역할과 향후 90일 투자 시간을 기록합니다.',
          question: '현재 시간 투자가 사업별 역할과 기대 결과에 맞습니까?',
          action: '5개 사업을 유지·성장·실험 중 하나로 분류하고 다음 검토일을 정합니다.',
          summary: '여러 사업의 목표와 검토 기준을 분리해야 집중과 확장을 함께 관리할 수 있습니다.',
        ),
      ],
    ),
    BusinessStudyDomain(
      id: 'software_direction',
      title: '소프트웨어 사업의 방향',
      description: '앱, SaaS, 산업용 SW, 맞춤 개발과 구독·라이선스 모델의 방향을 학습합니다.',
      lessons: [
        BusinessStudyLesson(
          id: 'software_service_product',
          title: '서비스와 제품의 균형',
          coreConcept: '맞춤 개발은 고객 학습과 현금을 만들고, 제품은 반복 판매와 확장성을 만듭니다.',
          detail:
              '서비스에서 반복되는 문제를 발견하고 공통 코어를 제품화합니다. 제품은 유지관리·지원·업데이트 비용까지 포함해 설계해야 합니다.',
          caseStudy:
              '설비 데이터 수집 맞춤 프로젝트에서 공통 통신·저장·대시보드 모듈을 분리하면 표준 제품의 기반이 됩니다.',
          sotongApplication: '현재 프로젝트에서 고객 전용 부분과 여러 고객에게 재사용 가능한 부분을 구분합니다.',
          question: '현재 코드 중 다른 고객에게 재사용할 수 있는 핵심은 무엇입니까?',
          action: '한 프로젝트의 기능을 공통 코어·설정·고객 전용 세 영역으로 분류합니다.',
          summary: '서비스 경험을 제품 자산으로 전환하는 흐름이 1인 소프트웨어 회사의 성장 기반입니다.',
        ),
        BusinessStudyLesson(
          id: 'software_revenue',
          title: '수익 모델과 유지 비용',
          coreConcept: '판매 방식은 고객 가치와 지속 비용에 맞아야 합니다.',
          detail:
              '단품, 구독, 라이선스, 광고, 유지보수, 프로젝트 비용은 각각 고객 기대와 운영 책임이 다릅니다. 서버·지원·업데이트 비용이 반복되면 반복 수익 구조가 필요합니다.',
          caseStudy: '데이터 서버와 알림을 지속 운영하는 서비스는 일회성 판매만으로 장기 비용을 감당하기 어렵습니다.',
          sotongApplication: '각 소프트웨어의 지속 비용과 현재 수익 방식을 비교해 불균형을 표시합니다.',
          question: '현재 판매 후에도 계속 발생하는 비용은 무엇입니까?',
          action: '서비스별 초기 비용·월간 비용·지원 시간을 실제 값이 있는 범위에서 기록합니다.',
          summary: '수익 모델은 가격 기법이 아니라 제품을 지속 가능하게 운영하는 구조입니다.',
        ),
        BusinessStudyLesson(
          id: 'software_quality',
          title: '출시 가능한 품질의 기준',
          coreConcept:
              '완벽한 코드가 아니라 핵심 흐름, 데이터 보호, 오류 대응, 배포와 복구가 확인된 상태가 출시 기준입니다.',
          detail:
              '테스트, 모바일 대응, 문서, 모니터링, 백업, 보안, 접근성, 버전 관리의 최소 기준을 제품별로 정합니다.',
          caseStudy:
              'Flutter 앱은 빌드 성공만으로 출시 준비가 아니며 실제 기기, 로그인, 데이터, 권한, 네트워크 실패를 확인해야 합니다.',
          sotongApplication:
              '소통총관제 분석에서 테스트·README·배포·최근 활동 여부를 준비도 지표로 사용합니다.',
          question: '현재 프로젝트의 출시를 막는 확인되지 않은 항목은 무엇입니까?',
          action: '프로젝트 하나에 대해 출시 체크리스트와 증거 링크를 등록합니다.',
          summary: '품질은 느낌이 아니라 반복 가능한 완료 기준과 확인 기록으로 관리합니다.',
        ),
      ],
    ),
    BusinessStudyDomain(
      id: 'ai_flow',
      title: 'AI와 소프트웨어의 흐름',
      description: '생성형 AI, Agent, 코딩 자동화와 실제 사업 가치를 구분하여 학습합니다.',
      lessons: [
        BusinessStudyLesson(
          id: 'ai_value',
          title: 'AI 유행과 실제 가치 구분',
          coreConcept: 'AI 도입은 최신 모델 사용이 아니라 시간·품질·매출·위험 중 무엇을 개선하는지로 평가합니다.',
          detail:
              '도구 데모보다 입력 데이터, 검토 책임, 반복 빈도, 오류 비용, 운영 비용을 확인합니다. 사람이 검증해야 하는 영역을 명확히 둡니다.',
          caseStudy:
              'AI가 강의 본문을 생성해도 출처·중복·퀴즈 정답·개인정보를 검증하지 않으면 운영 콘텐츠로 공개할 수 없습니다.',
          sotongApplication:
              'AI 기능마다 실제 연결 여부, 입력 데이터, 검증자, 실패 시 동작을 소통총관제에 표시합니다.',
          question: '현재 AI 기능이 실제로 줄이는 시간 또는 높이는 품질은 무엇입니까?',
          action: 'AI 도입 후보 하나를 효과·비용·위험·검증 방법으로 평가합니다.',
          summary: 'AI의 가치는 기능 이름이 아니라 검증 가능한 사업 결과로 판단합니다.',
        ),
        BusinessStudyLesson(
          id: 'ai_agent',
          title: 'AI Agent와 책임 있는 자동화',
          coreConcept:
              'Agent는 도구를 호출하고 작업을 이어갈 수 있지만 권한, 승인, 기록, 중단 조건이 필요합니다.',
          detail:
              '읽기와 쓰기 권한을 분리하고 외부 배포·결제·삭제 같은 고위험 작업은 사람 승인을 요구합니다. 입력과 결과, 오류를 추적할 수 있어야 합니다.',
          caseStudy:
              'GitHub 분석 Agent는 공개 정보를 읽을 수 있지만 코드 변경·배포는 검토와 승인 뒤 실행해야 합니다.',
          sotongApplication:
              'AI 사업분석은 실제 Firestore와 공개 GitHub 데이터를 규칙으로 분석하고, 추정은 별도로 표시합니다.',
          question: '자동화가 잘못되었을 때 즉시 중단하고 복구할 수 있습니까?',
          action: '자동화 하나의 허용 작업·금지 작업·승인 작업·로그 항목을 정의합니다.',
          summary: '안전한 Agent는 자율성보다 권한 경계와 검증 기록이 명확합니다.',
        ),
        BusinessStudyLesson(
          id: 'ai_opportunity',
          title: '5개 사업에서의 AI 기회',
          coreConcept: 'AI는 각 사업의 반복적이고 검증 가능한 작업에 연결할 때 효과가 큽니다.',
          detail:
              '산업자동화는 이상 패턴 보조, 앱은 개인화·지원, 전자책은 구조화·교정, 콘텐츠는 초안·변형, 마케팅은 카피·분석에 활용할 수 있습니다.',
          caseStudy:
              '콘텐츠 제목 후보 생성은 빠르게 자동화할 수 있지만 저작권, 사실성, 브랜드 적합성은 사람이 검토합니다.',
          sotongApplication:
              '5개 사업별 AI 후보를 하나씩 선정하고 실제 데이터 준비 여부와 검증 비용을 확인합니다.',
          question: '가장 자주 반복되며 결과를 사람이 쉽게 검증할 수 있는 작업은 무엇입니까?',
          action: 'AI 적용 후보를 빈도·시간 절감·검증 난이도로 점수화하되 실제 수치만 사용합니다.',
          summary: '작고 반복적이며 검증 가능한 작업부터 AI를 적용해야 운영 위험을 낮출 수 있습니다.',
        ),
      ],
    ),
  ];
}
