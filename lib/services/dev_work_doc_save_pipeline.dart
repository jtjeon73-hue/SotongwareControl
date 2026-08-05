/// DevWorkDoc 저장 파이프라인 (어댑터 기반, 브라우저/메모리 공용).
library;

import 'dev_work_doc_fs.dart';
import 'dev_work_doc_paths.dart';
import 'dev_work_doc_types.dart';
import 'dev_work_doc_verify.dart';
import 'work_instruction_validator.dart';

class DevWorkDocSavePipeline {
  DevWorkDocSavePipeline(this.fs);

  final DevWorkDocFsAdapter fs;

  final List<String> diagnostics = [];

  void _log(String step, [String detail = '']) {
    diagnostics.add(detail.isEmpty ? step : '$step: $detail');
  }

  Future<DevWorkDocWriteResult> saveInstruction({
    required String artifactType,
    required String instructionId,
    required int version,
    required String jsonText,
    bool isNewVersion = false,
  }) async {
    // isNewVersion: Active 갱신 허용 플래그(충돌 정책용, 현재 Versions 충돌만 엄격).
    // ignore: unused_local_variable
    final _ = isNewVersion;
    diagnostics.clear();
    if (instructionId.trim().isEmpty) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: instructionId\n대상: (empty)\n오류: InvalidStateError\n'
            'instructionId가 비어 있습니다.',
        errorCode: 'bad_id',
      );
    }
    final safeId = DevWorkDocPaths.sanitizeInstructionId(instructionId);

    final artifactFolder = DevWorkDocPaths.artifactFolder(artifactType);
    final activeFile = '${DevWorkDocPaths.wiBaseName(instructionId)}.json';
    final versionFile =
        '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';
    final activeRel = '$artifactFolder/Active/$activeFile';
    final versionRel = '$artifactFolder/Versions/$safeId/$versionFile';

    try {
      _log(DevWorkDocSaveStep.root, 'ok');

      // --- 기존 파일 프로브 (NotFound = 파일 없음, 실패 아님) ---
      _log(DevWorkDocSaveStep.existsProbe, activeRel);
      final existingActive = await fs.readFile([
        artifactFolder,
        'Active',
      ], activeFile);
      final existingVersion = await fs.readFile([
        artifactFolder,
        'Versions',
        safeId,
      ], versionFile);

      final activeCmp = compareExistingFile(
        existingText: existingActive.text,
        expectedJson: jsonText,
      );
      final versionCmp = compareExistingFile(
        existingText: existingVersion.text,
        expectedJson: jsonText,
      );

      if (activeCmp == DevWorkDocSaveOutcome.alreadyExists &&
          versionCmp == DevWorkDocSaveOutcome.alreadyExists) {
        final sum = contentChecksum(jsonText);
        return DevWorkDocWriteResult(
          ok: true,
          mode: 'folder',
          outcome: DevWorkDocSaveOutcome.alreadyExists,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          checksum: sum,
          fileName: activeFile,
          activeVerified: true,
          versionsVerified: true,
          activeBytes: existingActive.size,
          versionsBytes: existingVersion.size,
          message: '기존 파일 확인: 동일 checksum — 다시 쓰지 않음',
        );
      }

      if (versionCmp == DevWorkDocSaveOutcome.conflict) {
        return DevWorkDocWriteResult.failed(
          message:
              '실패 단계: Versions 충돌 검사\n대상: $versionRel\n오류: Conflict\n'
              '다른 내용의 버전이 이미 있어 덮어쓰지 않았습니다.\n'
              '다음 행동: 기존 Versions 파일을 확인한 뒤 관리자에게 보고',
          errorCode: 'conflict',
          outcome: DevWorkDocSaveOutcome.conflict,
          activePathHint: activeRel,
          versionPathHint: versionRel,
        );
      }

      final versionAlreadyOk =
          versionCmp == DevWorkDocSaveOutcome.alreadyExists;

      late final ({String? text, int size}) versionRead;

      if (versionAlreadyOk) {
        _log(
          DevWorkDocSaveStep.versionFileReread,
          'skip write (same checksum)',
        );
        versionRead = existingVersion;
      } else {
        // --- 1) Versions 경로 생성 + 쓰기 ---
        _log(DevWorkDocSaveStep.artifactDir, artifactFolder);
        await fs.ensureDir([artifactFolder], create: true);

        _log(DevWorkDocSaveStep.versionsDir, '$artifactFolder/Versions');
        await fs.ensureDir([artifactFolder, 'Versions'], create: true);

        _log(
          DevWorkDocSaveStep.instructionDir,
          '$artifactFolder/Versions/$safeId',
        );
        await fs.ensureDir([artifactFolder, 'Versions', safeId], create: true);

        _log(DevWorkDocSaveStep.versionFileCreate, versionRel);
        _log(DevWorkDocSaveStep.versionFileWrite, '${jsonText.length} chars');
        await fs.writeFile(
          [artifactFolder, 'Versions', safeId],
          versionFile,
          jsonText,
        );

        _log(DevWorkDocSaveStep.versionFileReread, versionRel);
        versionRead = await fs.readFile([
          artifactFolder,
          'Versions',
          safeId,
        ], versionFile);
        if (versionRead.text == null || versionRead.size <= 0) {
          throw DevWorkDocStepError(
            step: DevWorkDocSaveStep.versionFileReread,
            relativePath: versionRel,
            domName: 'NotFoundError',
            message: 'Versions 재읽기 실패 또는 빈 파일',
          );
        }
      }

      // --- 2) Active ---
      _log(DevWorkDocSaveStep.activeDir, '$artifactFolder/Active');
      try {
        await fs.ensureDir([artifactFolder, 'Active'], create: true);
        _log(DevWorkDocSaveStep.activeFileCreate, activeRel);
        _log(DevWorkDocSaveStep.activeFileWrite, '${jsonText.length} chars');
        await fs.writeFile([artifactFolder, 'Active'], activeFile, jsonText);
      } on FsNotFoundException catch (e) {
        return DevWorkDocWriteResult(
          ok: false,
          mode: 'failed',
          outcome: DevWorkDocSaveOutcome.partialSuccess,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          message:
              '부분 성공: Versions 저장·재읽기 완료, Active 쓰기 실패\n'
              '실패 단계: ${e.step}\n대상: ${e.relativePath}\n오류: NotFoundError\n'
              '다음 행동: 같은 지시서로 DevWorkDoc 저장을 다시 실행하세요 (Versions는 유지).',
          errorCode: 'partial_active',
          activeVerified: false,
          versionsVerified: true,
          versionsBytes: versionRead.size,
          checksum: contentChecksum(jsonText),
        );
      } catch (e) {
        return DevWorkDocWriteResult(
          ok: false,
          mode: 'failed',
          outcome: DevWorkDocSaveOutcome.partialSuccess,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          message:
              '부분 성공: Versions 저장·재읽기 완료, Active 쓰기 실패\n'
              '실패 단계: ${DevWorkDocSaveStep.activeFileWrite}\n대상: $activeRel\n'
              '오류: $e\n다음 행동: 같은 지시서로 DevWorkDoc 저장을 다시 실행하세요.',
          errorCode: 'partial_active',
          activeVerified: false,
          versionsVerified: true,
          versionsBytes: versionRead.size,
          checksum: contentChecksum(jsonText),
        );
      }

      _log(DevWorkDocSaveStep.activeFileReread, activeRel);
      final activeRead = await fs.readFile([
        artifactFolder,
        'Active',
      ], activeFile);
      if (activeRead.text == null || activeRead.size <= 0) {
        return DevWorkDocWriteResult(
          ok: false,
          mode: 'failed',
          outcome: DevWorkDocSaveOutcome.partialSuccess,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          message:
              '부분 성공: Versions 저장·재읽기 완료, Active 재읽기 실패\n'
              '실패 단계: ${DevWorkDocSaveStep.activeFileReread}\n대상: $activeRel\n'
              '오류: NotFoundError\n다음 행동: 같은 지시서로 DevWorkDoc 저장을 다시 실행하세요.',
          errorCode: 'partial_active',
          activeVerified: false,
          versionsVerified: true,
          versionsBytes: versionRead.size,
          checksum: contentChecksum(jsonText),
        );
      }

      _log(DevWorkDocSaveStep.checksum, 'verify');
      final verified = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: jsonText,
          activeText: activeRead.text,
          versionsText: versionRead.text,
          instructionId: instructionId,
          version: version,
        ),
      );

      if (!verified.isComplete) {
        return DevWorkDocWriteResult(
          ok: false,
          mode: 'failed',
          outcome: verified.outcome,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          message: verified.message,
          errorCode: verified.errorCode ?? 'verify_failed',
          checksum: verified.checksum,
          activeVerified: verified.activeVerified,
          versionsVerified: verified.versionsVerified,
          activeBytes: verified.activeBytes,
          versionsBytes: verified.versionsBytes,
        );
      }

      return DevWorkDocWriteResult(
        ok: true,
        mode: 'folder',
        outcome: DevWorkDocSaveOutcome.completeSuccess,
        activePathHint: activeRel,
        versionPathHint: versionRel,
        checksum: verified.checksum,
        fileName: activeFile,
        activeVerified: true,
        versionsVerified: true,
        activeBytes: activeRead.size,
        versionsBytes: versionRead.size,
        message:
            '완전 성공: Active ${activeRead.size}B · Versions ${versionRead.size}B 검증 완료\n'
            'Active: $activeRel\nVersions: $versionRel',
      );
    } on FsNotFoundException catch (e) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: ${e.step}\n대상: ${e.relativePath}\n오류: NotFoundError\n${e.message}',
        errorCode: 'not_found',
        activePathHint: activeRel,
        versionPathHint: versionRel,
      );
    } on DevWorkDocStepError catch (e) {
      return DevWorkDocWriteResult.failed(
        message: e.userMessage,
        errorCode: 'step_failed',
        activePathHint: activeRel,
        versionPathHint: versionRel,
      );
    } catch (e) {
      return DevWorkDocWriteResult.failed(
        message: '실패 단계: unknown\n대상: $versionRel | $activeRel\n오류: $e',
        errorCode: 'write_failed',
        activePathHint: activeRel,
        versionPathHint: versionRel,
      );
    }
  }
}
