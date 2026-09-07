import '../models/artifact_type.dart';

/// High-quality WI title recommendations by business kind + audience.
/// Curated seeds + light enrichment; never invent fake metrics/customers.
class StudioTitleRecommendations {
  StudioTitleRecommendations._();

  static const maxTitles = 50;
  static const topPreview = 10;

  /// User-facing business kind → internal artifactType (+ optional siteSubtype).
  static const businessKinds = <({
    String id,
    String label,
    String artifactType,
    String? siteSubtype,
  })>[
    (
      id: 'industrial_sw',
      label: '산업자동화 SW',
      artifactType: ArtifactType.app,
      siteSubtype: null,
    ),
    (
      id: 'app',
      label: '앱',
      artifactType: ArtifactType.app,
      siteSubtype: null,
    ),
    (
      id: 'ebook',
      label: '전자책',
      artifactType: ArtifactType.ebook,
      siteSubtype: null,
    ),
    (
      id: 'knowledge_site',
      label: '지식·교육 사이트',
      artifactType: ArtifactType.site,
      siteSubtype: 'knowledge_site',
    ),
    (
      id: 'marketing_site',
      label: '마케팅 사이트',
      artifactType: ArtifactType.site,
      siteSubtype: 'marketing_site',
    ),
    (
      id: 'content',
      label: '콘텐츠',
      artifactType: ArtifactType.contents,
      siteSubtype: null,
    ),
  ];

  static String ideaPlaceholder({
    required String artifactType,
    String? siteSubtype,
    List<String> audienceIds = const [],
    String? businessKindId,
  }) {
    final art = ArtifactType.normalize(artifactType);
    final site = (siteSubtype ?? '').trim();
    final kind = (businessKindId ?? '').trim();
    if (kind == 'industrial_sw' ||
        audienceIds.any(
          (a) =>
              a.contains('factory') ||
              a.contains('manufact') ||
              a.contains('생산') ||
              a.contains('보전'),
        )) {
      return '예: 중소 제조업체가 여러 자동화 업체를 따로 찾지 않고 '
          '상담부터 개발·연동·유지보수까지 한 곳에서 받을 수 있는 서비스';
    }
    if (art == ArtifactType.app) {
      return '예: 부모님도 쉽게 사용할 수 있는 복약·병원 일정 관리 앱';
    }
    if (art == ArtifactType.ebook) {
      return '예: 50대 초보자가 AI를 이용해 첫 전자책을 만드는 방법';
    }
    if (art == ArtifactType.site && site.contains('marketing')) {
      return '예: 지역 소상공인이 서비스와 가격을 쉽게 알리고 '
          '상담 문의를 받을 수 있는 사이트';
    }
    if (art == ArtifactType.site) {
      return '예: 현장 담당자가 용어·절차를 바로 찾아보는 실무 지식 허브';
    }
    if (art == ArtifactType.contents) {
      return '예: 제품 특징을 30초 안에 이해시키는 쇼츠 영상 시리즈';
    }
    return '예: 고객이 하루를 아끼고 실수를 줄일 수 있는 실용 결과물';
  }

  static List<String> recommend({
    required String artifactType,
    String? siteSubtype,
    List<String> audienceIds = const [],
    String? businessKindId,
    int limit = maxTitles,
  }) {
    final art = ArtifactType.normalize(artifactType);
    final site = (siteSubtype ?? '').trim();
    final kind = (businessKindId ?? '').trim();
    final audiences = audienceIds
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'custom')
        .toList();

    final pool = <String>[
      if (kind == 'industrial_sw') ..._industrialSeeds,
      ..._baseFor(art, site),
      ..._audienceFlavor(art, audiences),
      ..._qualityAngles(art, site),
    ];

    final deduped = <String>[];
    final seen = <String>{};
    for (final raw in pool) {
      final t = raw.trim();
      if (t.length < 8 || t.length > 64) continue;
      if (_looksTechnicalOnly(t)) continue;
      if (_looksFakeClaim(t)) continue;
      final key = t.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (!seen.add(key)) continue;
      if (_nearDuplicate(deduped, t)) continue;
      deduped.add(t);
      if (deduped.length >= limit) break;
    }

    // Ensure fallback always returns something usable.
    if (deduped.isEmpty) {
      return _fallback(art).take(limit).toList(growable: false);
    }
    return deduped;
  }

  static bool _looksTechnicalOnly(String t) {
    final tech = RegExp(
      r'^(PLC|MES|SCADA|ERP|API|SDK|IoT|AI|ML)\s',
      caseSensitive: false,
    );
    return tech.hasMatch(t) && !t.contains(' ');
  }

  static bool _looksFakeClaim(String t) {
    final bad = RegExp(
      r'(\d+%|보장|무조건|대박|월\s*\d+|억\s*매출|검증된\s*\d+)',
      caseSensitive: false,
    );
    return bad.hasMatch(t);
  }

  static bool _nearDuplicate(List<String> existing, String candidate) {
    final c = candidate.replaceAll(RegExp(r'[^\w가-힣]'), '');
    for (final e in existing) {
      final a = e.replaceAll(RegExp(r'[^\w가-힣]'), '');
      if (a == c) return true;
      if (a.length > 10 && c.length > 10) {
        final shorter = a.length < c.length ? a : c;
        final longer = a.length < c.length ? c : a;
        if (longer.contains(shorter) && shorter.length / longer.length > 0.82) {
          return true;
        }
      }
    }
    return false;
  }

  static List<String> _baseFor(String art, String site) {
    if (art == ArtifactType.app) {
      return const [
        '공장 설비가 멈추기 전에 먼저 알려주는 스마트 모니터링',
        '현장 직원이 태블릿으로 바로 점검하는 설비 일지',
        '고장 원인을 찾기 쉽게 정리해 주는 보전 도우미',
        '교대 근무자가 인계를 놓치지 않게 돕는 현장 메모',
        '품질 이상 신호를 한눈에 모아 보는 라인 보드',
        '부모님도 큰 글씨로 쓰는 복약·병원 일정 앱',
        '바쁜 사장님이 주문·재고를 한 화면에서 보는 가게 앱',
        '팀원이 같은 체크리스트로 일하는 현장 협업 앱',
        '초보도 헤매지 않는 단계별 학습 연습 앱',
        '하루 일정을 덜 복잡하게 만드는 생활 도우미',
        '사진 한 장으로 이상 여부를 남기는 점검 앱',
        '알람이 쌓여도 우선순위가 보이는 알림 정리 앱',
        '거래처 연락을 놓치지 않게 돕는 미니 CRM',
        '교육 진도를 스스로 확인하는 학습 트래커',
        '이동 중에도 빠르게 보고하는 모바일 업무 앱',
      ];
    }
    if (art == ArtifactType.ebook) {
      return const [
        '50대 초보자가 AI로 첫 전자책을 만드는 방법',
        '바쁜 직장인이 퇴근 후 한 장씩 끝내는 실무 입문',
        '자영업자가 고객 질문을 책으로 정리하는 법',
        '처음 시작하는 사람을 위한 쉬운 용어 해설집',
        '실패를 줄이는 체크리스트형 실전 가이드',
        '하루 20분으로 따라 하는 기초 실습 노트',
        '현장에서 바로 쓰는 질문·답변 모음집',
        '초보 실무자가 헤매지 않게 돕는 단계별 매뉴얼',
        '중장년이 스스로 배우는 생활 기술 입문서',
        '취미를 결과물로 바꾸는 작은 프로젝트 가이드',
        '고객이 자주 묻는 것만 모아 둔 친절한 FAQ 북',
        '처음 계약·견적 전에 알아둘 실무 포인트',
        '혼자 준비해도 덜 막히는 시작 로드맵',
        '사례 중심으로 이해하는 쉬운 업무 이야기',
        '복잡한 절차를 그림처럼 풀어 쓴 안내서',
      ];
    }
    if (art == ArtifactType.site) {
      if (site.contains('marketing') || site.contains('promo')) {
        return const [
          '지역 사장님이 서비스와 가격을 바로 알리는 소개 사이트',
          '상담 문의가 자연스럽게 이어지는 친절한 랜딩',
          '제품 특징을 한 화면에서 이해시키는 소개 페이지',
          '방문자가 다음 행동을 고민하지 않는 전환 중심 사이트',
          '후기·사례 없이도 신뢰가 느껴지는 회사 소개',
          '모바일에서도 읽기 쉬운 지역 사업 홍보 페이지',
          '견적 요청 전에 궁금증을 풀어 주는 안내 사이트',
          '서비스 범위를 과장 없이 보여주는 솔직한 소개',
          '첫 방문자가 30초 안에 이해하는 홈 메시지',
          '문의 버튼이 눈에 들어오지만 부담스럽지 않은 페이지',
          '제조·현장 고객이 찾아도 전문성이 보이는 소개',
          '온라인 판매자가 상품 가치를 짧게 설명하는 페이지',
          '개인 브랜드를 차분하게 소개하는 미니 사이트',
          '가격·일정·연락처가 한곳에 모인 실용 소개',
          '상담 전에 자주 묻는 질문을 먼저 보여주는 안내',
        ];
      }
      return const [
        '현장 담당자가 용어·절차를 바로 찾는 실무 지식 허브',
        '초보도 헤매지 않는 단계별 학습 사이트',
        '검색하면 바로 답이 나오는 친절한 FAQ 허브',
        '바쁜 직장인이 짧은 글로 배우는 실무 가이드',
        '학부모가 이해하기 쉬운 학습 안내 사이트',
        '중장년 학습자를 위한 큰 글씨·쉬운 설명 허브',
        '자격 준비를 스스로 점검하는 학습 로드맵 사이트',
        '흩어진 자료를 주제별로 모아 둔 지식 도서관',
        '실무 질문이 쌓일수록 더 쓸모 있어지는 Q&A',
        '처음 온 사람도 길을 잃지 않는 카테고리 구조',
        '현장 사례를 과장 없이 정리한 학습 자료실',
        '검색·목차로 바로 이동하는 실전 매뉴얼 사이트',
        '팀 공통 지식을 한곳에 모으는 사내 학습 허브',
        '초보 질문에 먼저 답하는 입문 지식관',
        '전문 용어를 일상어로 풀어 주는 해설 사이트',
      ];
    }
    // contents
    return const [
      '제품 특징을 30초 안에 이해시키는 쇼츠 시리즈',
      '초보도 따라 하는 짧은 실습 영상 시리즈',
      '하루 일과에 자연스럽게 붙는 짧은 팁 콘텐츠',
      '고객 고민을 장면으로 보여주는 스토리 숏폼',
      '복잡한 기능을 한 장면씩 풀어 주는 설명 영상',
      '현장 분위기가 느껴지는 짧은 데모 클립',
      '질문이 생기기 전에 답하는 FAQ 숏폼',
      '음악과 함께 분위기를 전하는 브랜드 클립',
      '만화처럼 읽히는 가벼운 안내 콘텐츠',
      '홍보가 아닌 이해부터 돕는 소개 시리즈',
      '바쁜 사람이 Scrub 없이 보는 핵심 요약 영상',
      '서비스 이용 전 꼭 볼 체크 포인트 숏폼',
      '고객 언어로 말하는 친절한 안내 클립',
      '한 주 주제만 깊게 다루는 미니 시리즈',
      '공유하고 싶어지는 짧고 명확한 팁 카드',
    ];
  }

  static List<String> _audienceFlavor(String art, List<String> audiences) {
    final out = <String>[];
    for (final a in audiences) {
      if (a.contains('factory') ||
          a.contains('plant') ||
          a.contains('manufact') ||
          a.contains('유지') ||
          a.contains('보전') ||
          a.contains('생산')) {
        out.addAll(const [
          '설비 담당자가 아침에 먼저 열어보는 이상 신호 보드',
          '생산 라인이 멈춘 이유를 더 빨리 찾아주는 현장 도우미',
          '보전 일지를 적기 쉽게 만드는 모바일 점검 흐름',
          '교대 인수인계가 빠지지 않게 돕는 현장 체크',
          '품질 이상 사진을 바로 남기는 간단한 보고 도구',
        ]);
      }
      if (a.contains('senior') ||
          a.contains('중장년') ||
          a.contains('50') ||
          a.contains('부모')) {
        out.addAll(const [
          '글씨가 크고 버튼이 여유로운 초보 친화 안내',
          '처음 쓰는 사람도 헤매지 않는 쉬운 시작 화면',
          '자녀에게 묻지 않아도 따라 할 수 있는 단계 안내',
        ]);
      }
      if (a.contains('소상공') ||
          a.contains('자영') ||
          a.contains('사장님') ||
          a.contains('local')) {
        out.addAll(const [
          '사장님이 바쁠 때도 문의 내용을 놓치지 않는 안내',
          '가게 소식을 짧게 알리고 상담으로 이어주는 소개',
          '가격·영업시간을 손님에게 바로 보여주는 페이지',
        ]);
      }
      if (a.contains('student') || a.contains('학생') || a.contains('학습')) {
        out.addAll(const [
          '오늘 배울 것만 보이는 짧은 학습 로드맵',
          '복습이 부담스럽지 않은 한 장 요약 자료',
        ]);
      }
    }
    if (art == ArtifactType.app) {
      out.addAll(const [
        '알람·할 일을 덜 복잡하게 정리하는 하루 도우미',
        '팀 공지를 놓치지 않게 모아 주는 간단 보드',
      ]);
    }
    return out;
  }

  static List<String> _fallback(String art) {
    switch (art) {
      case ArtifactType.ebook:
        return const ['초보도 끝까지 읽을 수 있는 쉬운 실무 가이드'];
      case ArtifactType.site:
        return const ['방문자가 바로 이해하는 친절한 안내 사이트'];
      case ArtifactType.contents:
        return const ['짧게 보고 바로 이해하는 안내 콘텐츠'];
      default:
        return const ['고객 하루를 덜 복잡하게 만드는 실용 앱'];
    }
  }

  static const _industrialSeeds = <String>[
    '공장 설비가 멈추기 전에 먼저 알려주는 스마트 모니터링',
    '중소 공장이 상담부터 유지보수까지 한곳에서 받는 자동화 창구',
    '생산기술 담당자가 라인 이상을 바로 공유하는 현장 보드',
    '설비보전 팀이 점검 순서를 놓치지 않게 돕는 일지 앱',
    '품질 이상 사진을 즉시 남기는 간단한 보고 흐름',
    '자동화 담당자가 여러 업체를 비교하기 쉽게 정리한 상담 가이드',
    '교대 근무 인계가 빠지지 않게 돕는 현장 체크',
    '중소 제조 대표가 현황을 한눈에 보는 운영 요약',
    '설비가 왜 멈췄는지 더 빨리 찾는 보전 도우미',
    '라인별 알람을 우선순위로 정리해 주는 알림 보드',
  ];

  /// 품질 각도별 보완 시드 (친근·비용·시간·결과·검색 클릭 등).
  static List<String> _qualityAngles(String art, String site) {
    if (art == ArtifactType.app) {
      return const [
        '비용 고민 전에 먼저 쓸 수 있는 가벼운 현장 도우미',
        '기록 시간을 줄여 주는 한 화면 업무 앱',
        '불편한 엑셀 대신 바로 적는 모바일 일지',
        '결과가 눈에 보이는 간단한 진행 보드',
        '검색해도 찾기 쉬운 이름의 실용 앱',
        '미래 확장이 궁금한 사람을 위한 시작용 미니 앱',
        '초보 직원이 첫날부터 따라 하는 체크 앱',
        '고객 문의가 쌓이기 전에 정리하는 응대 메모',
        '반복 실수를 줄여 주는 단계 안내 앱',
        '이동 중에도 보고가 끝나는 짧은 업무 흐름',
        '팀 모두가 같은 기준으로 일하는 공통 체크리스트',
        '복잡한 설정을 숨긴 초보 친화 화면',
        '하루 마감을 더 가볍게 만드는 정리 도우미',
        '문제 발생 전 신호를 모으는 가벼운 관찰 앱',
        '현장 사진과 메모를 한곳에 모으는 기록 앱',
      ];
    }
    if (art == ArtifactType.ebook) {
      return const [
        '비용 부담 없이 시작하는 첫 실무 입문서',
        '시간을 아끼는 한 장 요약형 실전 노트',
        '막히는 지점만 골라 푼 친절한 문제 해결 가이드',
        '결과가 보이는 작은 실습으로 배우는 입문 책',
        '검색창에 치고 싶은 제목의 쉬운 해설서',
        '다음에 뭐가 올지 궁금하게 만드는 시리즈 1권',
        '초보 용어부터 차근히 풀어 주는 친절한 입문서',
        '퇴근 후 20분으로 끝내는 짧은 실무 장',
        '자영업 현장에서 바로 쓰는 질문 모음',
        '실패 포인트를 미리 알려 주는 체크리스트 북',
        '중장년이 혼자 읽어도 덜 막히는 생활 가이드',
        '전문 실무를 일상어로 풀어 쓴 해설집',
        '처음 계약 전에 읽으면 도움이 되는 안내서',
        '사례만 모아 이해를 돕는 쉬운 이야기 책',
        '취미를 결과물로 바꾸는 작은 프로젝트 노트',
      ];
    }
    if (art == ArtifactType.site) {
      if (site.contains('marketing') || site.contains('promo')) {
        return const [
          '비용 안내가 부담스럽지 않은 솔직한 소개 페이지',
          '문의 전 시간을 아껴 주는 FAQ 중심 랜딩',
          '방문자가 고민을 바로 해결받는 느낌의 홈',
          '결과가 보이는 서비스 소개 한 화면',
          '검색에서 클릭하고 싶은 지역 사업 소개',
          '다음에 무엇이 가능한지 궁금하게 하는 미니 사이트',
          '소상공인이 가격·연락처를 한곳에 모은 페이지',
          '온라인 판매자가 가치를 짧게 말하는 소개',
          '개인 브랜드를 과장 없이 소개하는 홈',
          '상담 버튼이 자연스럽게 보이는 전환 페이지',
          '제조 고객도 이해하기 쉬운 현장 친화 소개',
          '모바일에서 읽기 편한 지역 홍보 사이트',
          '서비스 범위를 차분히 보여주는 안내',
          '첫 30초에 핵심이 보이는 홈 메시지',
          '자주 묻는 질문을 먼저 풀어 주는 랜딩',
        ];
      }
      return const [
        '학습 시간을 줄여 주는 짧은 지식 허브',
        '비용 없이 먼저 찾아보는 친절한 FAQ',
        '문제가 생겼을 때 바로 열리는 실무 안내',
        '결과가 보이는 단계별 학습 로드맵',
        '검색해서 들어오고 싶은 제목의 지식관',
        '다음 챕터가 궁금한 학습 시리즈 사이트',
        '학생이 오늘 배울 것만 보는 안내',
        '학부모가 이해하기 쉬운 학습 설명',
        '직장인 퇴근 후 짧은 실무 가이드',
        '중장년 학습자를 위한 큰 글씨 허브',
        '자격 준비를 스스로 점검하는 로드맵',
        '흩어진 자료를 주제별로 모은 도서관',
        '초보 질문에 먼저 답하는 입문관',
        '전문 용어를 일상어로 푸는 해설 사이트',
        '팀 공통 지식을 한곳에 모으는 학습 허브',
      ];
    }
    return const [
      '비용을 들이지 않고도 이해되는 짧은 소개 숏폼',
      '시청 시간을 아끼는 30초 핵심 설명',
      '불편한 기능을 장면으로 풀어 주는 팁 영상',
      '결과가 보이는 실습형 숏폼 시리즈',
      '검색·공유하고 싶은 짧고 명확한 팁 카드',
      '다음 편이 궁금한 미니 시리즈',
      '초보도 따라 하는 짧은 실습 클립',
      '유튜브·쇼츠에 올리는 친절한 안내',
      '음악과 함께 분위기를 전하는 브랜드 클립',
      '만화처럼 읽히는 가벼운 안내 콘텐츠',
      '홍보보다 이해를 돕는 소개 시리즈',
      '질문 전에 답하는 FAQ 숏폼',
      '현장 느낌이 나는 짧은 데모',
      '한 주 주제만 깊게 다루는 미니 시리즈',
      '고객 언어로 말하는 친절한 안내 클립',
    ];
  }
}
