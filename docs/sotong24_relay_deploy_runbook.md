# 소통24워크 Relay 배포·PC 연결 절차 (secret 평문 없음)

## 전제

- Firebase project: `sotongware-control`
- Cloud Function: `sotong24Relay` (Secret `SOTONG24_RELAY_SECRET`)
- **Blaze(종량제) 요금제**가 필요합니다. Spark에서는 Secret Manager·Cloud Functions 배포가 불가합니다.

## 1) Blaze 업그레이드

https://console.firebase.google.com/project/sotongware-control/usage/details

## 2) Secret 설정 (평문을 Git/문서에 넣지 말 것)

로컬에서 이미 생성된 안전한 저장 위치가 있다면 그 값을 사용합니다.  
없으면 새 난수를 만든 뒤 Secret Manager에만 넣습니다.

```powershell
# 대화형 입력 (화면에 에코되지 않게 주의)
firebase functions:secrets:set SOTONG24_RELAY_SECRET --project sotongware-control
```

또는 로컬 ignored 파일에서만 읽어 파이프 (파일을 커밋하지 말 것):

```powershell
# 예: %LOCALAPPDATA%\SotongWareControl\sotong24_relay_secret.txt
Get-Content "$env:LOCALAPPDATA\SotongWareControl\sotong24_relay_secret.txt" -Raw |
  firebase functions:secrets:set SOTONG24_RELAY_SECRET --project sotongware-control
```

## 3) Function만 배포

Windows에서 discovery timeout이 나면:

```powershell
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only functions:sotong24Relay --project sotongware-control
```

운영 endpoint (us-central1):

`https://us-central1-sotongware-control.cloudfunctions.net/sotong24Relay`

- runtime: Node.js 20 (2nd gen)
- memory: 256MiB / timeout: 30s / maxInstances: 20
- minInstances: 미설정(scale-to-zero)

배포 말미 Artifact Registry cleanup policy 경고는 Function 생성과 별개입니다.

## 4) PC(Sotong24Work) 설정 (이 저장소에서는 MFC 수정 금지)

다음 Open Folder를 Sotong24Work로 바꾼 뒤 진행:

- **service account private key를 PC에 두지 않습니다.**
- Relay URL + **동일** `SOTONG24_RELAY_SECRET`만 Git 밖 로컬 설정에 둡니다.
  - 예: `%USERPROFILE%\Documents\Sotong24Work\Config\` 아래 **gitignore된** 로컬 파일
  - 또는 `%LOCALAPPDATA%\Sotong24Work\` 등 repo 밖 경로
- SotongWareControl holding: `%LOCALAPPDATA%\SotongWareControl\sotong24_relay_secret.txt` (값 복사 시 평문을 Git/채팅에 넣지 말 것)
- `allowLiveFirestoreWrite=false` 유지 → dry-run으로 endpoint/인증만 확인 → 별도 승인 후 live
- secret을 GitHub·채팅·로그에 붙이지 않습니다.

## 5) 보안 스모크 (운영 write 없이)

```text
POST only
Authorization 없음 → 401
잘못된 Bearer → 403
잘못된 operation → 400
path injection projectId → 400
```

정상 `project_sync`/`full_sync`는 운영 데이터 생성 전이므로 별도 승인 후 수행합니다.
