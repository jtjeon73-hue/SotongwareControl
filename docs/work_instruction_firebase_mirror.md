# DevWorkDoc ↔ Firestore Active Mirror

로컬 `DevWorkDoc/*/Active` 가 PC 원본이고, Firestore `workInstructions` 는
휴대폰 원격관제용 **soft mirror** 이다.

## Sync triggers (제작소)

| 로컬 동작 | Mirror |
|-----------|--------|
| Active 저장 성공 / alreadyExists 검증 | `upsertActive` (status=active) |
| Archive | `markArchived` |
| Archive→Active 복원 / Versions→Active | `upsertActive` 또는 `restoreActive` |

Firestore sync 실패해도 로컬 저장은 유지한다.

## Stale Active 후속

영구 삭제(`permanentDelete`) 시 mirror 문서 삭제는 아직 훅하지 않았다.
후속에서 `permanentDelete` 성공 후 `workInstructions/{docId}` delete
또는 status=`deleted` 를 추가하면 stale Active 장기 잔존을 막을 수 있다.
