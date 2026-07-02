# 소통웨어 디지털랩 / SotongWare Control

**소통컨트롤총괄프로모** — Flutter Web 기반 비공개 본사 AI 경영 관제 시스템 데모

## 프로젝트 소개

소통웨어(SotongWare)의 **24시간 AI 경영 관제 · AI대표 · 사업부 · 관리부서** 운영 구조를 대표 1명이 확인하는 비공개 본사 시스템 컨셉 데모입니다.

실제 서버/Firebase/OpenAI 연동 전 단계로, **방향성·구조·AI대표 회의·알림·승인 체계**를 보여주는 **더미데이터 기반 대시보드**입니다. 화면의 진행률·수치·재무 입력·작업 목록은 모두 **샘플·예시**입니다.

### 내부 관제 데모 안내

- 실제 개인정보, 매출, 세금, 홈택스 로그인, API Key, 거래처 민감 정보는 **포함·저장하지 않습니다**
- 재무·세무·투자·매출·다운로드 관련 UI는 **향후 연동 비전**을 보여주는 데모입니다
- 브라우저에 저장되는 값은 데모 체험용 설정(작업·URL 등)에 한정됩니다

## 주요 기능

- **AI대표실** — 오늘의 대표 브리핑, 긴급 알림, 승인 대기, 매출, 다운로드, 고객문의, 개발/마케팅/세무/투자 요약
- **AI전략회의실** — AI대표와 AI부서장이 현재 사업 안건을 검토하고 대표 승인/보류/재검토 요청을 제안
- **AI아이디어회의실** — 신규 사업 아이디어를 시장성, 개발 난이도, 예상 수익성, 경쟁 강도, 소통웨어 연관성으로 평가
- **알림센터** — 긴급, 승인 필요, 개발 완료, 고객 문의, 매출, 다운로드, 마케팅, 세무, 투자, 시스템 오류 알림 관리
- **AI부서 관제** — 상품개발, 마케팅, 영업, 고객지원, 세무회계, 투자관리, 운영관리 부서별 감시 업무
- **데모 운영 기능** — 작업·이슈 CRUD, 재무 샘플 입력, 홍보사이트 링크맵 (브라우저 localStorage)

## 메뉴 구조

| 섹션 | 메뉴 |
|------|------|
| 관제 · AI대표 | 전체사업관리관제 |
| AI대표 | AI대표실, AI전략회의실, AI아이디어회의실, AI업무지시, AI진행보고, AI의사결정제안, AI리스크분석, AI미래전략, 알림센터 |
| AI부서 | AI상품개발부, AI마케팅부, AI영업부, AI고객지원부, AI세무회계부, AI투자관리부, AI운영관리부 |
| 기존 사업부/관리부서 | 산업자동화, 앱개발, 유튜브/콘텐츠, 전자책, 기획·아이디어, 홍보·마케팅, 재무·세금, 온라인 고객대응 |

## 연결된 공개 프로모 생태계

| 저장소 | 역할 |
|--------|------|
| **SotongwareControl** | 통합 컨트롤 허브 (본 사이트) |
| SotongAutomationPromo | 산업자동화 총괄 프로모 |
| SotongAppsPromo | 앱개발 총괄 프로모 |
| SotongContentsPromo | 콘텐츠 총괄 프로모 |
| SotongEbookPromo | 전자책 총괄 프로모 |

## 실행 방법

```bash
flutter pub get
flutter run -d chrome
```

## 배포 방법 (GitHub Pages)

```bash
flutter pub get
flutter analyze
flutter build web --base-href /SotongwareControl/
```

`build/web` 내용을 `docs/`에 반영하고 `.nojekyll`을 포함한 뒤 push합니다.

GitHub 저장소 **Settings → Pages → Branch: main / Folder: docs**

### 배포 URL

https://jtjeon73-hue.github.io/SotongwareControl/

## 기술 스택

- Flutter Web
- shared_preferences (데모 설정 localStorage)
- url_launcher (외부 프로모 링크)

## 라이선스·기여

소통웨어 디지털랩 공개 프로모 프로젝트입니다. 실제 운영 데이터·민감 정보는 이 저장소에 포함하지 마세요.

## 향후 확장

- AI대표 실행 승인(체크) UI
- 부서별 세부 프로모 페이지
- 실제 API·DB 연동 (별도 private 환경)
- 홈택스·재무 자동화 비전 구현
