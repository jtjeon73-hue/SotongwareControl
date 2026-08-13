import 'dart:convert';

import '../models/artifact_type.dart';
import '../models/remote_agent_models.dart';
import 'dev_work_doc_paths.dart';
import 'dev_work_doc_service.dart';
import 'remote_work_instruction_mirror.dart';

/// Loads Active work-instruction JSON for remote START_JOB.
/// Prefer Firestore mirror (mobile); merge local DevWorkDoc when available (PC).
class RemoteWorkInstructionSource {
  RemoteWorkInstructionSource({
    DevWorkDocService? docs,
    RemoteWorkInstructionMirrorService? mirror,
    List<ActiveWorkInstructionRef>? memoryCatalog,
  }) : _docs = docs ?? DevWorkDocService(),
       _mirror = mirror ?? RemoteWorkInstructionMirrorService(),
       _memory = List<ActiveWorkInstructionRef>.from(memoryCatalog ?? const []);

  final DevWorkDocService _docs;
  final RemoteWorkInstructionMirrorService _mirror;
  final List<ActiveWorkInstructionRef> _memory;

  void seedMemory(List<ActiveWorkInstructionRef> items) {
    _memory
      ..clear()
      ..addAll(items);
  }

  Future<List<ActiveWorkInstructionRef>> listActive(String artifactType) async {
    final normalized = ArtifactType.normalize(artifactType);

    final fromCloud = await _mirror.listActive(artifactType: normalized);
    final fromDisk = await _docs.listActiveInstructions(normalized);
    final diskMapped = fromDisk
        .map(
          (e) => ActiveWorkInstructionRef(
            artifactType: normalized,
            instructionId: e.instructionId,
            title: e.title.isEmpty ? e.instructionId : e.title,
            jsonText: e.jsonText,
            version: e.version,
            totalStages: e.totalStages,
          ),
        )
        .toList();

    return _mergeByInstructionId([
      ...fromCloud,
      ...diskMapped,
      ..._memory.where((e) => e.artifactType == normalized),
    ]);
  }

  /// Cloud first, then disk/memory fill gaps. Same instructionId = one row (cloud wins).
  static List<ActiveWorkInstructionRef> _mergeByInstructionId(
    List<ActiveWorkInstructionRef> items,
  ) {
    final map = <String, ActiveWorkInstructionRef>{};
    for (final item in items) {
      final key =
          '${item.artifactType}__${DevWorkDocPaths.sanitizeInstructionId(item.instructionId)}';
      map.putIfAbsent(key, () => item);
    }
    final out = map.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return out;
  }

  ActiveWorkInstructionRef? parseJsonText(
    String jsonText, {
    String? artifactHint,
  }) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final id = '${map['instructionId'] ?? ''}'.trim();
      if (id.isEmpty) return null;
      final title = '${map['title'] ?? map['projectName'] ?? id}'.trim();
      final artifact = ArtifactType.normalize(
        '${map['artifactType'] ?? map['deliverableType'] ?? artifactHint ?? ''}',
      );
      final version = int.tryParse('${map['version'] ?? 1}') ?? 1;
      var total = 18;
      final stages = map['stages'];
      if (stages is List && stages.isNotEmpty) total = stages.length;
      if (map['totalStages'] != null) {
        total = int.tryParse('${map['totalStages']}') ?? total;
      }
      return ActiveWorkInstructionRef(
        artifactType: artifact == ArtifactType.undecided
            ? (artifactHint ?? ArtifactType.ebook)
            : artifact,
        instructionId: id,
        title: title.isEmpty ? id : title,
        jsonText: jsonText,
        version: version,
        totalStages: total,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? payloadMap(ActiveWorkInstructionRef ref) {
    try {
      final decoded = jsonDecode(ref.jsonText);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
