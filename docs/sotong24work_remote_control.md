# 소통24워크 원격 관제 (소통총관제 ↔ PC Sotong24Work)

## 역할 구분

| 구성 | 역할 |
|------|------|
| 소통총관제 메뉴 **소통24워크** (`productWorkshop`) | 휴대폰/웹 원격 관제·승인 UI |
| PC **Sotong24Work** (MFC) | 실제 제작 엔진 |
| 보관 메뉴 **소통24워크 사업부** (`sotong24work`) | 기존 Ops 사업부 대시보드 (유지) |
| 작업지시 제작소 Inbox 전달 | PC 로컬 Inbox 파일 전달 (기존 유지) |

GitHub는 소스/버전 관리용이며, 실시간 승인 통신에는 사용하지 않습니다.

## Firestore 컬렉션 (신규, 기존 컬렉션 비파괴)

```text
sotong24work_projects/{projectId}
  title, productType, contentSubtype
  currentStage, totalStages, progress
  status, approvalStatus
  pcStatus, lastHeartbeat
  createdAt, updatedAt, startedAt, isDemo

  stages/{stageId}
    stageNumber, stageName, status
    summary, resultPreview, workReport, errorMessage, userAttention
    resultUrl, previewUrl   # http(s)만 모바일에서 오픈
    approvalRequired, approvalStatus, activeRequestId, updatedAt

  requests/{requestId}
    projectId, stageId, requestType  # approve | revision_request
    status  # pending | approved | revision_requested
    message, createdAt, updatedAt, processedAt
```

승인해도 배포·판매 등록·Git push는 자동 실행하지 않습니다.
PC가 `requests`를 읽고 다음 단계를 진행합니다.

## PC Heartbeat

MFC가 주기적으로 `lastHeartbeat`(ISO8601 UTC)와 `pcStatus`를 갱신하면
웹은 2분 이내 온라인 / 10분 이내 연결 지연 / 그 외 오프라인으로 표시합니다.

**이번 작업 범위:** 소통총관제 모델·UI·승인 저장. MFC 쓰기 연동은 후속 작업.

## 데모 데이터

Firebase 미연결 또는 프로젝트 문서가 비어 있으면 `isDemo: true` 샘플을 표시합니다.
실제 제품 문서와 구분되며, 기존 데이터를 삭제·마이그레이션하지 않습니다.
