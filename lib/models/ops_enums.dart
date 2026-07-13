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

/// 배포 단계 상태
class DeployStepStatus {
  static const notChecked = 'not_checked';
  static const success = 'success';
  static const failed = 'failed';
  static const notRequired = 'not_required';

  static const values = [notChecked, success, failed, notRequired];

  static String labelKo(String code) {
    switch (code) {
      case notChecked:
        return '미확인';
      case success:
        return '성공';
      case failed:
        return '실패';
      case notRequired:
        return '해당 없음';
      default:
        return '확인 필요';
    }
  }

  /// 구 bool 필드 호환
  static String fromBool(bool? v, {bool required = true}) {
    if (v == true) return success;
    if (v == false) return required ? notChecked : notRequired;
    return notChecked;
  }
}

class IdeaStatus {
  static const idea = 'idea';
  static const reviewing = 'reviewing';
  static const selected = 'selected';
  static const onHold = 'on_hold';
  static const rejected = 'rejected';
  static const inDevelopment = 'in_development';

  static String labelKo(String code) {
    switch (code) {
      case idea:
        return '아이디어';
      case reviewing:
        return '검토 중';
      case selected:
        return '채택';
      case onHold:
        return '보류';
      case rejected:
        return '폐기';
      case inDevelopment:
        return '개발 진행';
      default:
        return '확인 필요';
    }
  }
}
