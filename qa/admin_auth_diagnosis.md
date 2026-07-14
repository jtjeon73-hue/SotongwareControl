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

## 실제 원인

최근 배포(`feat: AI 자동 강의 생성…`, 커밋 `75862ad`)에서

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
