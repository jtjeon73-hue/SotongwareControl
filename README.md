# 소통웨어 디지털랩 / SotongWare Control

**소통컨트롤총괄프로모** — Flutter Web 기반 공개형 프로모 / 데모 컨트롤센터

## 프로젝트 소개

소통웨어(SotongWare)의 **통합 컨트롤센터 · AI대표 · 관리부서 · 사업부** 운영 비전을 외부 방문자에게 소개하는 공개 프로모 사이트입니다.

실제 내부 관리 시스템이 아니라, **방향성·구조·AI대표 컨셉·관리 체계**를 보여주는 **데모형 대시보드**입니다. 화면의 진행률·수치·재무 입력·작업 목록은 모두 **샘플·예시**입니다.

### 공개용 안내

- 실제 개인정보, 매출, 세금, 홈택스 로그인, API Key, 거래처 민감 정보는 **포함·저장하지 않습니다**
- 재무·세무 관련 UI는 **향후 연동 비전**을 보여주는 데모입니다
- 브라우저에 저장되는 값은 데모 체험용 설정(작업·URL 등)에 한정됩니다

## 주요 기능

- **전체사업관리관제** — 4개 사업부·4개 관리부서 진행 비전, 체크포인트, 우선·수익·발전 포인트
- **AI대표** — 종합 브리핑, 사업부/부서 진단, 실행 제안, 체크 기반 의사결정 확장 비전
- **관리부서** — 기획·아이디어 / 홍보·마케팅 / 재무·세금 / 온라인 고객대응
- **사업부** — 산업자동화, 앱개발, 유튜브/콘텐츠, 전자책
- **데모 운영 기능** — 작업·이슈 CRUD, 재무 샘플 입력, 홍보사이트 링크맵 (브라우저 localStorage)

## 메뉴 구조

| 섹션 | 메뉴 |
|------|------|
| 관제 · AI대표 | 전체사업관리관제, AI대표 |
| 사업부 | 산업자동화, 앱개발, 유튜브/콘텐츠, 전자책 |
| 관리부서 | 기획·아이디어, 홍보·마케팅, 재무·세금, 온라인 고객대응 |

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
