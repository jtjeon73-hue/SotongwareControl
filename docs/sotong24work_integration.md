# 소통24워크 → 소통총관제 연동 스키마 (준비)

현재 **자동 연동은 미구현**입니다. 소통24워크가 작업 완료 후
Firestore `work_logs` / `projects` / `deployments` 로 상태를 전달할 때
아래 필드를 사용하십시오.

## work_logs 문서 예시

```json
{
  "projectId": "sotong24_app_auto",
  "businessUnitId": "sotong24work",
  "workType": "cursor",
  "title": "앱개발자동화 화면 골격",
  "requestSummary": "요청 요약",
  "resultSummary": "수정 결과 요약",
  "changedFiles": ["path/a.dart"],
  "testResult": "passed|failed|skipped|미등록",
  "buildResult": "passed|failed|skipped|미등록",
  "commitHash": "",
  "source": "sotong24work",
  "nextAction": "다음 작업",
  "workedAt": "<timestamp>"
}
```

## projects 업데이트 권장 필드

- currentStage
- progress 또는 completedStages / totalStages
- status (`not_started` | `planning` | `in_progress` | `testing` | `blocked` | `on_hold` | `completed` | `maintenance`)
- nextAction
- lastWorkedAt

## deployments 문서

검사·테스트·빌드·커밋·푸시·Firebase·사이트 확인이 **모두 true**일 때만 완료로 표시합니다.

## 출처 코드

- `manual` 수동 등록
- `github` GitHub 커밋
- `json_import` JSON 가져오기
- `sotong24work` 소통24워크 연동
- `system` 시스템 생성

자동 연동이 연결되기 전에는 UI에 「자동 연동 완료」로 표시하지 마십시오.
