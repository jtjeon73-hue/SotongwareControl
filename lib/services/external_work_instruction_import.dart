/// Safe external Commercial V2 WI / handoff import for existing Control deliver.
/// Data-only: never executes paths/scripts from JSON.
library;

import 'dart:convert';

import '../models/artifact_type.dart';
import 'commercial_work_instruction_preflight.dart';

enum ExternalWiImportKind { rawWorkInstruction, handoffEnvelope }

class ExternalWiImportIssue {
  const ExternalWiImportIssue({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

class ExternalWiImportResult {
  const ExternalWiImportResult({
    required this.ok,
    required this.kind,
    required this.issues,
    this.instructionId = '',
    this.title = '',
    this.type = '',
    this.assignedAgentId = '',
    this.approvalMode = '',
    this.executionMode = '',
    this.totalStages = 0,
    this.payload = const {},
    this.ignoredHandoffJobId = '',
    this.ignoredHandoffCommandId = '',
    this.ignoredHandoffIdempotencyKey = '',
    this.sourceWasHandoff = false,
  });

  final bool ok;
  final ExternalWiImportKind kind;
  final List<ExternalWiImportIssue> issues;
  final String instructionId;
  final String title;
  final String type;
  final String assignedAgentId;
  final String approvalMode;
  final String executionMode;
  final int totalStages;

  /// Authoritative flat WI payload for WorkInstructionRemoteDelivery.deliver.
  final Map<String, dynamic> payload;

  final String ignoredHandoffJobId;
  final String ignoredHandoffCommandId;
  final String ignoredHandoffIdempotencyKey;
  final bool sourceWasHandoff;

  factory ExternalWiImportResult.fail(
    List<ExternalWiImportIssue> issues, {
    ExternalWiImportKind kind = ExternalWiImportKind.rawWorkInstruction,
  }) {
    return ExternalWiImportResult(
      ok: false,
      kind: kind,
      issues: issues,
    );
  }
}

/// Parse + normalize external JSON into a deliver-ready flat WI payload.
class ExternalWorkInstructionImport {
  ExternalWorkInstructionImport._();

  static const expectedEbookStages = 18;

  static ExternalWiImportResult parseText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return ExternalWiImportResult.fail(const [
        ExternalWiImportIssue(code: 'EMPTY_JSON', message: 'JSON이 비어 있습니다.'),
      ]);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return ExternalWiImportResult.fail(const [
        ExternalWiImportIssue(code: 'INVALID_JSON', message: 'JSON 파싱에 실패했습니다.'),
      ]);
    }
    return parseDecoded(decoded);
  }

  static ExternalWiImportResult parseDecoded(Object? decoded) {
    if (decoded is! Map) {
      return ExternalWiImportResult.fail(const [
        ExternalWiImportIssue(
          code: 'NOT_OBJECT',
          message: '루트 JSON은 객체여야 합니다.',
        ),
      ]);
    }
    final root = Map<String, dynamic>.from(decoded);

    final isHandoff = _looksLikeHandoff(root);
    if (isHandoff) {
      return _fromHandoff(root);
    }
    return _fromRawWi(root, sourceWasHandoff: false);
  }

  static bool _looksLikeHandoff(Map<String, dynamic> root) {
    final type = '${root['type'] ?? ''}'.trim().toUpperCase();
    final payload = root['payload'];
    if (payload is Map && payload['workInstruction'] is Map) return true;
    if (type == 'START_JOB' && payload is Map) return true;
    return false;
  }

  static ExternalWiImportResult _fromHandoff(Map<String, dynamic> root) {
    final payload = root['payload'];
    if (payload is! Map) {
      return ExternalWiImportResult.fail(const [
        ExternalWiImportIssue(
          code: 'HANDOFF_PAYLOAD_MISSING',
          message: 'handoff payload가 없습니다.',
        ),
      ], kind: ExternalWiImportKind.handoffEnvelope);
    }
    final p = Map<String, dynamic>.from(payload);
    final wiNode = p['workInstruction'];
    if (wiNode is! Map) {
      // Allow already-flat payload inside handoff.payload
      if ('${p['instructionId'] ?? ''}'.trim().isNotEmpty &&
          p['workflowSteps'] is List) {
        return _fromRawWi(
          p,
          sourceWasHandoff: true,
          assignedAgentHint: '${root['agentId'] ?? ''}'.trim(),
          ignoredJobId: '${root['jobId'] ?? ''}'.trim(),
          ignoredCommandId: '${root['commandId'] ?? ''}'.trim(),
          ignoredIdem: '${root['idempotencyKey'] ?? ''}'.trim(),
        );
      }
      return ExternalWiImportResult.fail(const [
        ExternalWiImportIssue(
          code: 'HANDOFF_WI_MISSING',
          message: 'handoff payload.workInstruction이 없습니다.',
        ),
      ], kind: ExternalWiImportKind.handoffEnvelope);
    }

    return _fromRawWi(
      Map<String, dynamic>.from(wiNode),
      sourceWasHandoff: true,
      assignedAgentHint: '${root['agentId'] ?? ''}'.trim(),
      ignoredJobId: '${root['jobId'] ?? ''}'.trim(),
      ignoredCommandId: '${root['commandId'] ?? ''}'.trim(),
      ignoredIdem: '${root['idempotencyKey'] ?? ''}'.trim(),
      topLevelInstructionId: '${root['instructionId'] ?? ''}'.trim(),
    );
  }

  static ExternalWiImportResult _fromRawWi(
    Map<String, dynamic> wiIn, {
    required bool sourceWasHandoff,
    String assignedAgentHint = '',
    String ignoredJobId = '',
    String ignoredCommandId = '',
    String ignoredIdem = '',
    String topLevelInstructionId = '',
  }) {
    final issues = <ExternalWiImportIssue>[];
    // Deep copy for authoritative payload isolation (preserve fields; no WI model
    // round-trip). Dart JSON maps keep insertion order from the source object.
    final wi = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(wiIn)) as Map,
    );

    final schema = '${wi['schemaVersion'] ?? ''}'.trim();
    if (schema != '1.1') {
      issues.add(ExternalWiImportIssue(
        code: 'WRONG_SCHEMA',
        message: 'schemaVersion 1.1이 필요합니다 (got: $schema).',
      ));
    }

    final instructionId = '${wi['instructionId'] ?? ''}'.trim();
    if (instructionId.isEmpty) {
      issues.add(const ExternalWiImportIssue(
        code: 'MISSING_INSTRUCTION_ID',
        message: 'instructionId가 필요합니다.',
      ));
    }
    if (topLevelInstructionId.isNotEmpty &&
        instructionId.isNotEmpty &&
        topLevelInstructionId != instructionId) {
      issues.add(ExternalWiImportIssue(
        code: 'INSTRUCTION_ID_MISMATCH',
        message:
            'top-level instructionId($topLevelInstructionId)와 payload instructionId($instructionId)가 일치하지 않습니다.',
      ));
    }

    final artifact = ArtifactType.normalize(
      '${wi['artifactType'] ?? wi['type'] ?? ''}',
    );
    if (artifact != ArtifactType.ebook) {
      issues.add(ExternalWiImportIssue(
        code: 'NON_EBOOK_REJECTED',
        message:
            '이 bridge는 ebook Commercial V2 WI만 지원합니다 (got: $artifact).',
      ));
    }

    final steps = wi['workflowSteps'];
    if (steps is! List || steps.isEmpty) {
      issues.add(const ExternalWiImportIssue(
        code: 'WORKFLOW_STEPS_MISSING',
        message: 'workflowSteps가 필요합니다.',
      ));
    } else if (steps.length != expectedEbookStages) {
      issues.add(ExternalWiImportIssue(
        code: 'WORKFLOW_STEPS_COUNT',
        message:
            'Commercial V2는 workflowSteps $expectedEbookStages개가 필요합니다 (got: ${steps.length}).',
      ));
    } else {
      final first = steps.first;
      if (first is Map) {
        final sid = '${first['id'] ?? ''}'.trim();
        if (sid.isNotEmpty && sid != 'idea_clarify') {
          issues.add(ExternalWiImportIssue(
            code: 'WORKFLOW_STEP1_UNEXPECTED',
            message: '1단계 id는 idea_clarify여야 합니다 (got: $sid).',
          ));
        }
      }
    }

    final title = '${wi['businessIdea'] ?? wi['title'] ?? ''}'.trim();
    if (title.isEmpty) {
      issues.add(const ExternalWiImportIssue(
        code: 'MISSING_TITLE',
        message: 'title/businessIdea가 필요합니다.',
      ));
    }

    final ai = wi['aiExecution'];
    var approvalMode = '';
    var executionMode = '';
    if (ai is Map) {
      approvalMode = '${ai['approvalMode'] ?? ''}'.trim();
      executionMode = '${ai['executionMode'] ?? ''}'.trim();
    }
    if (approvalMode.isEmpty) {
      issues.add(const ExternalWiImportIssue(
        code: 'MISSING_APPROVAL_MODE',
        message: 'aiExecution.approvalMode가 필요합니다.',
      ));
    }
    if (executionMode.isEmpty) {
      issues.add(const ExternalWiImportIssue(
        code: 'MISSING_EXECUTION_MODE',
        message: 'aiExecution.executionMode가 필요합니다.',
      ));
    }

    // Authoritative external WI fields are preserved as-is (including
    // workInstructionBrief.titleSource=user_confirmed from Batch mint).
    // Do not rewrite brief metadata to satisfy a narrower Control-only enum.

    // Reuse Control commercial preflight (same gate as normal deliver).
    if (issues.isEmpty && CommercialWorkInstructionPreflight.isSchema11(wi)) {
      final commercial = CommercialWorkInstructionPreflight.evaluate(wi);
      if (!commercial.ok) {
        for (final e in commercial.errors) {
          issues.add(ExternalWiImportIssue(
            code: e.code,
            message: e.userMessageKo,
          ));
        }
        if (commercial.errors.isEmpty) {
          issues.add(const ExternalWiImportIssue(
            code: 'COMMERCIAL_PREFLIGHT_BLOCKED',
            message: '상용 품질 계약(brief/profile) 검증에 실패했습니다.',
          ));
        }
      }
    }

    final assigned = assignedAgentHint.trim();
    final totalStages = steps is List && steps.isNotEmpty
        ? steps.length
        : expectedEbookStages;

    if (issues.isNotEmpty) {
      return ExternalWiImportResult(
        ok: false,
        kind: sourceWasHandoff
            ? ExternalWiImportKind.handoffEnvelope
            : ExternalWiImportKind.rawWorkInstruction,
        issues: issues,
        instructionId: instructionId,
        title: title,
        type: artifact,
        assignedAgentId: assigned,
        approvalMode: approvalMode,
        executionMode: executionMode,
        totalStages: totalStages,
        payload: wi,
        ignoredHandoffJobId: ignoredJobId,
        ignoredHandoffCommandId: ignoredCommandId,
        ignoredHandoffIdempotencyKey: ignoredIdem,
        sourceWasHandoff: sourceWasHandoff,
      );
    }

    // Ensure instructionId consistency on payload for deliver API.
    wi['instructionId'] = instructionId;

    return ExternalWiImportResult(
      ok: true,
      kind: sourceWasHandoff
          ? ExternalWiImportKind.handoffEnvelope
          : ExternalWiImportKind.rawWorkInstruction,
      issues: const [],
      instructionId: instructionId,
      title: title,
      type: ArtifactType.ebook,
      assignedAgentId: assigned,
      approvalMode: approvalMode,
      executionMode: executionMode,
      totalStages: totalStages,
      payload: wi,
      ignoredHandoffJobId: ignoredJobId,
      ignoredHandoffCommandId: ignoredCommandId,
      ignoredHandoffIdempotencyKey: ignoredIdem,
      sourceWasHandoff: sourceWasHandoff,
    );
  }

  /// Identity equality for duplicate-import checks (instruction + revision/batch).
  static String identityKey(ExternalWiImportResult r) {
    final rev = '${r.payload['revision'] ?? ''}';
    final batch = '${r.payload['batchId'] ?? ''}';
    return '${r.instructionId}|r=$rev|b=$batch';
  }

  /// Canonical JSON for semantic field equality (key-order / formatting independent).
  static String semanticCanonicalJson(Object? value) =>
      jsonEncode(_canonicalize(value));

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      return {
        for (final k in keys) k: _canonicalize(value[k]),
      };
    }
    if (value is List) {
      return [for (final e in value) _canonicalize(e)];
    }
    return value;
  }

  /// Recursive semantic diff paths between two JSON-like trees.
  static List<String> semanticDiffPaths(Object? a, Object? b, [String path = r'$']) {
    if (a is Map && b is Map) {
      final keys = <String>{
        ...a.keys.map((k) => '$k'),
        ...b.keys.map((k) => '$k'),
      };
      final out = <String>[];
      for (final k in keys.toList()..sort()) {
        out.addAll(semanticDiffPaths(a[k], b[k], '$path.$k'));
      }
      return out;
    }
    if (a is List && b is List) {
      final out = <String>[];
      final n = a.length > b.length ? a.length : b.length;
      for (var i = 0; i < n; i++) {
        out.addAll(semanticDiffPaths(
          i < a.length ? a[i] : null,
          i < b.length ? b[i] : null,
          '$path[$i]',
        ));
      }
      return out;
    }
    if (semanticCanonicalJson(a) == semanticCanonicalJson(b)) return const [];
    return [path];
  }
}
