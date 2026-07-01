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

### 앱개발 사업부 관리 앱

- **소통여행** — 여행 정보·일정 관리
- **소통사주** — 사주·운세 콘텐츠
- **팜지기** — 농촌 직거래
- **소통건강** — AI 건강코치
- **소통AI** — AI 활용 플랫폼
- **소통사매앱 / SotongSamae** — 지역 생활정보, 마을 소식, 관광지, 생활 편의 정보를 담는 지역 밀착형 앱

## 지원 부서

- 세무·회계·예산·재테크
- 기획·아이디어
- 온라인영업·고객대응
- 판매·고객대응
- AI 직원실

## 실행 방법

### 웹 (개발·확인)

```bash
flutter pub get
flutter run -d chrome
```

### Android (휴대폰 테스트용 APK)

이 APK는 **개인용 테스트 APK**입니다. Play Store 등록용이 아니며, **GitHub 저장소에 APK 파일을 직접 업로드하지 마세요.**

#### 빌드 전 점검

```bash
flutter clean
flutter pub get
flutter analyze
```

#### 테스트용 debug APK 빌드

```bash
flutter build apk --debug
```

#### APK 생성 위치

```
build/app/outputs/flutter-apk/app-debug.apk
```

#### 복사 위치 (권장)

프로젝트 루트 `release_apk` 폴더에 아래 이름으로 복사합니다.

```
release_apk/SotongWareControl_0.2.0_debug.apk
```

release 빌드가 성공한 경우:

```
release_apk/SotongWareControl_0.2.0_release.apk
```

#### 휴대폰 설치 방법

1. APK 파일을 휴대폰으로 전송 (USB, 클라우드, 메신저 등)
2. 파일 관리자에서 APK 파일 열기
3. **출처를 알 수 없는 앱** 설치 허용
4. 설치 진행
5. **소통웨어 디지털랩** 실행

#### 앱 정보

| 항목 | 값 |
|------|-----|
| 표시 이름 | 소통웨어 디지털랩 |
| 영문명 | SotongWare Control |
| 버전 | 0.2.0+1 |
| 패키지명 | com.sotongware.control |

## 사업 홍보사이트 링크맵

내부 관제센터에서 **PRIVATE 사이트**와 **PUBLIC 사업 총괄 홍보사이트**를 구분해 관리합니다.

## Public 사업 총괄 사이트 연결 구조

| 저장소 | 역할 |
|--------|------|
| SotongwareControl | private 내부 관제센터 |
| SotongAutomationPromo | 산업자동화 public 홍보사이트 |
| SotongAppsPromo | 앱개발 public 홍보사이트 |
| SotongContentsPromo | 콘텐츠 public 홍보사이트 |
| SotongEbookPromo | 전자책 public 홍보사이트 |

### 연결 URL

- https://jtjeon73-hue.github.io/SotongAutomationPromo/
- https://jtjeon73-hue.github.io/SotongAppsPromo/
- https://jtjeon73-hue.github.io/SotongContentsPromo/
- https://jtjeon73-hue.github.io/SotongEbookPromo/

### GitHub Pages 확인 방법

- 각 promo 저장소에서 `docs` 폴더가 있는지 확인
- GitHub Desktop에서 Commit / Push 되었는지 확인
- GitHub 저장소 **Settings → Pages → main / docs** 설정 확인
- 배포 주소 접속 시 404가 없는지 확인

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

- SotongTravelPromo, SotongSajuPromo, FarmjigiPromo, SotongHealthPromo, SotongAIPromo, SotongSamaePromo

## 앱개발부 개별 프로모 연결 구조

| 앱 | 프로모 URL |
|----|------------|
| 소통여행 | https://jtjeon73-hue.github.io/SotongTravelPromo/ |
| 소통사주 | https://jtjeon73-hue.github.io/SotongSajuPromo/ |
| 팜지기 | https://jtjeon73-hue.github.io/FarmjigiPromo/ |
| 소통건강 | https://jtjeon73-hue.github.io/SotongHealthPromo/ |
| 소통AI | https://jtjeon73-hue.github.io/SotongAIPromo/ |
| 소통사매앱 | https://jtjeon73-hue.github.io/SotongSamaePromo/ |

각 개별 프로모 저장소가 아직 생성·배포되지 않은 경우 해당 URL은 **404**가 날 수 있습니다. 저장소 생성 후 GitHub Pages를 **main / docs** 기준으로 설정하면 연결됩니다.

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
