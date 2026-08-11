# 소통24워크 원격 관제 (소통총관제 ↔ PC Sotong24Work)

## 역할 구분

| 구성 | 역할 |
|------|------|
| 소통총관제 메뉴 **소통24워크** (`productWorkshop`) | 휴대폰/웹 원격 관제·승인 UI |
| PC **Sotong24Work** (MFC) | 실제 제작 엔진 |
| Cloud Function **sotong24Relay** | PC → Firestore 최소 권한 HTTPS relay |
| 보관 메뉴 **소통24워크 사업부** (`sotong24work`) | 기존 Ops 사업부 대시보드 (유지) |
| 작업지시 제작소 Inbox 전달 | PC 로컬 Inbox 파일 전달 (기존 유지) |

GitHub는 소스/버전 관리용이며, 실시간 승인 통신에는 사용하지 않습니다.

## Firestore 컬렉션 (신규, 기존 컬렉션 비파괴)

```text
sotong24work_projects/{projectId}
  title, productType, contentSubtype
  currentStage (int stageNumber), currentStageId (optional)
  totalStages, progress
  status, approvalStatus
  pcStatus, lastHeartbeat (서버 시각 권장)
  serverReceivedAt, clientUpdatedAt, clientHeartbeatAt (optional)
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
PC가 `request_poll`로 `requests`를 **읽기 전용**으로 수신합니다. (소비/status 변경은 별도 operation)

## PC → Relay → Firestore (권장)

PC에 service account private key를 장기 저장하지 않습니다.

```text
Sotong24Work PC
  -- HTTPS + Bearer relay token -->
Cloud Function sotong24Relay (Admin SDK)
  -- allowlist upsert -->
Firestore sotong24work_projects
  -->
SotongWareControl (기존 Admin Auth 읽기/승인)
```

### Endpoint

- 단일 HTTP 함수: `sotong24Relay`
- `POST` only
- Body: `{ "operation": "heartbeat"|"project_sync"|"stage_sync"|"full_sync"|"request_poll", ... }`
- `request_poll` 입력: `{ "operation":"request_poll", "projectId", "currentStageId", "limit?" }`
  - 고정 경로: `sotong24work_projects/{projectId}/requests` (클라이언트 path 불가)
  - 응답: `{ ok, operation, projectId, currentStageId, requests:[], serverReceivedAt }`
  - **쓰기 없음** (status/processedAt 변경 금지). `isDemo=true` 차단.

### 인증

- Firebase Secret: `SOTONG24_RELAY_SECRET`
- 헤더: `Authorization: Bearer <secret>` 또는 `X-Sotong24-Relay-Token: <secret>`
- Secret 미설정 시 **fail-closed** (503)
- Secret을 소스/Git에 커밋하지 않음

### 배포

```bash
firebase functions:secrets:set SOTONG24_RELAY_SECRET --project sotongware-control
firebase deploy --only functions:sotong24Relay --project sotongware-control
```

PC에는 동일 secret만 로컬 보안 저장소에 두고, Firestore 광범위 권한은 부여하지 않습니다.

### Allowlist / 검증

- project/stage 허용 필드만 merge write
- `projectId`/`stageId` path injection 거부
- ebook은 canonical 18 `stageId`만 허용 (`BusinessPlanningService.standardWorkflowTitles`와 동일)
- `currentStage`가 stageId 문자열(예: `launch`)이면 서버가 stageNumber(예: 15)로 변환해 Flutter 계약(`int`)을 유지
- `lastHeartbeat`는 **서버 수신 시각**으로 기록 (PC 시계 조작 완화). PC 시각은 `clientHeartbeatAt`에만 보존
- 원고/workReport 등 대용량·민감 필드는 relay로 받지 않음

### Firestore Rules

- **변경하지 않음.** Client는 기존 Admin Auth만 read/write
- Relay는 Admin SDK로 서버 권한 사용 (rules와 별개)
- PC 직접 Firestore write를 위해 rules를 완화하지 **않음**

## PC Heartbeat

MFC가 relay `heartbeat`(권장 45초)로 `lastHeartbeat`·`pcStatus`를 갱신하면
웹은 2분 이내 온라인 / 10분 이내 연결 지연 / 그 외 오프라인으로 표시합니다.

## 데모 데이터

Firebase 미연결 또는 프로젝트 문서가 비어 있으면 `isDemo: true` 샘플을 표시합니다.
relay로 동기화된 실문서는 `isDemo: false`로 기록됩니다.
실제 제품 문서와 구분되며, 기존 데이터를 삭제·마이그레이션하지 않습니다.
