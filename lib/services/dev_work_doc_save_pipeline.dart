/// DevWorkDoc 저장 파이프라인 (어댑터 기반, 브라우저/메모리 공용).
library;

import 'instruction_content_checksum.dart';
import 'dev_work_doc_fs.dart';
import 'dev_work_doc_paths.dart';
import 'dev_work_doc_types.dart';
import 'dev_work_doc_verify.dart';

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
    String? operationId,
  }) async {
    diagnostics.clear();
    final opId =
        operationId ??
        'op_${DateTime.now().toUtc().millisecondsSinceEpoch}_v$version';
    if (isNewVersion) {
      _log('isNewVersion', 'true');
    }
    if (instructionId.trim().isEmpty) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: instructionId\n대상: (empty)\n오류: InvalidStateError\n'
            'instructionId가 비어 있습니다.',
        errorCode: 'bad_id',
        instructionId: instructionId,
        version: version,
        operationId: opId,
      );
    }
    final safeId = DevWorkDocPaths.sanitizeInstructionId(instructionId);

    final artifactFolder = DevWorkDocPaths.artifactFolder(artifactType);
    final activeFile = '${DevWorkDocPaths.wiBaseName(instructionId)}.json';
    final versionFile =
        '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';
    final activeRel = '$artifactFolder/Active/$activeFile';
    final versionRel = '$artifactFolder/Versions/$safeId/$versionFile';
    final expectedStable = stableContentChecksum(jsonText);

    try {
      _log(DevWorkDocSaveStep.root, 'ok');

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
        return DevWorkDocWriteResult(
          ok: true,
          mode: 'folder',
          outcome: DevWorkDocSaveOutcome.alreadyExists,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          checksum: expectedStable,
          fileName: activeFile,
          activeVerified: true,
          versionsVerified: true,
          activeBytes: existingActive.size,
          versionsBytes: existingVersion.size,
          instructionId: instructionId,
          version: version,
          operationId: opId,
          message: '기존 파일 확인: 동일 핵심 checksum — 다시 쓰지 않음',
        );
      }

      // Versions 핵심 내용이 실제로 다르면 덮어쓰지 않음
      if (versionCmp == DevWorkDocSaveOutcome.conflict) {
        final diff = diffInstructionContent(
          existingVersion.text ?? '',
          jsonText,
        );
        final metaOnly = diff.isMetadataOnly;
        // 안정 checksum 기준으로 conflict인데 metaOnly는 이론상 없어야 함.
        // 방어: sameCore면 conflict가 아니므로 여기까지 오지 않음.
        final summary = diff.entries
            .map((e) => '${e.label}: ${e.left} ↔ ${e.right}')
            .join('\n');
        return DevWorkDocWriteResult.failed(
          message:
              '실패 단계: Versions 충돌 검사\n대상: $versionRel\n오류: Conflict\n'
              '버전 v$version 핵심 내용이 기존 Versions와 다릅니다. 기존 파일을 덮어쓰지 않았습니다.\n'
              '다음 행동: 「기존 버전 확인 및 복구」에서 비교·복구하거나, '
              '승인한 뒤 다음 버전으로 생성하세요.',
          errorCode: 'conflict',
          outcome: DevWorkDocSaveOutcome.conflict,
          activePathHint: activeRel,
          versionPathHint: versionRel,
          instructionId: instructionId,
          version: version,
          operationId: opId,
          conflictIsMetadataOnly: metaOnly,
          conflictDiffSummary: summary,
          checksum: expectedStable,
        );
      }

      final versionAlreadyOk =
          versionCmp == DevWorkDocSaveOutcome.alreadyExists;
      // isNewVersion은 호출부에서 버전 번호를 올린 뒤 전달됨 (파이프라인은 덮어쓰기 금지).

      late final ({String? text, int size}) versionRead;
      var recovered = false;

      if (versionAlreadyOk) {
        _log(
          DevWorkDocSaveStep.versionFileReread,
          'reuse existing Versions (same core)',
        );
        versionRead = existingVersion;
        // Active가 없거나 핵심이 다르면 Versions 내용으로 Active 복구
        if (activeCmp != DevWorkDocSaveOutcome.alreadyExists) {
          recovered = true;
        }
      } else {
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

      // Active에는 Versions 스냅샷(존재 시)을 기준으로 기록 — 재시도 시 메타 드리프트 방지
      final activePayload = versionRead.text ?? jsonText;

      _log(DevWorkDocSaveStep.activeDir, '$artifactFolder/Active');
      try {
        await fs.ensureDir([artifactFolder, 'Active'], create: true);
        _log(DevWorkDocSaveStep.activeFileCreate, activeRel);
        _log(
          DevWorkDocSaveStep.activeFileWrite,
          '${activePayload.length} chars',
        );
        await fs.writeFile(
          [artifactFolder, 'Active'],
          activeFile,
          activePayload,
        );
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
              '다음 행동: 「기존 버전 확인 및 복구」로 Active를 복구하세요 (Versions는 유지).',
          errorCode: 'partial_active',
          activeVerified: false,
          versionsVerified: true,
          versionsBytes: versionRead.size,
          checksum: stableContentChecksum(activePayload),
          instructionId: instructionId,
          version: version,
          operationId: opId,
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
              '오류: $e\n다음 행동: 「기존 버전 확인 및 복구」로 Active를 복구하세요.',
          errorCode: 'partial_active',
          activeVerified: false,
          versionsVerified: true,
          versionsBytes: versionRead.size,
          checksum: stableContentChecksum(activePayload),
          instructionId: instructionId,
          version: version,
          operationId: opId,
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
              '오류: NotFoundError\n다음 행동: 「기존 버전 확인 및 복구」로 Active를 복구하세요.',
          errorCode: 'partial_active',
          activeVerified: false,
          versionsVerified: true,
          versionsBytes: versionRead.size,
          checksum: stableContentChecksum(activePayload),
          instructionId: instructionId,
          version: version,
          operationId: opId,
        );
      }

      _log(DevWorkDocSaveStep.checksum, 'verify');
      final verified = verifyWrittenPair(
        DevWorkDocVerifyInput(
          expectedJson: activePayload,
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
          instructionId: instructionId,
          version: version,
          operationId: opId,
        );
      }

      final outcome = recovered
          ? DevWorkDocSaveOutcome.recoveredFromPartial
          : (versionAlreadyOk
                ? DevWorkDocSaveOutcome.alreadyExists
                : DevWorkDocSaveOutcome.completeSuccess);

      return DevWorkDocWriteResult(
        ok: true,
        mode: 'folder',
        outcome: outcome,
        activePathHint: activeRel,
        versionPathHint: versionRel,
        checksum: verified.checksum,
        fileName: activeFile,
        activeVerified: true,
        versionsVerified: true,
        activeBytes: activeRead.size,
        versionsBytes: versionRead.size,
        instructionId: instructionId,
        version: version,
        operationId: opId,
        message: recovered
            ? '부분 저장 복구 완료: 기존 Versions v$version 확인 후 Active 생성·검증\n'
                  'Active: $activeRel (${activeRead.size}B)\n'
                  'Versions: $versionRel (${versionRead.size}B)'
            : versionAlreadyOk
            ? '기존 Versions 확인 후 Active 동기화 완료'
            : '완전 성공: Active ${activeRead.size}B · Versions ${versionRead.size}B 검증 완료\n'
                  'Active: $activeRel\nVersions: $versionRel',
      );
    } on FsNotFoundException catch (e) {
      return DevWorkDocWriteResult.failed(
        message:
            '실패 단계: ${e.step}\n대상: ${e.relativePath}\n오류: NotFoundError\n${e.message}',
        errorCode: 'not_found',
        activePathHint: activeRel,
        versionPathHint: versionRel,
        instructionId: instructionId,
        version: version,
        operationId: opId,
      );
    } on DevWorkDocStepError catch (e) {
      return DevWorkDocWriteResult.failed(
        message: e.userMessage,
        errorCode: 'step_failed',
        activePathHint: activeRel,
        versionPathHint: versionRel,
        instructionId: instructionId,
        version: version,
        operationId: opId,
      );
    } catch (e) {
      return DevWorkDocWriteResult.failed(
        message: '실패 단계: unknown\n대상: $versionRel | $activeRel\n오류: $e',
        errorCode: 'write_failed',
        activePathHint: activeRel,
        versionPathHint: versionRel,
        instructionId: instructionId,
        version: version,
        operationId: opId,
      );
    }
  }

  /// Versions의 특정 버전 JSON으로 Active만 복구 (덮어쓰기 승인된 복구 경로).
  Future<DevWorkDocWriteResult> restoreActiveFromVersionText({
    required String artifactType,
    required String instructionId,
    required int version,
    required String versionJsonText,
  }) async {
    final safeId = DevWorkDocPaths.sanitizeInstructionId(instructionId);
    final artifactFolder = DevWorkDocPaths.artifactFolder(artifactType);
    final activeFile = '${DevWorkDocPaths.wiBaseName(instructionId)}.json';
    final versionFile =
        '${DevWorkDocPaths.wiBaseName(instructionId)}_v$version.json';
    final activeRel = '$artifactFolder/Active/$activeFile';
    final versionRel = '$artifactFolder/Versions/$safeId/$versionFile';

    try {
      await fs.ensureDir([artifactFolder, 'Active'], create: true);
      await fs.writeFile(
        [artifactFolder, 'Active'],
        activeFile,
        versionJsonText,
      );
      final activeRead = await fs.readFile([
        artifactFolder,
        'Active',
      ], activeFile);
      if (activeRead.text == null || activeRead.size <= 0) {
        return DevWorkDocWriteResult.failed(
          message:
              '실패 단계: active_file_reread\n대상: $activeRel\n오류: NotFoundError\n'
              'Active 복구 검증 실패',
          errorCode: 'restore_failed',
          activePathHint: activeRel,
          versionPathHint: versionRel,
          instructionId: instructionId,
          version: version,
        );
      }
      final sum = stableContentChecksum(versionJsonText);
      if (stableContentChecksum(activeRead.text!) != sum) {
        return DevWorkDocWriteResult.failed(
          message: 'Active 복구 후 checksum 불일치',
          errorCode: 'restore_checksum',
          instructionId: instructionId,
          version: version,
        );
      }
      return DevWorkDocWriteResult(
        ok: true,
        mode: 'folder',
        outcome: DevWorkDocSaveOutcome.recoveredFromPartial,
        activePathHint: activeRel,
        versionPathHint: versionRel,
        checksum: sum,
        activeVerified: true,
        versionsVerified: true,
        activeBytes: activeRead.size,
        versionsBytes: versionJsonText.length,
        instructionId: instructionId,
        version: version,
        message:
            '부분 저장 복구 완료: Versions v$version → Active\n'
            'Active: $activeRel (${activeRead.size}B)',
      );
    } catch (e) {
      return DevWorkDocWriteResult.failed(
        message: 'Active 복구 실패: $e',
        errorCode: 'restore_failed',
        instructionId: instructionId,
        version: version,
      );
    }
  }
}
