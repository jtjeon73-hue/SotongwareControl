# 관리자 인증 진단 (소통총관제)

작성일: 2026-07-14  
운영 주소: https://sotongware-control.web.app  
Firebase Project: `sotongware-control`

## 증상

로그인 화면에서 아이디 `sotongware`와 비밀번호를 입력한 뒤 로그인하면,
Firebase Authentication 비밀번호 검증이 수행되기 전에

> 관리자 인증 설정이 완료되지 않았습니다.

메시지가 표시된다.
시크릿 창·강력 새로고침에서도 동일하다.

## 오류 문구 발생 위치

- UI 메시지: `lib/screens/login_screen.dart` → `_messageFor(AuthFailureReason.configMissing)`
- 발생 조건: `lib/services/auth_service.dart` → `signIn`에서  
  `!AuthConfig.hasAdminEmailConfigured` 일 때 `AuthFailureReason.configMissing` 반환
- 설정 소스: `lib/config/auth_config.dart`  
  `String.fromEnvironment('SOTONG_ADMIN_AUTH_EMAIL')` / `SOTONG_ADMIN_UID`

## 발생 조건

빌드 시 다음 dart-define이 **비어 있으면** 발생한다.

```text
--dart-define=SOTONG_ADMIN_AUTH_EMAIL=...
--dart-define=SOTONG_ADMIN_UID=...
```

이메일이 비어 있으면 `hasAdminEmailConfigured == false` → Firebase `signInWithEmailAndPassword` 호출 전에 실패.

## Console / Network

- Firebase 초기화 자체 실패가 아니라, **컴파일 타임 상수 누락**이 주원인이다.
- Auth REST 로그인 요청이 나가지 않거나, 나가기 전에 클라이언트가 차단한다.
- 캐시 문제가 아니다 (시크릿 창에서도 동일).

## Firebase 상태

- 활성 프로젝트: `sotongware-control` (`.firebaserc` default)
- 관리자 계정·비밀번호를 삭제/초기화한 흔적은 코드상 없음
- 인증 방식: UI 아이디 `sotongware` → Firebase 이메일/비밀번호로 매핑

## 실제 원인 (2026-08-31 재발)

Golden Run 2 사전 고도화 배포(`d310c8f`)에서 `flutter build web`만 실행한 뒤 Hosting을 배포했다.
관리자 dart-define(`SOTONG_ADMIN_AUTH_EMAIL`, `SOTONG_ADMIN_UID`)이 빠진 빌드가 운영을 덮어써
로그인 시 `AuthFailureReason.configMissing` → "관리자 인증 설정을 확인할 수 없습니다." 발생.

**API 장애가 아님.** 로그인 화면은 별도 config API를 호출하지 않고, 컴파일 타임 상수를 사용한다.
`verify_live_admin_build.py`로 live bundle에 email/uid 포함 여부를 확인할 수 있다.

## 재발 방지 (2026-08-31)

1. `scripts/deploy_control.ps1`만으로 운영 Hosting 배포
2. `GET /api/control/auth-public-config` — dart-define 누락 시 런타임 fallback (비밀번호 미포함)
3. `AuthRuntimeConfig.ensureLoaded()` — 앱 시작·로그인 전 서버 매핑 로드

```powershell
flutter build web --release --base-href /
```

만 실행한 뒤 Hosting을 배포했다.
이 명령에는 관리자 dart-define이 없다.
그 결과 `SOTONG_ADMIN_AUTH_EMAIL` / `SOTONG_ADMIN_UID`가 빈 문자열로 들어간 빌드가
어제 dart-define이 포함된 정상 빌드를 **덮어썼다**.

정상 절차는 `tool/deploy_control.local.ps1`(gitignore)에 문서화된 대로
따옴표로 dart-define을 넣어 빌드·배포하는 것이다.
관련 수정 커밋: `3129155 Fix PowerShell dart-define quoting and add local deploy script`

## 캐시 / Firebase 프로젝트 오배포 여부

| 항목 | 판단 |
|------|------|
| 단순 캐시 | 아님 |
| 다른 Firebase 프로젝트 배포 | 아님 (`sotongware-control` 유지) |
| 관리자 계정 삭제 | 해당 없음 (코드/설정 누락) |
| 빌드 변수 누락 | **맞음** |

## 수정 방법

1. 로컬 `tool/deploy_control.local.ps1`의 email/UID로 운영 빌드
2. Hosting만 `firebase deploy --only hosting --project sotongware-control`
3. 재발 방지: `scripts/deploy_control.ps1`에서 설정 없으면 빌드 중단
4. dart-define 없는 `flutter build web --release`만으로 운영 배포하지 않기

## 비고

- 비밀번호는 진단 문서·Git에 기록하지 않음
- 관리자 이메일은 로컬 배포 스크립트에만 보관 (gitignore)
