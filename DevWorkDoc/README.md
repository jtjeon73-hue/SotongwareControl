# DevWorkDoc

SotongWare Control에서 생성·편집하는 **실작업 작업지시서(JSON)** 를 로컬에 보관하는 폴더입니다.

> **공개 저장소 경고:** 이 디렉터리의 JSON 파일에는 개인·사업 정보가 포함될 수 있습니다.  
> **절대 Git에 커밋하지 마세요.** `.gitignore` 로 `*.json` 은 차단되어 있으며, 구조만 `.gitkeep` 으로 추적됩니다.

## 폴더 구조

각 산출물(artifact)마다 동일한 3단 구조를 사용합니다.

```
DevWorkDoc/
├── App/
│   ├── Active/      ← 현재 편집·실행 중인 WI_*.json
│   ├── Versions/    ← 버전별 스냅샷 (Versions/{id}/WI_{id}_vN.json)
│   └── Archive/     ← 보관된 이전 Active (WI_{id}_vN.json)
├── Ebook/
├── Contents/
├── Site/
└── PromoSite/
```

| 하위 폴더 | 용도 |
|-----------|------|
| **Active** | 현재 작업 중인 지시서 1건 (`WI_{instructionId}.json`) |
| **Versions** | 버전 이력 (`WI_{id}_v1.json`, `v2`, …) |
| **Archive** | Active 에서 보관(move)된 파일 (Versions 는 유지) |

## 파일명 규칙

- Active: `WI_{instructionId}.json`
- Version: `WI_{instructionId}_v{version}.json`
- Archive: `WI_{instructionId}_v{version}.json`

`instructionId` 는 파일명에 안전하도록 정규화됩니다.

## 웹 앱 연동

브라우저(Chromium 계열)에서는 **File System Access API** 로 이 폴더를 루트로 선택할 수 있습니다.

- 루트 폴더 **이름**만 `SharedPreferences` 에 저장됩니다 (절대 경로는 저장하지 않음).
- 폴더 접근 권한은 세션·브라우저 정책에 따라 만료될 수 있으므로, 필요 시 다시 선택하세요.
- API 미지원·권한 없음·쓰기 실패 시 JSON **다운로드**로 대체됩니다 (폴더 저장 성공으로 표시되지 않음).

## 로컬 배치 (수동)

다운로드로 받은 JSON 은 위 구조에 맞게 해당 artifact 의 `Active` 또는 `Versions/{id}/` 아래에 넣어 주세요.
