import '../models/artifact_type.dart';
import '../models/sotong24_guide_models.dart';
import 'sotong24_guide_enrichments.dart';
import 'sotong24_workflows.dart';

/// 사업별 표준 제작 가이드 — workflow(SSOT) + stageId 보강 메타.
class Sotong24ProductionGuideCatalog {
  Sotong24ProductionGuideCatalog._();

  static const productIds = <String>[
    'ebook',
    'app',
    'industrial',
    'site',
    'promo_site',
    'contents',
  ];

  static String labelKo(String id) {
    switch (id) {
      case 'ebook':
        return '전자책';
      case 'app':
        return '앱';
      case 'industrial':
        return '산업자동화SW';
      case 'site':
        return '지식사이트';
      case 'promo_site':
        return '마케팅사이트';
      case 'contents':
        return '콘텐츠';
      default:
        return id;
    }
  }

  static Sotong24ProductGuide guideFor(
    String productId, {
    String contentSubtype = '',
  }) {
    final workflow = _workflowFor(productId, contentSubtype: contentSubtype);
    final meta = _productMeta(productId);
    final enrichments = Sotong24GuideEnrichments.forProduct(productId);
    final stages = <Sotong24StageGuide>[
      for (final s in workflow.stages)
        Sotong24StageGuide(
          stage: s,
          enrichment:
              enrichments[s.id] ?? Sotong24StageGuideEnrichment.fromStage(s),
        ),
    ];
    return Sotong24ProductGuide(
      id: productId,
      label: labelKo(productId),
      guideTitle: meta.guideTitle,
      goal: meta.goal,
      flowOverview: meta.flowOverview,
      keyDeliverables: meta.keyDeliverables,
      checklist: meta.checklist,
      workflow: workflow,
      stages: stages,
      contentSubtype: contentSubtype,
      subtypeNotes: productId == 'contents' ? _contentsSubtypeNotes : const {},
    );
  }

  static Sotong24WorkflowDef _workflowFor(
    String productId, {
    String contentSubtype = '',
  }) {
    if (productId == 'industrial') {
      return Sotong24WorkflowCatalog.industrial;
    }
    if (productId == 'contents') {
      return Sotong24WorkflowCatalog.contentsFor(contentSubtype);
    }
    return Sotong24WorkflowCatalog.resolve(productType: productId);
  }

  static ({
    String guideTitle,
    String goal,
    List<String> flowOverview,
    List<String> keyDeliverables,
    List<String> checklist,
  })
  _productMeta(String id) {
    switch (id) {
      case 'ebook':
        return (
          guideTitle: '전자책 표준 제작 가이드',
          goal: '아이디어를 검증하고 가치 있는 원고를 제작하여 PDF 상품화, 판매 등록, 홍보, 운영까지 연결한다.',
          flowOverview: const [
            '아이디어',
            '검증',
            '기획',
            '자료준비',
            '원고작성',
            '검토',
            '편집',
            '품질검사',
            '상품화',
            '판매준비',
            '출시',
            '운영',
          ],
          keyDeliverables: const [
            '기획서',
            '검증자료',
            '원고',
            '표지',
            'PDF',
            '판매페이지 자료',
            '홍보자료',
          ],
          checklist: const [
            '기획 완료',
            '시장/문제 검증',
            '목차 확정',
            '원고 초안',
            '사실 검증',
            '저작권/출처 검사',
            '품질검사',
            '판매 등록자료',
            '가격·설명 확정',
            '홍보자료',
            '출시 승인',
            '백업·유지',
          ],
        );
      case 'app':
        return (
          guideTitle: '앱 표준 제작 가이드',
          goal: '사용자 문제를 Android MVP로 구현하고 설치 가능한 APK와 출시 전 검토 패키지까지 완성한다.',
          flowOverview: const [
            '아이디어',
            '시장',
            'MVP',
            '설계',
            '개발',
            '연동',
            '테스트',
            'APK',
            '실기기 검토',
            '보완',
            'Production Complete',
          ],
          keyDeliverables: const [
            '요구사항',
            'UX/UI',
            'Flutter 소스',
            'Release APK',
            '설치 안내',
            '테스트 체크리스트',
            '출시 준비자료',
          ],
          checklist: const [
            '문제·타깃 확정',
            'MVP 기능 확정',
            '보안·인증',
            'flutter analyze·test 통과',
            'Release APK 검증',
            '휴대폰 설치 안내',
            '실기기 체크리스트',
            '보완 revision 보존',
            'Production/Launch 분리',
            '외부 공개 NOT STARTED',
          ],
        );
      case 'industrial':
        return (
          guideTitle: '산업자동화SW 표준 제작 가이드',
          goal: '현장 요구·통신·데이터·시운전·납품·유지보수까지 현장 프로젝트를 안정적으로 완료한다.',
          flowOverview: const [
            '요구분석',
            '공정',
            '통신',
            'I/O',
            '설계',
            '개발',
            '시뮬',
            '시운전',
            '검수',
            '백업',
            '납품',
            '유지',
          ],
          keyDeliverables: const [
            '요구사항서',
            'I/O List',
            '통신 사양',
            'HMI',
            '프로그램',
            'PLC 백업',
            '매뉴얼',
            '변경이력',
          ],
          checklist: const [
            '고객 요구·CT/품질',
            'PLC/설비 구성',
            '통신(Modbus/OPC 등)',
            'I/O·Address',
            '이상 시나리오',
            '안전 인터록',
            'FAT/시운전',
            '사용자 검수',
            '프로그램·PLC 백업',
            '매뉴얼·납품',
          ],
        );
      case 'site':
        return (
          guideTitle: '지식사이트 표준 제작 가이드',
          goal: '전문 주제로 신뢰 가능한 콘텐츠 구조·SEO·배포·운영을 만든다.',
          flowOverview: const [
            '주제',
            '독자',
            '수요',
            'IA',
            '콘텐츠',
            '개발',
            'SEO',
            '배포',
            '운영',
          ],
          keyDeliverables: const [
            'IA',
            '콘텐츠',
            'SEO 설정',
            'Analytics',
            '공개 URL',
            '업데이트 계획',
          ],
          checklist: const [
            '주제·독자',
            '검색 수요',
            'IA/메뉴',
            '출처·신뢰도',
            'SEO·구조화 데이터',
            '모바일·성능',
            '배포 승인',
            'Search Console',
            '오래된 정보 관리',
          ],
        );
      case 'promo_site':
        return (
          guideTitle: '마케팅사이트 표준 제작 가이드',
          goal: '방문 → 관심 → 신뢰 → 행동 → 구매/문의 전환을 설계·측정·개선한다.',
          flowOverview: const [
            '상품',
            '고객',
            'USP',
            '카피',
            'CTA',
            '개발',
            '측정',
            '유입',
            '전환개선',
          ],
          keyDeliverables: const [
            'USP',
            '랜딩 카피',
            'CTA',
            '증거/FAQ',
            'UTM/Analytics',
            '전환 이벤트',
          ],
          checklist: const [
            'Offer·가격',
            'USP',
            'Hero·CTA',
            '신뢰 증거',
            '모바일 전환',
            'UTM·Analytics',
            '전환 추적',
            '배포 승인',
            'A/B·CVR 개선',
          ],
        );
      case 'contents':
        return (
          guideTitle: '콘텐츠 표준 제작 가이드',
          goal: '트렌드·Hook·제작·저작권·업로드·분석까지 반복 가능한 콘텐츠 파이프라인을 만든다.',
          flowOverview: const [
            '트렌드',
            '주제',
            'Hook',
            '대본',
            '제작',
            '편집',
            '메타',
            '업로드',
            '분석',
            '후속',
          ],
          keyDeliverables: const [
            '대본/가사',
            '음원/영상',
            '썸네일',
            '제목·태그',
            '업로드 기록',
            '성과 분석',
          ],
          checklist: const [
            '타깃·주제',
            'Hook(1~3초)',
            '저작권 클리어',
            '편집·자막',
            '플랫폼 정책',
            '업로드 승인',
            '조회/유지율 분석',
            '후속 기획',
          ],
        );
      default:
        return (
          guideTitle: '표준 제작 가이드',
          goal: '사업별 표준 제작 절차를 확인합니다.',
          flowOverview: const ['기획', '제작', '검사', '출시', '운영'],
          keyDeliverables: const ['단계 산출물'],
          checklist: const ['기획 완료', '품질검사', '배포 승인'],
        );
    }
  }

  static const _contentsSubtypeNotes = <String, List<String>>{
    ContentSubtype.shorts: [
      '첫 1~3초 Hook이 유지율의 핵심이다.',
      '짧은 전달·자막 가독성·세로 비율을 확인한다.',
      '클릭베이트성 허위 썸네일을 쓰지 않는다.',
    ],
    ContentSubtype.song: [
      '가사·멜로디·보컬·샘플의 저작권/배포권을 확인한다.',
      '음원 배포 채널(플랫폼) 정책을 점검한다.',
      '크레딧·라이선스 문구를 남긴다.',
    ],
    ContentSubtype.songAndShorts: [
      '음원과 쇼츠 메시지가 같은 훅·세계관을 공유하는지 확인한다.',
      '쇼츠 CTA가 음원/채널로 자연스럽게 연결되는지 본다.',
    ],
    ContentSubtype.video: ['영상 길이·챕터·자막·음량 정규화를 점검한다.'],
    ContentSubtype.other: ['유형별 플랫폼 정책과 포맷을 별도 체크한다.'],
  };
}
