# 소통웨어 디지털랩 / SotongWare Control Center

개인 사업 총괄 관제센터 — Flutter Web 기반 내부용 대시보드 프로토타입

## 목적

소통웨어의 전체 사업, 부서, 프로젝트, 홍보사이트, 앱, 콘텐츠, 전자책, 영업, 재무 흐름을 한눈에 관리하는 **개인용 사업 관제센터**입니다.

이 사이트는 공개 홍보사이트가 아닙니다.

## 2단계: 업무 상태 관리 기능

- **ActionItem CRUD** — 작업 추가·수정·완료·상태·우선순위·메모·삭제
- **BusinessIssue CRUD** — 문제 등록·상태 변경·대응 수정·해결·삭제
- **로컬 저장** — 브라우저 새로고침 후에도 ActionItem·BusinessIssue·재무 입력값 유지
- **AI 업무지시문 복사** — AI 직원실에서 추천 지시문 클립보드 복사
- **재무 카드 기초 입력** — 예상 매출/비용/순이익·부가세 확인·메모 (샘플)
- **대시보드 자동 집계** — 진행/완료/지연 작업, 미해결/긴급 문제 수 실시간 반영
- **아직 미연동** — OpenAI API, ChatGPT API, Cursor API, Firebase Auth, 실제 DB 서버

## 주요 사업부

- 산업자동화 모니터링 시스템
- 앱개발
- 유튜브/콘텐츠
- 전자책

## 지원 부서

- 세무·회계·예산·재테크
- 기획·아이디어
- 온라인영업·고객대응
- 판매·고객대응
- AI 직원실

## 실행 방법

```bash
flutter pub get
flutter run -d chrome
```

## 사업 홍보사이트 링크맵

내부 관제센터에서 **PRIVATE 사이트**와 **PUBLIC 사업 총괄 홍보사이트**를 구분해 관리합니다.

### PRIVATE (내부)

| 저장소 | 사이트 | 용도 |
|--------|--------|------|
| SotongwareControl | SotongWare Control Center | 개인용 내부 사업 총괄 관제센터 |

### PUBLIC 사업 총괄 홍보사이트 (제작 예정)

| 저장소 | 사업부 | 목적 |
|--------|--------|------|
| SotongAutomationPromo | 산업자동화 | 제조업체·조립라인·검사라인 고객 홍보 |
| SotongAppsPromo | 앱개발 | 개발 앱 전체 소개 + 하위 프로모 연결 |
| SotongContentsPromo | 유튜브/콘텐츠 | AI 음악·지역/시골 영상·앱 홍보 영상 |
| SotongEbookPromo | 전자책 | 출간 예정작·판매 링크 소개 |

### SotongAppsPromo 하위 링크 예정

- SotongTravelPromo, SotongSajuPromo, FarmjigiPromo, SotongHealthPromo, SotongAIPromo

### URL 관리

- 각 사이트 카드에 **저장소 이름, 공개 여부, 제작 상태, 다음 작업, 예상 URL** 표시
- URL 미등록 시 **「준비 중」** 표시
- GitHub Pages URL은 관제센터에서 **등록·수정** 가능 (브라우저 localStorage 저장)
- 이 관제센터(SotongwareControl)는 **GitHub Pages 공개 배포 금지**

## 의존성

- **shared_preferences** — Flutter Web `localStorage`에 ActionItem·BusinessIssue·재무 입력·홍보사이트 URL 저장

## 보안 원칙

- **private 저장소 권장** — 이 프로젝트는 개인 내부 관리용입니다.
- **GitHub Pages 공개 배포 금지** — 외부에 노출하지 마세요.
- **실제 고객정보 저장 금지** — 샘플·운영자 입력만 로컬에 저장합니다.
- **API Key 저장 금지** — 코드에 비밀번호·키를 넣지 마세요.
- **세무/회계 민감정보 저장 금지** — 재무 입력은 내부 점검용 샘플 수준만 허용합니다.
- 필요 시 나중에 **로그인 기능** 또는 **Firebase Auth** 검토

## 향후 개발 계획

- Firebase / 실제 DB 연동
- 로그인 기능
- 실제 날짜 기반 지연 자동 감지
- AI API 연동 (지시 → 보고 자동화)
- 공개 홍보사이트 링크 연결
- 소통창고/스마트스토어 연결
- 월별 매출/비용 대시보드 고도화
