# Firebase 원격 중앙관제 Backend V1

**protocolVersion:** `1.0`  
**상태:** Emulator / 자동 테스트 완료 · **production deploy 보류**

Sotong24Work Agent 계약 SSOT:  
`Sotong24Work/docs/remote_agent_protocol_v1.md`, `scripts/mock_agent_relay.py`, `AgentProtocol.h`, `AgentModels.h` (`StateKey` 소문자 wire).

## 아키텍처

```text
소통총관제 (Flutter + Firebase Auth)
    │  POST /api/control/*  (ID Token)
    ▼
Cloud Function `api` (2nd gen, Node 20)
    │  Admin SDK
    ▼
Firestore: agents / jobs / commands / stages / pairingSessions
    ▲
Cloud Function `api`
    │  POST /api/agent/*  (Bearer agentToken)
    ▼
Sotong24Work Agent (WinHTTP, DPAPI token)
```

기존 `sotong24Relay`(project mirror / request_poll)는 **별도 유지**. Agent job command 경로와 혼용하지 않는다.

## Collections

| Path | 비고 |
|------|------|
| `agents/{agentId}` | tokenHash만 저장 (원문 token 금지) |
| `agentTokens/{sha256}` | token → agentId 조회 |
| `pairingSessions/{sessionId}` | codeHash, used, expiresAt |
| `jobs/{jobId}` | ownerUid, assignedAgentId, status… |
| `jobs/{jobId}/commands/{commandId}` | START_JOB 등 |
| `jobs/{jobId}/stages/{stageId}` | report-stage |
| `jobs/{jobId}/events/{eventId}` | report-error |
| `users/{uid}` | 예약 |

## Agent API

Base URL (Hosting rewrite 시): `https://<host>`  
Emulator Functions 직접: `http://127.0.0.1:5001/sotongware-control/us-central1/api`  
→ Agent `relayBaseUrl`에는 **호스트(+ /api 함수 prefix)** 를 두고 path는 `/api/agent/...` 또는 함수가 path를 `/agent/...`로 받는 경우 문서화대로 맞춘다.

| Method | Path | Auth |
|--------|------|------|
| POST | `/api/agent/enroll` | none (pairingCode) |
| POST | `/api/agent/heartbeat` | Bearer agentToken |
| POST | `/api/agent/pull` | Bearer |
| POST | `/api/agent/claim` | Bearer |
| POST | `/api/agent/complete` | Bearer |
| POST | `/api/agent/fail` | Bearer |
| POST | `/api/agent/report-state` | Bearer |
| POST | `/api/agent/report-job` | Bearer |
| POST | `/api/agent/report-stage` | Bearer |
| POST | `/api/agent/report-error` | Bearer |

응답 공통: `{ "ok": true|false, ... }` · 에러 시 `{ ok:false, error }`  
Pull: `{ ok:true, commands:[ envelope… ] }` — mock relay와 동일 envelope.

Agent state wire: `starting|idle|receiving_job|running|waiting_approval|revision_requested|error|offline`

## Control API (Firebase Auth ID Token)

| Path | V1 |
|------|----|
| `/api/control/create-pairing` | ✅ pairingCode 1회 반환 |
| `/api/control/create-job` | ✅ |
| `/api/control/start-job` | ✅ START_JOB queued |
| `/api/control/approve-stage` | validator + 501 stub |
| `/api/control/request-revision` | validator + 501 stub |
| pause/resume/cancel | 501 stub |

## Pairing

1. Control `create-pairing` → 8자 코드 + `codeHash` 저장 (평문 장기 저장 금지)
2. TTL 10분, `used=false`
3. Agent `enroll` → agentId + agentToken 1회 발급, session used, tokenHash만 저장

## Claim transaction

`queued` → `claimed` only inside Firestore transaction.  
동일 agent 재claim → `{ ok:true, alreadyClaimed:true }`.  
`completed`/`failed` → 409 `not_claimable`.

## Online 판정

SSOT: `agents.lastHeartbeatAt` (서버 시각).  
UI 임계값 상수: `ONLINE_WITHIN_MS = 90000`.

## Security Rules

- Agent/job/pairing/token: **client write 금지**
- 본인 `ownerUid` 또는 기존 admin UID read
- 레거시 컬렉션: 기존 admin read/write 유지

## Indexes

`commands` collectionGroup: `agentId + status + createdAt`  
`pairingSessions`: `codeHash + used`

## Emulator

```bash
# Java(JRE) 필요 — Firestore emulator
firebase emulators:start --only auth,firestore,functions,hosting
```

Ports: Auth 9099 · Firestore 8080 · Functions 5001 · Hosting 5000 · UI 4000

계약 테스트 (배포 불필요, in-memory Firestore mock):

```bash
cd functions && npm test
```

> 참고: 이 PC에서 `firebase emulators:exec`는 Java PATH 미설정 시 Firestore emulator가 기동되지 않을 수 있다. Backend V1 계약은 `npm test`의 memory DB로 검증한다.
## Production 배포 전 체크리스트

- [ ] Blaze + Secret/API 확인
- [ ] `firestore.indexes` 배포
- [ ] `firestore.rules` 리뷰 (레거시 회귀)
- [ ] `firebase deploy --only functions:api` (relay와 분리)
- [ ] Hosting rewrite `/api/**` → `api` 확인
- [ ] Sotong24Work `agent_remote.json` relayBaseUrl / enroll
- [ ] pairing UX (총관제 버튼)
- [ ] 부하·비용 (poll 3–5s, heartbeat 30s)

**이번 단계에서는 deploy/push 하지 않음.**

## Sotong24Work 연결

1. Emulator 또는 향후 production Base URL 설정  
   `Documents\Sotong24Work\Config\agent_remote.json`
2. 총관제에서 pairing 생성 → Agent enroll → DPAPI token 저장
3. create-job + start-job → Agent pull/claim → Inbox START_JOB
4. 기존 `allowLiveFirestoreWrite` / RemoteSync relay와 역할 분리 유지
