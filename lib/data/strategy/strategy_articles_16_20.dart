import 'strategy_models.dart';

const List<StrategyArticle> strategyArticles1620 = [
  StrategyArticle(
    id: 'strategy_16',
    title: '실패 가능성이 높은 사업을 적은 비용으로 검증하는 방법',
    summary:
        '대부분의 아이디어는 실패한다. '
        '2주·20만 원·10시간 같은 '
        'kill budget 안에서 가설을 깨는 실무 프레임.',
    category: '성장운영',
    tags: ['검증', 'MVP', '실험', '리스크'],
    problem:
        '플랫폼 전체 재개발, 앱 5종 동시, '
        '전자책 시리즈 10권— '
        '성공 스토리만 보면 큰 베팅이 맞는 것 같지만 '
        '1인 기업에견 한 번의 실패가 '
        '6개월 공백과 고정비 체납으로 이어질 수 있다. '
        '검증 없이 "이번엔 될 것"은 '
        '감정적 sunk cost 반복이다. '
        'kill budget 없이 "조금만 더" 하면 '
        '2주 실험이 2개월 개발로 바뀐다. '
        '검증 비용을 아끼면 '
        '실패 비용이 10배로 커질 수 있다.',
    whyImportant:
        '적은 비용 검증은 '
        '실패를 없애는 게 아니라 '
        '실패를 빨리·저렴하게 만든다. '
        '소통웨어는 PoC·랜딩·선불·인터뷰·데모 등 '
        '도구가 다양해 '
        '분야별 최소 실험을 설계하기 좋다. '
        '검증 통과도 매출 보장은 아니다. '
        'kill budget 없는 실험은 '
        '결국 "조금 더"만 반복하는 함정이 된다.',
    corePrinciples:
        '① Kill budget: 시간·금액·기회비용 상한 사전 선언. '
        '② One metric: 유료 intent 1개만. '
        '③ Fake door·concierge·Wizard of Oz 허용. '
        '④ 실패 정의: "0건이면 pivot 또는 중단". '
        '⑤ 학습 기록: 가설→실험→결과→다음. '
        '⑥ kill budget 초과 시 자동 보류 규칙을 '
        '스스로와 약속해 sunk cost를 끊는다.',
    sotongwareApplication:
        '앱: 스토어 전 대기 리스트 랜딩. '
        '전자책: 목차+1장 샘플 선주문. '
        '플랫폼: Notion+수동 배포 concierge MVP. '
        '자동화: Excel 매크로 수준 PoC 후 PC앱. '
        '콘텐츠: 3글+유료 PDF before 30글. '
        '실험 종료 후 wiki 1페이지에 '
        '가설·kill budget·결과를 남겨 재실험 비용을 줄인다.',
    scenario:
        '소통사이트매니저 유료 tier 가설. '
        'Kill: 2주, 개발 15h, 광고 5만 원. '
        '성공: 유료 intent 3건. '
        '결과 intent 1건— pivot: 템플릿 단품 판매로 축소. '
        '플랫폼 full build 2개월 분 avoided. '
        '실험 종료 후 가설·결과·다음 action을 '
        '내부 wiki 한 페이지에 남기면 '
        '같은 실수를 두 번 하지 않는다.',
    options: [
      StrategyOption(
        title: 'Concierge MVP',
        description:
            '수동으로 약속한 가치 제공, '
            '소프트웨어는 나중.',
        pros: '학습 밀도 최고.',
        risks: '대표 시간 소모.',
      ),
      StrategyOption(
        title: 'Smoke test only',
        description: '랜딩+가격+결제 intent.',
        pros: '개발 0~5h.',
        risks: '과장 시 브랜드 손상.',
      ),
      StrategyOption(
        title: 'Portfolio of bets',
        description: 'kill budget 작은 실험 3개 병렬.',
        pros: '분산.',
        risks: '1인에게 3개도 많을 수 있음.',
      ),
    ],
    reviewQuestions: [
      '진행 중 프로젝트에 kill budget이 있는가?',
      '성공 지표가 출시가 아닌 행동인가?',
      '실패 후 pivot 기록이 있는가?',
      '검증 없이 2개월+ 개발 중인가?',
      '실험 wiki·kill budget 초과 freeze 규칙이 있는가?',
    ],
    monthActions: [
      '진행 가설 1개 kill budget·성공 기준 문서화',
      '2주 실험 실행·회고·초과 시 freeze 결정',
      '실패 시 중단·축소를 캘린더·wiki에 기록',
    ],
    conclusion:
        '실패 가능성이 높다는 건 '
        '하지 말라는 뜻이 아니라 '
        '싸게 배우라는 뜻이다. '
        '소통웨어는 작은 실험을 '
        '사업부 간에 번갈아 돌리며 '
        '큰 도박을 피할 수 있다. '
        '실험 로그를 한 폴더에 모으면 '
        '반년 뒤 "우리는 무엇을 배웠는가"가 '
        '전자책·콘텐츠·내부 교육 자료로 재활용된다. '
        '실패 기록을 숨기지 않으면 '
        '다음 실험의 kill budget이 짧아진다. '
        '실패도 기록하면 '
        '회사 학습 자산이 된다. '
        '작은 실험 log가 쌓이면 '
        '큰 도박을 덜 하게 된다. '
        'kill budget 초과 시 자동 보류 규칙을 '
        '캘endars에 리마인더로 걸어 두면 '
        'sunk cost를 끊기 쉽다.',
  ),
  StrategyArticle(
    id: 'strategy_17',
    title: '여러 프로젝트가 중단되지 않도록 우선순위를 관리하는 방법',
    summary:
        'WIP가 많으면 모두 90%에서 멈춘다. '
        '칸반·WIP limit·주간 리뷰로 '
        '1인 개발기업의 흐름을 유지하는법.',
    category: '성장운영',
    tags: ['우선순위', 'WIP', '칸반', '프로젝트관리'],
    problem:
        '총관제에 13개 프로젝트가 "진행 중"이면 '
        '실제로는 context switch만 13번이다. '
        '고객 납품·앱 심사·블로그·플랫폼·전자책— '
        '각각 조금씩 진행되다 '
        '어느 주엔 갑자기 모두 urgent. '
        '우선순위 없는 TODO는 '
        '가장 시끄러운 것만 살아남는다. '
        '급한 유지보수가 North Star를 '
        '매주 잠식하는 패턴을 방지하려면 '
        'WIP limit이 필요하다. '
        'P0가 너무 많으면 '
        'North Star는 영원히 P1이다.',
    whyImportant:
        '중단은 동기·신뢰·현금흐름을 동시에 깎는다. '
        'B2B는 납기 slip이 재계약 kill. '
        '앱은 업데이트 공백이 리뷰 악화. '
        '1인에게 WIP 관리는 '
        '프로젝트 관리 methodology가 아니라 '
        '생존 장치다. '
        'WIP limit 없이 urgent만 처리하면 '
        '중요한 North Star가 영원히 "다음 주"로 밀린다.',
    corePrinciples:
        '① WIP limit: 동시 active 2~3. '
        '② Every item: priority P0~P3 + due + owner(대표). '
        '③ Weekly review: done / blocked / kill. '
        '④ Blocked 7일→ escalate or descope. '
        '⑤ "아이디어"는 backlog, "진행"과 분리. '
        '⑥ weekly review에서 "kill" 1건을 '
        '의무화해 backlog 팽창을 막는다.',
    sotongwareApplication:
        '총관제·샘플 데이터를 '
        '실제 우선순위 보드와 sync(수동 OK). '
        'P0: 납품·유료 고객. '
        'P1: North Star 성장. '
        'P2: 유지·콘텐츠. '
        'P3: 실험 backlog. '
        '사업부 라벨로 필터— '
        '한 주에 한 사업부 deep day 가능. '
        'blocked 7일 규칙 위반 항목은 '
        'weekly review에서 descope 또는 kill 필수.',
    scenario:
        'WIP 11→ limit 3 적용. '
        '8개를 backlog, '
        '3개만 sprint. '
        '2주 후 2개 done, 1개 blocked→ descope. '
        '고객 커뮤니케이션: '
        '일정 재협상 1건, 신뢰 유지. '
        '새 시작 0건 규칙 2주 유지. '
        'done 항목을 case·changelog로 '
        '즉시 변환하면 우선순위 관리가 '
        '마케팅 자산과 연결된다.',
    options: [
      StrategyOption(
        title: 'Strict WIP 2',
        description: '극단적 집중, 나머지 queue.',
        pros: '완료율↑.',
        risks: '기회 비용·고객 불만.',
      ),
      StrategyOption(
        title: 'Tiered WIP',
        description: 'P0 무제한(1)~P3 limit 1.',
        pros: '유연.',
        risks: 'P0 inflation.',
      ),
      StrategyOption(
        title: 'Timebox per division',
        description: '주별 사업부 half-day.',
        pros: '균형.',
        risks: 'deep work fragmentation.',
      ),
    ],
    reviewQuestions: [
      'active WIP 숫자를 아는가? 5 초과인가?',
      'blocked 항목과 7일 규칙을 쓰는가?',
      'weekly review가 4주 연속 있었는가?',
      'backlog와 active가 섞여 있지 않은가?',
    ],
    monthActions: [
      '전 프로젝트 P0~P3 태그 및 WIP limit 선언',
      'weekly review 4회·blocked 7일 초과 1건 descope',
      'backlog 정리·active 3건 이하 유지',
    ],
    conclusion:
        '프로젝트가 중단되지 않게 하려면 '
        '더 많이 시작하지 말고 '
        '더 적게 동시에 하라. '
        '소통웨어 총관제는 '
        '보기 좋은 숫자가 아니라 '
        'WIP를 드러내는 거울이 되어야 한다. '
        'blocked 사유 Top 3를 월말에 모으면 '
        '인프라·고객·스코프 중 어디를 고칠지 '
        '감으로 싸우지 않아도 된다. '
        'done 항목을 case·changelog로 '
        '즉시 변환하면 우선순위 관리가 '
        '마케팅 자산과 연결된다. '
        'weekly review 30분은 CEO block과 '
        '같은 캘린더 슬롯에 고정하자. '
        'WIP limit 위반 시 새 시작을 '
        '다음 주로 미루는 규칙을 스스로에게 적용한다.',
  ),
  StrategyArticle(
    id: 'strategy_18',
    title: '월 수익 목표를 방문자·고객·전환율로 분해하는 방법',
    summary:
        '"월 100만 원"은 실행 지침이 아니다. '
        '퍼널 수식으로 쪼개 '
        '이번 달 행동(글·랜딩·상담)과 연결한다.',
    category: '수익화',
    tags: ['목표', 'KPI', '퍼널', '전환율'],
    problem:
        '매출 목표만 세우고 '
        '방문·리드·상담·견적·계약 단계를 '
        '측정하지 않으면 '
        '월말에 "운이 나빴다"로 끝난다. '
        '광고·앱·B2B·전자책이 섞이면 '
        '더욱 원인 분석이 불가능하다. '
        '채널별 건수·단가·전환 없이 '
        '목표만 키우면 번아웃만 커진다. '
        'leading 지표 없이 lagging(매출)만 보면 '
        '한 달 낭비를 끝에서야 알게 된다. '
        '스프레드시트 한 장이면 '
        '채널별 건수·단가·전환을 '
        '1인도 충분히 추적할 수 있다. '
        '목표는 희망이 아니라 '
        '가정의 묶음이다.',
    whyImportant:
        '분해는 목표를 '
        '주간·일간 행동으로 번역한다. '
        '예: 100만 원 = 파일럿 1건(50)+템플릿 10건(5)+앱 IAP 20건— '
        '각각 필요 visit·conversion 가 역산. '
        '달성 보장은 없지만 '
        '헛수고(트래픽만)를 조기 발견한다. '
        '목표 숫자만 크고 퍼널이 없으면 '
        '월말 스트레스만 커진다.',
    corePrinciples:
        '① Revenue = Σ(상품i × 단가i × 건수i). '
        '② 각 상품: visit→lead→pay funnel. '
        '③ Conversion 가정은 지난 3개월 실적 기반, '
        '없으면 보수적 가정+범위. '
        '④ Leading vs lagging 지표 분리. '
        '⑤ 월 중 2주차 checkpoint. '
        '⑥ 목표 미달 시 트래픽·전환·단가 중 '
        '하나만 다음 달 실험 변수로 고른다.',
    sotongwareApplication:
        '콘텐츠: visit→PDF click→pay. '
        '웹마케팅: organic→form→call. '
        '앱: install→trial→IAP. '
        '자동화: inquiry→quote→deposit. '
        '플랫폼: trial→paid workspace. '
        '총관제 샘플 metrics를 '
        '실제 스프레드시트와 교체·병행. '
        '목표 미달 시 트래픽·전환·단가 중 '
        '하나만 다음 달 변수로 고른다.',
    scenario:
        '목표 월 80만 원(예시). '
        '템플릿 9,900×15=148.5k, '
        '파일럿 300k×1, '
        '앱 IAP 4,900×10=49k, '
        '나머지 gap은 B2B or adjust. '
        '템플릿 15건에 visit 600, CVR 2.5% 필요— '
        '글 4편+SEO 1주. '
        '2주차 PDF click 40→ pace OK. '
        'pace NG면 단가 올리기보다 '
        '퍼널 병목(클릭 vs 결제)부터 고친다.',
    options: [
      StrategyOption(
        title: 'Bottom-up funnel',
        description: '상품별 건수부터 역산.',
        pros: '행동 명확.',
        risks: '가정 틀리면 전체 붕괴.',
      ),
      StrategyOption(
        title: 'Top-down split',
        description: '총 목표를 사업부 % 배분.',
        pros: '균형.',
        risks: '약한 funnel에 과할당.',
      ),
      StrategyOption(
        title: 'Scenario bands',
        description: 'best/base/worst 3시나리오.',
        pros: '리스크 인식.',
        risks: '복잡.',
      ),
    ],
    reviewQuestions: [
      '월 목표가 건수·단가로 쪼개졌는가?',
      '각 단계 conversion을 측정 중인가?',
      '2주 checkpoint를 했는가?',
      '달성 실패 시 조정 규칙이 있는가?',
      'leading vs lagging 지표를 구분해 추적 중인가?',
    ],
    monthActions: [
      '월 목표 스프레드시트: 상품×건수×퍼널',
      'leading 지표 3개 주간 추적·2주 checkpoint',
      '미달 시 퍼널 병목 하나만 다음 달 실험 변수로 지정',
    ],
    conclusion:
        '월 수익 목표는 '
        '숫자가 아니라 방정식이 되어야 한다. '
        '소통웨어는 채널이 많을수록 '
        '분해 없이는 배울 수 없다. '
        '매출은 여전히 불확실하지만 '
        '행동은 더 선명해진다. '
        '목표 미달 시 "트래픽 문제"인지 '
        '"전환 문제"인지 "단가 문제"인지 '
        '분해표만으로도 다음 달 실험이 정해진다. '
        'best/base/worst 3시나리오를 '
        '한 줄씩만 적어도 '
        '목표 숫자 집착이 줄어든다. '
        '퍼널 분해표는 월말에 한 번만 '
        '갱신해도 다음 달 실험 우선순위가 '
        '명확해진다. '
        '채널별 단가·전환율을 나란히 두면 '
        '어느 레일에 시간을 쓸지 바로 보인다.',
  ),
  StrategyArticle(
    id: 'strategy_19',
    title: '소통웨어의 1년·3년·5년 성장 경로 설계',
    summary:
        '장기 비전과 단기 생존을 '
        '타임라인으로 정렬. '
        '1인 개발기업에 현실적인 마일스톤.',
    category: '성장운영',
    tags: ['로드맵', '장기', '마일스톤', '성장'],
    problem:
        '5년 후 "플랫폼 IPO"만 그리면 '
        '올해 호스팅비·납품·가족 시간과 충돌한다. '
        '반대로 이번 달 매출만 보면 '
        '자산·브랜드·플랫폼 투자가 영영 미루어진다. '
        '기간별 목표 없이 '
        '사업부가 제각각 속도로 움직인다. '
        '올해 cashflow와 5년 그림이 '
        '같은 문서에 없으면 '
        '분기마다 방향 싸움이 반복된다. '
        '5년 비전만 크고 올해 kill list가 없으면 '
        '매번 "이번엔 플랫폼"으로 돌아온다.',
    whyImportant:
        '1·3·5년은 '
        '같은 방향의 다른 zoom level이다. '
        '1년: 생존·1 North Star·첫 반복 수익. '
        '3년: 플랫폼·자산·히어로 제품. '
        '5년: 선택적 확장·파트너·(팀) — '
        '보장된 성장 곡선은 아니다. '
        '5년 계획만 크고 올해 theme가 없으면 '
        '로드맵이 포스터에 그만난다.',
    corePrinciples:
        '① 1년: cashflow positive 목표(정의 명확히), '
        'kill 2개 big bets. '
        '② 3년: 2 recurring rails, '
        'platform phase 2. '
        '③ 5년: wedge domination or pivot story. '
        '④ 매년 1 theme only. '
        '⑤ 분기 review— external shock 반영. '
        '⑥ 5년 그림은 "하지 않을 일" 목록과 '
        '쌍으로 작성해 FOMO를 줄인다.',
    sotongwareApplication:
        'Y1 theme: "현장 자산화+히어로 앱". '
        'Y2~3: "소통사이트매니저 유료+자동화 템플릿 SKU". '
        'Y4~5: "니치 integrator brand or SaaS scale" — '
        '실제 경로는 데이터에 따라 pivot. '
        '콘텐츠·전자책은 전 기간 Acquire. '
        '총관제는 로드맵 communication. '
        '매년 12월 asset inventory로 '
        '템플릿·case·코드 모듈 수를 세어 '
        '성장이 자산인지 부채인지 구분한다.',
    scenario:
        '2026: 템플릿·앱 tier·case 5건. '
        '2027~8: 플랫폼 paid 20 workspace(목표, 미보장). '
        '2029~30: 파트너 2·지역+온라인 mix. '
        '매년 12월 theme·kill list·asset inventory. '
        '매년 theme는 '
        '지난해 데이터(전환·납기·burnout)를 '
        '반영해 수정— 처음 쓴 글을 성경으로 두지 않는다.',
    options: [
      StrategyOption(
        title: 'Bootstrap path',
        description: '외부 투자 없이 recurring 중심.',
        pros: '통제·유연.',
        risks: '속도 한계.',
      ),
      StrategyOption(
        title: 'Services-led',
        description: 'B2B 납품이 R&D fund.',
        pros: '현금.',
        risks: '서비스 trap.',
      ),
      StrategyOption(
        title: 'Product-led',
        description: 'SaaS·앱 early bet.',
        pros: 'scale potential.',
        risks: 'long dry spell.',
      ),
    ],
    reviewQuestions: [
      '올해 theme가 1개인가?',
      '3년 목표가 올해 행동과 연결되는가?',
      '5년 그림이 팀 1명 현실과 맞는가?',
      '분기 review 일정이 있는가?',
      '올해 theme와 맞지 않는 진행 프로젝트를 kill했는가?',
    ],
    monthActions: [
      '1·3·5년 초안( theme·마일스톤·kill·asset inventory)',
      '올해 theme·분기 milestone 4개·총관제 공유',
      'theme와 맞지 않는 프로젝트 1건 kill list 추가',
    ],
    conclusion:
        '성장 경로는 '
        '운세가 아니라 '
        '선택의 시퀀스다. '
        '소통웨어는 1년 생존과 '
        '5년 그림을 동시에 쓸 수 있어야 하며, '
        '둘 다 분기마다 현실 검증이 필요하다. '
        '5년 목표는 희망이 아니라 '
        '올해 하지 않을 일을 적는 도구로 쓰면 '
        'FOMO가 줄어든다. '
        '로드맵은 포스터가 아니라 '
        '분기 review에서 수정하는 '
        '살아 있는 문서여야 한다. '
        '1·3·5년 목표를 한 페이지에 '
        '겹쳐 그리면 올해 kill list가 '
        '자연스럽게 나온다. '
        '로드맵 수정 이력을 남기면 '
        'FOMO 대신 학습 기록이 쌓인다.',
  ),
  StrategyArticle(
    id: 'strategy_20',
    title: '소통회장이 기술자에서 사업가로 성장하기 위해 필요한 변화',
    summary:
        '코딩·납품에 익숙한 대표가 '
        '가격·마케팅·거절·위임·재무를 '
        '배워야 회사가 개인 기술을 넘어선다.',
    category: '방향설정',
    tags: ['리더십', '사업가', '대표', '성장'],
    problem:
        '소통회장이 모든 코드·견적·글·미팅을 '
        '직접 하면 회사 매출 상한=대표 24h. '
        '기술자 마인드는 '
        '"완벽한 구현"에 시간을 쓰고 '
        '유료 검증·가격 협상·마케팅을 미루기 쉽다. '
        '사업부 6개는 '
        '대표 역량 확장 없이는 조직이 아니라 '
        '할 일 목록일 뿐이다. '
        'CEO 역할을 미루면 '
        '기술은 늘지만 가격·계약·재무는 '
        '같은 자리에 머문다. '
        '견적·가격·NO를 연습하지 않으면 '
        '좋은 기술도 할인 판매된다.',
    whyImportant:
        '사업가 성장은 '
        '타이틀 변경이 아니라 '
        '시간 배분·의사결정·리스크 감수 방식 변경이다. '
        '기술 신뢰는 소통웨어 자산이지만 '
        '스스로만 믿는 브랜드는 '
        '확장 불가. '
        '1인 단계에서도 '
        'CEO 시간 vs maker 시간 분리가 필요. '
        'CEO time 없이 maker만 하면 '
        '회사는 기술은 늘지만 수익 구조는 정체된다.',
    corePrinciples:
        '① CEO block: 영업·재무·전략 주 5h+. '
        '② 가격·계약·NO 말하기 연습. '
        '③ good enough shipping— 80% release. '
        '④ 재무: 월 P&L simple, tax reserve. '
        '⑤ 학습: sales·storytelling·delegation 소량씩. '
        '⑥ maker→CEO 시간 비율을 월말에 '
        '숫자로 기록해 습관 전환을 추적한다.',
    sotongwareApplication:
        '대표는 산업자동화 deep tech 유지하되 '
        '앱·콘텐츠·랜딩은 템플릿·AI 초안·재사용. '
        '웹마케팅은 "직접 다"가 아니라 checklist SEO. '
        '소통사이트매니저는 본인 dogfood. '
        '총관제로 CEO dashboard— '
        'WIP·cash·funnel weekly glance. '
        'CEO block에는 견적·가격·파트너십만 '
        '다루고 maker task는 템플릿·위임 목록으로 넘긴다.',
    scenario:
        '월 100h maker→ 70h로 줄이고 '
        '30h CEO(상담 10, 마케팅 8, 재무 4, 전략 8). '
        '견적 2건 NO— scope creep 거절. '
        '템플릿 판매 6건으로 '
        '단기 gap partial fill(보장 없음). '
        '6개월 후 납품 1건 margin 개선 체감. '
        'CEO block에 재무 4h를 넣으면 '
        '세금·고정비 surprise가 줄어 '
        '기술 일정이 덜 흔들린다.',
    options: [
      StrategyOption(
        title: 'CEO calendar hard block',
        description: '화·목 오전 CEO only.',
        pros: '습관화.',
        risks: 'urgent delivery 침범.',
      ),
      StrategyOption(
        title: 'Maker CEO alternate weeks',
        description: '주 alternation.',
        pros: 'deep work 보존.',
        risks: '영업 공백 주.',
      ),
      StrategyOption(
        title: 'Outsource maker fringe',
        description: '디자인·QA·초안 위임.',
        pros: 'CEO time 확보.',
        risks: '비용·품질.',
      ),
    ],
    reviewQuestions: [
      '지난 4주 CEO time 비율은?',
      'scope creep 견적을 NO한 적 있는가?',
      '월 P&L 또는 cash를 봤는가?',
      '모든 코드를 대표만 작성하는가?',
      '지난 달 CEO block 5h 목표를 달성했는가?',
    ],
    monthActions: [
      '주간 CEO block 5h 캘린더·4주 달성 기록',
      '월 simple P&L(수입·고정비·세금 reserve) 작성',
      '위임·템플릿화할 maker task 2개 실행',
    ],
    conclusion:
        '기술자에서 사업가로는 '
        '코드를 덜 짜는 것이 아니라 '
        '회사를 돌리는 시간을 '
        '의도적으로 만드는 것이다. '
        '소통웨어의 다음 단계는 '
        '대표 개인 skill이 아니라 '
        '시스템·자산·결정의 질에 달려 있다. '
        'CEO block 시간에만 '
        '견적·가격·파트너십을 다루는 습관이 '
        '6개월 후 회사 체감 속도를 바꾼다. '
        'maker 시간을 줄이는 것은 '
        '코드를 포기하는 것이 아니라 '
        '회사를 돌릴 여유를 만드는 것이다. '
        'CEO block을 캘린더에 반복 일정으로 '
        '고정하면 maker 일정과 충돌을 '
        '미리 조율할 수 있다.',
  ),
];
