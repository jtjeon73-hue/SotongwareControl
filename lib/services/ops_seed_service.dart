import '../models/ops_enums.dart';
import '../models/ops_models.dart';
import 'ops_repository.dart';

/// 확인된 구조·실제 프로젝트만 시드. 가상 수치/완료 상태를 만들지 않음.
class OpsSeedService {
  OpsSeedService(this._repo);

  final OpsRepository _repo;

  Future<String> ensureStructure() async {
    if (await _repo.isStructureSeeded()) {
      return '기본 구조 데이터가 이미 있습니다. 중복 생성하지 않았습니다.';
    }

    final units = <BusinessUnitDoc>[
      const BusinessUnitDoc(
        id: 'sotong24work',
        name: '소통24워크',
        description:
            'MFC 기반 자동화 개발 프로그램. 앱·전자책·마케팅·유튜브·MFC 개발 및 유지관리 핵심 내부 도구.',
        status: '확인 필요',
        currentFocus: '현재 프로젝트 소스 및 진행 단계 확인',
        nextAction: '개발 영역별 상태 등록',
        displayOrder: 1,
      ),
      const BusinessUnitDoc(
        id: 'industrial_automation',
        name: '산업자동화사업부',
        description: '현장 개발, PLC·센서 연동, MFC, 설비 모니터링, 유지보수.',
        status: '확인 필요',
        currentFocus: '등록된 현장 프로젝트 확인',
        nextAction: '실제 프로젝트 등록',
        displayOrder: 2,
      ),
      const BusinessUnitDoc(
        id: 'app_development',
        name: '앱개발사업부',
        description: 'Flutter 앱 개발, APK, Play Store, 프로모 사이트.',
        status: '진행 중',
        currentFocus: '확인된 앱 프로젝트 상태 정리',
        nextAction: '각 앱 진행 단계·배포 상태 등록',
        displayOrder: 3,
      ),
      const BusinessUnitDoc(
        id: 'content_music',
        name: '콘텐츠·음악사업부',
        description: '유튜브·음악·영상·쇼츠·썸네일·업로드·수익화.',
        status: '아직 시작하지 않음',
        currentFocus: '등록된 콘텐츠 없음',
        nextAction: '실제 제작 콘텐츠 등록',
        displayOrder: 4,
      ),
      const BusinessUnitDoc(
        id: 'ebook',
        name: '전자책사업부',
        description: '전자책 기획·제작·판매 채널.',
        status: '사업 준비 단계',
        currentFocus: 'Cursor 작업 내역 없음 · 등록 프로젝트 없음',
        nextAction: '전자책 주제와 목표 독자 등록',
        displayOrder: 5,
      ),
    ];

    for (final u in units) {
      await _repo.upsertBusinessUnit(u);
    }

    // 확인된 앱 프로젝트만 등록 (완료 단정하지 않음)
    final knownApps = <ProjectDoc>[
      const ProjectDoc(
        id: 'app_sotong_travel',
        businessUnitId: 'app_development',
        name: '소통여행',
        projectType: 'flutter_app',
        status: ProjectStatus.inProgress,
        currentStage: '프로모·APK 상태 확인 필요',
        promoUrl: 'https://jtjeon73-hue.github.io/SotongTravelPromo/',
        nextAction: '배포·프로모·테스트 상태 실측 등록',
      ),
      const ProjectDoc(
        id: 'app_farmjigi',
        businessUnitId: 'app_development',
        name: '팜지기',
        projectType: 'flutter_app',
        status: ProjectStatus.inProgress,
        currentStage: '프로모 연결 확인됨 · 앱 진행 단계 확인 필요',
        promoUrl: 'https://jtjeon73-hue.github.io/FarmjigiPromo/',
        nextAction: '현재 개발 단계 확인 후 등록',
      ),
      const ProjectDoc(
        id: 'app_sotong_samae',
        businessUnitId: 'app_development',
        name: '소통사매앱',
        projectType: 'flutter_app',
        status: ProjectStatus.inProgress,
        currentStage: '프로모 저장소 연결 · 앱 고도화 단계 확인 필요',
        promoUrl: 'https://jtjeon73-hue.github.io/SotongSamaePromo/',
        nextAction: '지역 데이터·화면 진행 상태 등록',
      ),
      const ProjectDoc(
        id: 'app_sotong_ai',
        businessUnitId: 'app_development',
        name: '소통AI',
        projectType: 'flutter_app',
        status: ProjectStatus.planning,
        currentStage: '서비스 범위·MVP 정의 확인 필요',
        nextAction: 'MVP 범위 등록',
      ),
      const ProjectDoc(
        id: 'app_sotong_energy',
        businessUnitId: 'app_development',
        name: '소통에너지',
        projectType: 'flutter_app',
        status: ProjectStatus.planning,
        currentStage: '확인 필요',
        nextAction: '저장소·진행 단계 확인',
      ),
      const ProjectDoc(
        id: 'sotong24_app_auto',
        businessUnitId: 'sotong24work',
        name: '앱개발자동화',
        projectType: 'sotong24_module',
        status: ProjectStatus.notStarted,
        currentStage: '확인 필요',
        nextAction: '현재 프로젝트 소스 및 진행 단계 확인',
      ),
      const ProjectDoc(
        id: 'sotong24_ebook_auto',
        businessUnitId: 'sotong24work',
        name: '전자책개발자동화',
        projectType: 'sotong24_module',
        status: ProjectStatus.notStarted,
        currentStage: '확인 필요',
        nextAction: '현재 프로젝트 소스 및 진행 단계 확인',
      ),
      const ProjectDoc(
        id: 'sotong24_marketing_auto',
        businessUnitId: 'sotong24work',
        name: '마케팅개발자동화',
        projectType: 'sotong24_module',
        status: ProjectStatus.notStarted,
        currentStage: '확인 필요',
        nextAction: '현재 프로젝트 소스 및 진행 단계 확인',
      ),
      const ProjectDoc(
        id: 'sotong24_youtube_auto',
        businessUnitId: 'sotong24work',
        name: '유튜브개발자동화',
        projectType: 'sotong24_module',
        status: ProjectStatus.notStarted,
        currentStage: '확인 필요',
        nextAction: '현재 프로젝트 소스 및 진행 단계 확인',
      ),
      const ProjectDoc(
        id: 'sotong24_mfc_auto',
        businessUnitId: 'sotong24work',
        name: 'MFC개발자동화',
        projectType: 'sotong24_module',
        status: ProjectStatus.notStarted,
        currentStage: '확인 필요',
        nextAction: '현재 프로젝트 소스 및 진행 단계 확인',
      ),
      const ProjectDoc(
        id: 'control_center',
        businessUnitId: 'app_development',
        name: '소통총관제 (본 사이트)',
        projectType: 'flutter_web',
        status: ProjectStatus.inProgress,
        currentStage: '운영 관제 Firestore 전환',
        repositoryUrl: 'https://github.com/jtjeon73-hue/SotongwareControl',
        firebaseUrl: 'https://sotongware-control.web.app',
        nextAction: '실데이터 등록·배포 체크리스트 유지',
      ),
    ];

    for (final p in knownApps) {
      await _repo.upsertProject(p, isNew: true);
    }

    // 전자책 권장 절차 = 할 일(완료 아님)
    const ebookSteps = [
      '전자책 주제 선정',
      '목표 독자 설정',
      '제목 후보 작성',
      '목차 구성',
      '자료 수집',
      '본문 초안 작성',
      'AI 검토 및 보완',
      '표지 제작',
      'PDF 및 EPUB 제작',
      '가격 및 판매 채널 결정',
      '상품 소개 페이지 제작',
      '판매 등록 및 홍보',
    ];
    for (var i = 0; i < ebookSteps.length; i++) {
      await _repo.upsertTask(
        TaskDoc(
          id: 'ebook_plan_$i',
          title: ebookSteps[i],
          businessUnitId: 'ebook',
          description: '권장 진행 절차 (아직 완료된 작업이 아님)',
          status: TaskStatus.todo,
          priority: 'normal',
          source: 'system',
        ),
      );
    }

    await _repo.markStructureSeeded();
    return '기본 구조·확인된 프로젝트를 등록했습니다. 가상 완료 수치는 넣지 않았습니다.';
  }
}
