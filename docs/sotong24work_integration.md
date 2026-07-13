# 소통24워크 → 소통총관제 연동 스키마 (준비)

현재 **자동 연동은 미구현**입니다.

```text
소통24워크 직접 자동 전송: 준비 중
현재 사용 가능 방식: JSON 가져오기 (관리자 승인형)
```

안전한 향후 방식:
- Firebase Auth + HTTPS Cloud Function (관리자 전용)
- 관리자 승인형 JSON 가져오기 (현재 제공)

## 연동 요청 데이터 모델

```json
{
  "projectId": "",
  "moduleId": "",
  "currentStage": 0,
  "totalStages": 0,
  "progress": 0,
  "workTitle": "",
  "requestSummary": "",
  "resultSummary": "",
  "changedFiles": [],
  "analyzeResult": "",
  "testResult": "",
  "buildResult": "",
  "commitHash": "",
  "gitPushed": false,
  "firebaseDeployed": false,
  "siteVerified": false,
  "siteUrl": "",
  "nextAction": "",
  "errors": [],
  "workedAt": ""
}
```

관리자 화면의 「소통24 JSON 승인 가져오기」에서 검증 → 미리보기 → 승인 → Firestore 반영합니다.
