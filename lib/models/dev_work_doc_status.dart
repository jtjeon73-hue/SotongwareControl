/// DevWorkDoc 저장·전달 상태 (아이콘+텍스트, 색상만으로 구분하지 않음).
library;

import 'package:flutter/material.dart';

import '../services/dev_work_doc_types.dart';
import '../services/instruction_transfer_types.dart';
import '../services/work_instruction_validator.dart';
import 'business_planning.dart';

enum DevWorkDocSaveTarget { folder, downloadOnly }

enum DevWorkDocStatusKind {
  folderNotSet,
  folderReady,
  localSaveComplete,
  browserDownloadComplete,
  activeFileCreated,
  versionsFileCreated,
  transferReady,
  transferComplete,
  failed,
}

class DevWorkDocStatus {
  const DevWorkDocStatus({
    required this.kind,
    required this.label,
    required this.icon,
    required this.nextAction,
    this.failureReason,
    this.activePathHint,
    this.versionPathHint,
  });

  final DevWorkDocStatusKind kind;
  final String label;
  final IconData icon;
  final String nextAction;
  final String? failureReason;
  final String? activePathHint;
  final String? versionPathHint;

  String get displayLabel => failureReason == null || failureReason!.isEmpty
      ? label
      : '$label — $failureReason';

  static DevWorkDocStatus resolve({
    required DevWorkDocState? devDocState,
    required DevWorkDocWriteResult? lastSaveResult,
    required WorkInstruction? instruction,
    required BusinessPlanDocument? activeDoc,
    required FolderPermissionState? transferFolder,
    required BusinessPlanInput input,
  }) {
    if (lastSaveResult != null) {
      if (lastSaveResult.mode == 'download' ||
          lastSaveResult.outcome == DevWorkDocSaveOutcome.downloadOnly) {
        return DevWorkDocStatus(
          kind: DevWorkDocStatusKind.browserDownloadComplete,
          label: '브라우저 다운로드 완료 (DevWorkDoc 직접 저장 아님)',
          icon: Icons.download_done,
          nextAction:
              '다운로드한 JSON을 DevWorkDoc 폴더에 수동 배치하거나, '
              '「DevWorkDoc에 저장」으로 폴더에 직접 저장하세요.',
          activePathHint: lastSaveResult.activePathHint,
          versionPathHint: lastSaveResult.versionPathHint,
        );
      }

      if (!lastSaveResult.ok) {
        return DevWorkDocStatus(
          kind: DevWorkDocStatusKind.failed,
          label: '실패',
          icon: Icons.error_outline,
          nextAction: '오류를 확인한 뒤 다시 저장하세요.',
          failureReason: lastSaveResult.message ?? lastSaveResult.errorCode,
        );
      }
    }

    final planStatus = activeDoc == null
        ? PlanningStatus.draft
        : PlanningStatus.normalize(activeDoc.status);

    if (planStatus == PlanningStatus.transferred ||
        planStatus == PlanningStatus.imported) {
      return const DevWorkDocStatus(
        kind: DevWorkDocStatusKind.transferComplete,
        label: '전달 완료',
        icon: Icons.check_circle_outline,
        nextAction: '소통24워크에서 가져오기·실행을 진행하세요.',
      );
    }

    if (instruction != null) {
      final validation = WorkInstructionValidator().validate(
        input: input,
        instruction: instruction,
      );
      final folderReady = transferFolder?.hasHandle == true;
      if (validation.ok && folderReady) {
        return DevWorkDocStatus(
          kind: DevWorkDocStatusKind.transferReady,
          label: '소통24워크 전달 준비 완료',
          icon: Icons.outbound,
          nextAction: '「소통24워크로 전달」 버튼으로 Inbox에 저장하세요.',
        );
      }
    }

    if (lastSaveResult != null && lastSaveResult.ok) {
      if (lastSaveResult.mode == 'folder') {
        final version = instruction?.instructionVersion;
        final isMultiVersion =
            version != null &&
            int.tryParse(version) != null &&
            int.parse(version) > 1;

        if (isMultiVersion) {
          return DevWorkDocStatus(
            kind: DevWorkDocStatusKind.versionsFileCreated,
            label: 'Versions 파일 생성 완료',
            icon: Icons.history,
            nextAction:
                'Active: ${lastSaveResult.activePathHint ?? '—'} · '
                'Versions: ${lastSaveResult.versionPathHint ?? '—'}',
            activePathHint: lastSaveResult.activePathHint,
            versionPathHint: lastSaveResult.versionPathHint,
          );
        }

        if (lastSaveResult.activePathHint != null) {
          return DevWorkDocStatus(
            kind: DevWorkDocStatusKind.activeFileCreated,
            label: 'Active 파일 생성 완료',
            icon: Icons.insert_drive_file_outlined,
            nextAction:
                'Active: ${lastSaveResult.activePathHint}'
                '${lastSaveResult.versionPathHint != null ? ' · Versions: ${lastSaveResult.versionPathHint}' : ''}',
            activePathHint: lastSaveResult.activePathHint,
            versionPathHint: lastSaveResult.versionPathHint,
          );
        }

        return const DevWorkDocStatus(
          kind: DevWorkDocStatusKind.localSaveComplete,
          label: '로컬 DevWorkDoc 저장 완료',
          icon: Icons.folder_special_outlined,
          nextAction: '작업지시서가 DevWorkDoc 폴더에 저장되었습니다.',
        );
      }
    }

    final devDoc = devDocState;
    if (devDoc != null && devDoc.readyToWrite) {
      return const DevWorkDocStatus(
        kind: DevWorkDocStatusKind.folderReady,
        label: '저장 준비 완료',
        icon: Icons.folder_open,
        nextAction: '「DevWorkDoc에 저장」으로 작업지시서를 폴더에 저장하세요.',
      );
    }

    if (devDoc != null && devDoc.supported && devDoc.hasRoot) {
      return const DevWorkDocStatus(
        kind: DevWorkDocStatusKind.folderReady,
        label: '저장 준비 완료',
        icon: Icons.folder_open,
        nextAction: '「DevWorkDoc에 저장」으로 작업지시서를 폴더에 저장하세요.',
      );
    }

    if (devDoc != null && !devDoc.supported) {
      return const DevWorkDocStatus(
        kind: DevWorkDocStatusKind.folderNotSet,
        label: '저장 폴더 미설정',
        icon: Icons.folder_off_outlined,
        nextAction:
            '이 환경에서는 폴더 직접 저장을 지원하지 않습니다. '
            '「JSON 다운로드」로 파일을 받으세요.',
      );
    }

    return const DevWorkDocStatus(
      kind: DevWorkDocStatusKind.folderNotSet,
      label: '저장 폴더 미설정',
      icon: Icons.folder_off_outlined,
      nextAction: '「작업지시서 관리 폴더를 설정」하세요.',
    );
  }
}
