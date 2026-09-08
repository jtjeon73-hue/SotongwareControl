import '../models/artifact_type.dart';

/// High-quality WI title recommendations by business kind + audience.
/// Curated seeds + strong audience filtering; never invent fake metrics.
class StudioTitleRecommendations {
  StudioTitleRecommendations._();

  static const maxTitles = 50;
  static const topPreview = 10;

  /// User-facing business kind → internal artifactType (+ optional siteSubtype).
  static const businessKinds =
      <({String id, String label, String artifactType, String? siteSubtype})>[
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

  static String labelForBusinessKind({
    required String artifactType,
    String? siteSubtype,
    String? businessKindId,
  }) {
    final kind = (businessKindId ?? '').trim();
    for (final k in businessKinds) {
      if (kind.isNotEmpty && k.id == kind) return k.label;
    }
    final art = ArtifactType.normalize(artifactType);
    final site = (siteSubtype ?? '').trim();
    if (art == ArtifactType.site && site.contains('marketing')) {
      return '마케팅 사이트';
    }
    if (art == ArtifactType.promoSite) return '마케팅 사이트';
    if (art == ArtifactType.site) return '지식·교육 사이트';
    if (art == ArtifactType.ebook) return '전자책';
    if (art == ArtifactType.contents) return '콘텐츠';
    if (art == ArtifactType.app) return '앱';
    return ArtifactType.labelKo(art);
  }

  /// 상세 제작 설정용 AI 자동 제작 라벨 (사업유형 동기화).
  /// 미선택 시 전자책으로 폴백하지 않는다.
  static String aiProductionModeLabel({
    required bool aiPilotEnabled,
    String artifactType = '',
    String? siteSubtype,
    String? businessKindId,
  }) {
    if (!aiPilotEnabled) return '수동·혼합 제작';
    final kind = (businessKindId ?? '').trim();
    final art = ArtifactType.normalize(artifactType);
    final site = (siteSubtype ?? '').trim();
    final hasSelection =
        kind.isNotEmpty ||
        (art.isNotEmpty && art != ArtifactType.undecided) ||
        site.isNotEmpty;
    if (!hasSelection) return 'AI 자동 제작';
    final label = labelForBusinessKind(
      artifactType: artifactType,
      siteSubtype: siteSubtype,
      businessKindId: businessKindId,
    );
    if (label.isEmpty || label == ArtifactType.labelKo(ArtifactType.undecided)) {
      return 'AI 자동 제작';
    }
    return 'AI 자동 제작 ($label)';
  }

  static String ideaPlaceholder({
    required String artifactType,
    String? siteSubtype,
    List<String> audienceIds = const [],
    String? businessKindId,
  }) {
    final art = ArtifactType.normalize(artifactType);
    final site = (siteSubtype ?? '').trim();
    final kind = (businessKindId ?? '').trim();
    final audiences = _normalizeAudiences(audienceIds);
    if (kind == 'industrial_sw' || audiences.any(_isIndustrialAudience)) {
      return '예: 중소 제조업체가 여러 자동화 업체를 따로 찾지 않고 '
          '상담부터 개발·연동·유지보수까지 한 곳에서 받을 수 있는 서비스';
    }
    if (audiences.any(_isOfficeAudience)) {
      if (art == ArtifactType.ebook) {
        return '예: 바쁜 직장인이 퇴근 후 20분씩 AI로 첫 전자책을 만드는 방법';
      }
      if (art == ArtifactType.app) {
        return '예: 출퇴근 시간을 덜 복잡하게 만드는 직장인용 일정 앱';
      }
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
    final audiences = _normalizeAudiences(
      audienceIds,
    ).where((a) => a != 'general').toList();
    final capped = limit.clamp(1, maxTitles);

    final seeds = <_TitleSeed>[
      if (kind == 'industrial_sw') ..._industrialSeeds,
      ..._seedsFor(art, site),
      ..._audienceSeeds(art, audiences),
    ];

    final matched = <String>[];
    final neutral = <String>[];
    final seen = <String>{};

    void consider(_TitleSeed seed, {required bool requireAudienceMatch}) {
      final t = seed.text.trim();
      if (t.length < 8 || t.length > 64) return;
      if (_looksTechnicalOnly(t) || _looksFakeClaim(t)) return;
      if (audiences.isNotEmpty && !_compatibleWithAudiences(seed, audiences)) {
        return;
      }
      if (audiences.isNotEmpty &&
          requireAudienceMatch &&
          !_matchesSelectedAudiences(seed, audiences)) {
        return;
      }
      final key = t.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (!seen.add(key)) return;
      final bucket = seed.audienceTags.isEmpty ? neutral : matched;
      if (_nearDuplicate([...matched, ...neutral], t)) return;
      bucket.add(t);
    }

    // Pass 1: audience-tagged matches first (drives TOP10).
    for (final s in seeds) {
      if (s.audienceTags.isEmpty) continue;
      consider(s, requireAudienceMatch: audiences.isNotEmpty);
    }
    // Pass 2: neutral fillers only after audience pool, still foreign-filtered.
    for (final s in seeds) {
      if (s.audienceTags.isNotEmpty) continue;
      consider(s, requireAudienceMatch: false);
    }

    final ordered = <String>[...matched, ...neutral];
    if (ordered.isEmpty) {
      return _fallback(art, audiences).take(capped).toList(growable: false);
    }
    return ordered.take(capped).toList(growable: false);
  }

  static List<String> _normalizeAudiences(List<String> audienceIds) {
    return audienceIds
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'custom')
        .toList();
  }

  static bool _isOfficeAudience(String a) =>
      a == 'office' || a.contains('직장') || a.contains('office');

  static bool _isSmbAudience(String a) =>
      a == 'smb' ||
      a.contains('소상공') ||
      a.contains('자영') ||
      a.contains('사장님') ||
      a.contains('local');

  static bool _isSeniorAudience(String a) =>
      a.contains('age_40') ||
      a.contains('age_60') ||
      a.contains('중장년') ||
      a.contains('50') ||
      a.contains('senior') ||
      a.contains('retire') ||
      a.contains('부모');

  static bool _isStudentAudience(String a) =>
      a.contains('student') || a.contains('학생') || a.contains('학습');

  static bool _isIndustrialAudience(String a) =>
      a.contains('factory') ||
      a.contains('plant') ||
      a.contains('manufact') ||
      a.contains('생산') ||
      a.contains('보전') ||
      a.contains('유지');

  static bool _matchesSelectedAudiences(
    _TitleSeed seed,
    List<String> selected,
  ) {
    if (seed.audienceTags.isEmpty) return false;
    return seed.audienceTags.any(selected.contains) ||
        selected.any((a) {
          if (_isOfficeAudience(a) && seed.audienceTags.contains('office')) {
            return true;
          }
          if (_isSmbAudience(a) && seed.audienceTags.contains('smb')) {
            return true;
          }
          if (_isSeniorAudience(a) && seed.audienceTags.contains('senior')) {
            return true;
          }
          if (_isStudentAudience(a) && seed.audienceTags.contains('student')) {
            return true;
          }
          if (_isIndustrialAudience(a) &&
              seed.audienceTags.contains('industrial')) {
            return true;
          }
          return seed.audienceTags.any((t) => a.contains(t) || t.contains(a));
        });
  }

  /// Drop titles that are exclusive to a non-selected audience family.
  static bool _compatibleWithAudiences(_TitleSeed seed, List<String> selected) {
    if (seed.audienceTags.isEmpty) {
      // Keyword hard-block for exclusive foreign phrases.
      return !_hasForeignExclusiveKeywords(seed.text, selected);
    }
    return _matchesSelectedAudiences(seed, selected);
  }

  static bool _hasForeignExclusiveKeywords(String text, List<String> selected) {
    final officeOnly =
        selected.every(_isOfficeAudience) &&
        selected.isNotEmpty &&
        !selected.any(
          (a) =>
              _isSmbAudience(a) ||
              _isSeniorAudience(a) ||
              _isStudentAudience(a) ||
              _isIndustrialAudience(a),
        );
    if (!officeOnly) return false;
    final foreign = RegExp(r'(50대|중장년|자영업|사장님|소상공|부모님|취미|학부모|학생)');
    return foreign.hasMatch(text);
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

  static List<_TitleSeed> _seedsFor(String art, String site) {
    if (art == ArtifactType.app) {
      return const [
        _TitleSeed('공장 설비가 멈추기 전에 먼저 알려주는 스마트 모니터링', ['industrial']),
        _TitleSeed('현장 직원이 태블릿으로 바로 점검하는 설비 일지', ['industrial']),
        _TitleSeed('고장 원인을 찾기 쉽게 정리해 주는 보전 도우미', ['industrial']),
        _TitleSeed('교대 근무자가 인계를 놓치지 않게 돕는 현장 메모', ['industrial']),
        _TitleSeed('품질 이상 신호를 한눈에 모아 보는 라인 보드', ['industrial']),
        _TitleSeed('부모님도 큰 글씨로 쓰는 복약·병원 일정 앱', ['senior']),
        _TitleSeed('바쁜 사장님이 주문·재고를 한 화면에서 보는 가게 앱', ['smb']),
        _TitleSeed('퇴근 후 할 일을 덜 복잡하게 만드는 직장인 도우미', ['office']),
        _TitleSeed('회의·마감을 한눈에 정리하는 직장인 일정 보드', ['office']),
        _TitleSeed('출퇴근길에도 빠르게 보고하는 모바일 업무 앱', ['office']),
        _TitleSeed('팀 공지를 놓치지 않게 모아 주는 직장 협업 보드', ['office']),
        _TitleSeed('초보도 헤매지 않는 단계별 학습 연습 앱', ['student']),
        _TitleSeed('하루 일정을 덜 복잡하게 만드는 생활 도우미', []),
        _TitleSeed('사진 한 장으로 이상 여부를 남기는 점검 앱', ['industrial']),
        _TitleSeed('알람이 쌓여도 우선순위가 보이는 알림 정리 앱', ['office']),
        _TitleSeed('거래처 연락을 놓치지 않게 돕는 미니 CRM', ['smb']),
        _TitleSeed('교육 진도를 스스로 확인하는 학습 트래커', ['student']),
        _TitleSeed('이동 중에도 빠르게 보고하는 모바일 업무 앱', ['office']),
      ];
    }
    if (art == ArtifactType.ebook) {
      return const [
        _TitleSeed('50대 초보자가 AI로 첫 전자책을 만드는 방법', ['senior']),
        _TitleSeed('바쁜 직장인이 퇴근 후 한 장씩 끝내는 실무 입문', ['office']),
        _TitleSeed('자영업자가 고객 질문을 책으로 정리하는 법', ['smb']),
        _TitleSeed('처음 시작하는 사람을 위한 쉬운 용어 해설집', []),
        _TitleSeed('실패를 줄이는 체크리스트형 실전 가이드', []),
        _TitleSeed('하루 20분으로 따라 하는 기초 실습 노트', ['office']),
        _TitleSeed('현장에서 바로 쓰는 질문·답변 모음집', ['office']),
        _TitleSeed('초보 실무자가 헤매지 않게 돕는 단계별 매뉴얼', ['office']),
        _TitleSeed('중장년이 스스로 배우는 생활 기술 입문서', ['senior']),
        _TitleSeed('취미를 결과물로 바꾸는 작은 프로젝트 가이드', ['senior']),
        _TitleSeed('고객이 자주 묻는 것만 모아 둔 친절한 FAQ 북', ['smb']),
        _TitleSeed('처음 계약·견적 전에 알아둘 실무 포인트', ['smb']),
        _TitleSeed('혼자 준비해도 덜 막히는 시작 로드맵', []),
        _TitleSeed('사례 중심으로 이해하는 쉬운 업무 이야기', ['office']),
        _TitleSeed('복잡한 절차를 그림처럼 풀어 쓴 안내서', []),
        _TitleSeed('퇴근 후 AI로 첫 전자책 만드는 방법', ['office']),
        _TitleSeed('직장 경험을 책으로 정리하는 자기계발 입문', ['office']),
        _TitleSeed('바쁜 직장인을 위한 부업 아이디어 정리 노트', ['office']),
        _TitleSeed('회의 전에 한 장으로 읽는 실무 요약 가이드', ['office']),
        _TitleSeed('야근 대신 짧게 끝내는 업무 스킬 입문서', ['office']),
        _TitleSeed('출퇴근 시간에 읽는 직장인 실무 팁집', ['office']),
        _TitleSeed('팀 업무를 덜 복잡하게 만드는 실전 체크리스트', ['office']),
        _TitleSeed('이직·성장이 궁금한 직장인을 위한 로드맵', ['office']),
        _TitleSeed('보고서 쓰기를 덜 막히게 하는 직장인 가이드', ['office']),
        _TitleSeed('자기계발을 미루지 않게 돕는 퇴근 후 학습법', ['office']),
        _TitleSeed('업무 경험을 콘텐츠로 바꾸는 직장인 워크북', ['office']),
        _TitleSeed('점심시간에 끝내는 짧은 실무 학습 노트', ['office']),
        _TitleSeed('직장인이 혼자 따라 하는 AI 활용 입문', ['office']),
        _TitleSeed('메일·문서 시간을 줄이는 실무 글쓰기 가이드', ['office']),
        _TitleSeed('부업보다 먼저 정리하는 직장인 스킬 맵', ['office']),
        _TitleSeed('승진 전에 알아두면 좋은 실무 포인트 모음', ['office']),
        _TitleSeed('야근을 줄이는 우선순위 정리법 입문서', ['office']),
        _TitleSeed('직장 고민을 문장으로 정리하는 자기계발 노트', ['office']),
        _TitleSeed('회의록을 짧게 남기는 직장인 기록법', ['office']),
        _TitleSeed('업무 자동화 전에 읽는 쉬운 AI 입문', ['office']),
        _TitleSeed('퇴근 후 20분 학습으로 쌓는 실무 습관', ['office']),
        _TitleSeed('직장인이 처음 쓰는 전자책 기획 체크리스트', ['office']),
        _TitleSeed('경험은 많은데 정리가 안 될 때 쓰는 실무 노트', ['office']),
        _TitleSeed('바쁜 일정 속에서도 이어가는 자기계발 가이드', ['office']),
        _TitleSeed('팀 협업을 덜 피곤하게 만드는 실무 매뉴얼', ['office']),
      ];
    }
    if (art == ArtifactType.site) {
      if (site.contains('marketing') || site.contains('promo')) {
        return const [
          _TitleSeed('지역 사장님이 서비스와 가격을 바로 알리는 소개 사이트', ['smb']),
          _TitleSeed('상담 문의가 자연스럽게 이어지는 친절한 랜딩', ['smb']),
          _TitleSeed('제품 특징을 한 화면에서 이해시키는 소개 페이지', []),
          _TitleSeed('방문자가 다음 행동을 고민하지 않는 전환 중심 사이트', []),
          _TitleSeed('후기·사례 없이도 신뢰가 느껴지는 회사 소개', []),
          _TitleSeed('모바일에서도 읽기 쉬운 지역 사업 홍보 페이지', ['smb']),
          _TitleSeed('견적 요청 전에 궁금증을 풀어 주는 안내 사이트', ['smb']),
          _TitleSeed('서비스 범위를 과장 없이 보여주는 솔직한 소개', []),
          _TitleSeed('첫 방문자가 30초 안에 이해하는 홈 메시지', []),
          _TitleSeed('문의 버튼이 눈에 들어오지만 부담스럽지 않은 페이지', ['smb']),
          _TitleSeed('제조·현장 고객이 찾아도 전문성이 보이는 소개', ['industrial']),
          _TitleSeed('온라인 판매자가 상품 가치를 짧게 설명하는 페이지', ['smb']),
          _TitleSeed('개인 브랜드를 차분하게 소개하는 미니 사이트', ['office']),
          _TitleSeed('가격·일정·연락처가 한곳에 모인 실용 소개', ['smb']),
          _TitleSeed('상담 전에 자주 묻는 질문을 먼저 보여주는 안내', ['smb']),
        ];
      }
      return const [
        _TitleSeed('현장 담당자가 용어·절차를 바로 찾는 실무 지식 허브', ['office']),
        _TitleSeed('초보도 헤매지 않는 단계별 학습 사이트', ['student']),
        _TitleSeed('검색하면 바로 답이 나오는 친절한 FAQ 허브', []),
        _TitleSeed('바쁜 직장인이 짧은 글로 배우는 실무 가이드', ['office']),
        _TitleSeed('학부모가 이해하기 쉬운 학습 안내 사이트', ['senior']),
        _TitleSeed('중장년 학습자를 위한 큰 글씨·쉬운 설명 허브', ['senior']),
        _TitleSeed('자격 준비를 스스로 점검하는 학습 로드맵 사이트', ['student']),
        _TitleSeed('흩어진 자료를 주제별로 모아 둔 지식 도서관', []),
        _TitleSeed('실무 질문이 쌓일수록 더 쓸모 있어지는 Q&A', ['office']),
        _TitleSeed('처음 온 사람도 길을 잃지 않는 카테고리 구조', []),
        _TitleSeed('현장 사례를 과장 없이 정리한 학습 자료실', ['office']),
        _TitleSeed('검색·목차로 바로 이동하는 실전 매뉴얼 사이트', ['office']),
        _TitleSeed('팀 공통 지식을 한곳에 모으는 사내 학습 허브', ['office']),
        _TitleSeed('초보 질문에 먼저 답하는 입문 지식관', ['student']),
        _TitleSeed('전문 용어를 일상어로 풀어 주는 해설 사이트', []),
      ];
    }
    return const [
      _TitleSeed('제품 특징을 30초 안에 이해시키는 쇼츠 시리즈', []),
      _TitleSeed('초보도 따라 하는 짧은 실습 영상 시리즈', ['student']),
      _TitleSeed('하루 일과에 자연스럽게 붙는 짧은 팁 콘텐츠', ['office']),
      _TitleSeed('고객 고민을 장면으로 보여주는 스토리 숏폼', ['smb']),
      _TitleSeed('복잡한 기능을 한 장면씩 풀어 주는 설명 영상', []),
      _TitleSeed('현장 분위기가 느껴지는 짧은 데모 클립', ['industrial']),
      _TitleSeed('질문이 생기기 전에 답하는 FAQ 숏폼', []),
      _TitleSeed('음악과 함께 분위기를 전하는 브랜드 클립', []),
      _TitleSeed('만화처럼 읽히는 가벼운 안내 콘텐츠', []),
      _TitleSeed('홍보가 아닌 이해부터 돕는 소개 시리즈', ['smb']),
      _TitleSeed('바쁜 사람이 Scrub 없이 보는 핵심 요약 영상', ['office']),
      _TitleSeed('서비스 이용 전 꼭 볼 체크 포인트 숏폼', []),
      _TitleSeed('고객 언어로 말하는 친절한 안내 클립', ['smb']),
      _TitleSeed('한 주 주제만 깊게 다루는 미니 시리즈', []),
      _TitleSeed('공유하고 싶어지는 짧고 명확한 팁 카드', ['office']),
    ];
  }

  static List<_TitleSeed> _audienceSeeds(String art, List<String> audiences) {
    final out = <_TitleSeed>[];
    for (final a in audiences) {
      if (_isIndustrialAudience(a)) {
        out.addAll(const [
          _TitleSeed('설비 담당자가 아침에 먼저 열어보는 이상 신호 보드', ['industrial']),
          _TitleSeed('생산 라인이 멈춘 이유를 더 빨리 찾아주는 현장 도우미', ['industrial']),
          _TitleSeed('보전 일지를 적기 쉽게 만드는 모바일 점검 흐름', ['industrial']),
          _TitleSeed('교대 인수인계가 빠지지 않게 돕는 현장 체크', ['industrial']),
          _TitleSeed('품질 이상 사진을 바로 남기는 간단한 보고 도구', ['industrial']),
        ]);
      }
      if (_isSeniorAudience(a)) {
        out.addAll(const [
          _TitleSeed('글씨가 크고 버튼이 여유로운 초보 친화 안내', ['senior']),
          _TitleSeed('처음 쓰는 사람도 헤매지 않는 쉬운 시작 화면', ['senior']),
          _TitleSeed('자녀에게 묻지 않아도 따라 할 수 있는 단계 안내', ['senior']),
        ]);
      }
      if (_isSmbAudience(a)) {
        out.addAll(const [
          _TitleSeed('사장님이 바쁠 때도 문의 내용을 놓치지 않는 안내', ['smb']),
          _TitleSeed('가게 소식을 짧게 알리고 상담으로 이어주는 소개', ['smb']),
          _TitleSeed('가격·영업시간을 손님에게 바로 보여주는 페이지', ['smb']),
        ]);
      }
      if (_isStudentAudience(a)) {
        out.addAll(const [
          _TitleSeed('오늘 배울 것만 보이는 짧은 학습 로드맵', ['student']),
          _TitleSeed('복습이 부담스럽지 않은 한 장 요약 자료', ['student']),
        ]);
      }
      if (_isOfficeAudience(a) && art == ArtifactType.ebook) {
        out.addAll(const [
          _TitleSeed('직장인이 퇴근 후 쓰는 실무 전자책 시작법', ['office']),
          _TitleSeed('업무 시간을 아끼는 한 장 요약형 실전 노트', ['office']),
          _TitleSeed('자기계발을 결과로 남기는 직장인 전자책 가이드', ['office']),
          _TitleSeed('점심 휴게시간에 끝내는 짧은 업무 정리법', ['office']),
          _TitleSeed('상사 보고 전에 읽는 한 장 핵심 정리', ['office']),
          _TitleSeed('직장 메일을 덜 오래 쓰는 실무 문장 가이드', ['office']),
          _TitleSeed('야근을 줄이는 할 일 정리 습관 입문서', ['office']),
          _TitleSeed('이직 준비 전에 정리하는 경력 스토리 노트', ['office']),
          _TitleSeed('회의를 짧게 끝내는 안건 작성 실전법', ['office']),
          _TitleSeed('팀 협업 갈등을 줄이는 직장 커뮤니케이션', ['office']),
          _TitleSeed('성과 리뷰 전에 읽는 자기평가 작성법', ['office']),
          _TitleSeed('출장·외근 중에도 이어가는 학습 습관', ['office']),
          _TitleSeed('직장인이 AI로 자료 조사를 빠르게 하는 법', ['office']),
          _TitleSeed('부서 공통 지식을 책으로 남기는 실무 템플릿', ['office']),
          _TitleSeed('연말 정산·문서 업무를 덜 헤매는 체크 가이드', ['office']),
        ]);
      }
    }
    return out;
  }

  static List<_TitleSeed> get _industrialSeeds => const [
    _TitleSeed('공장 설비가 멈추기 전에 먼저 알려주는 스마트 모니터링', ['industrial']),
    _TitleSeed('중소 공장이 상담부터 유지보수까지 한곳에서 받는 자동화 창구', ['industrial']),
    _TitleSeed('생산기술 담당자가 라인 이상을 바로 공유하는 현장 보드', ['industrial']),
    _TitleSeed('설비보전 팀이 점검 순서를 놓치지 않게 돕는 일지 앱', ['industrial']),
    _TitleSeed('품질 이상 사진을 즉시 남기는 간단한 보고 흐름', ['industrial']),
    _TitleSeed('자동화 담당자가 여러 업체를 비교하기 쉽게 정리한 상담 가이드', ['industrial']),
    _TitleSeed('교대 근무 인계가 빠지지 않게 돕는 현장 체크', ['industrial']),
    _TitleSeed('중소 제조 대표가 현황을 한눈에 보는 운영 요약', ['industrial']),
    _TitleSeed('설비가 왜 멈췄는지 더 빨리 찾는 보전 도우미', ['industrial']),
    _TitleSeed('라인별 알람을 우선순위로 정리해 주는 알림 보드', ['industrial']),
  ];

  static List<String> _fallback(String art, List<String> audiences) {
    if (audiences.any(_isOfficeAudience) && art == ArtifactType.ebook) {
      return const ['바쁜 직장인이 퇴근 후 한 장씩 끝내는 실무 입문'];
    }
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
}

class _TitleSeed {
  const _TitleSeed(this.text, this.audienceTags);
  final String text;
  final List<String> audienceTags;
}
