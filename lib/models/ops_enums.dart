/// 프로젝트 진행 상태 (일관 코드)
class ProjectStatus {
  static const notStarted = 'not_started';
  static const planning = 'planning';
  static const inProgress = 'in_progress';
  static const testing = 'testing';
  static const blocked = 'blocked';
  static const onHold = 'on_hold';
  static const completed = 'completed';
  static const maintenance = 'maintenance';

  static String labelKo(String code) {
    switch (code) {
      case notStarted:
        return '아직 시작하지 않음';
      case planning:
        return '설계·준비';
      case inProgress:
        return '진행 중';
      case testing:
        return '테스트 중';
      case blocked:
        return '문제 발생';
      case onHold:
        return '보류';
      case completed:
        return '완료';
      case maintenance:
        return '유지보수';
      default:
        return '확인 필요';
    }
  }
}

class TaskStatus {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const waiting = 'waiting';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static String labelKo(String code) {
    switch (code) {
      case todo:
        return '할 일';
      case inProgress:
        return '진행 중';
      case waiting:
        return '대기';
      case completed:
        return '완료';
      case cancelled:
        return '취소';
      default:
        return '확인 필요';
    }
  }
}

class WorkLogSource {
  static const manual = 'manual';
  static const github = 'github';
  static const jsonImport = 'json_import';
  static const sotong24 = 'sotong24work';
  static const system = 'system';

  static String labelKo(String code) {
    switch (code) {
      case manual:
        return '수동 등록';
      case github:
        return 'GitHub 커밋';
      case jsonImport:
        return 'JSON 가져오기';
      case sotong24:
        return '소통24워크 연동';
      case system:
        return '시스템 생성';
      default:
        return code;
    }
  }
}
