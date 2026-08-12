import 'dart:convert';

import '../models/artifact_type.dart';
import '../models/remote_agent_models.dart';
import 'dev_work_doc_service.dart';

/// Loads existing Active work-instruction JSON for remote START_JOB.
class RemoteWorkInstructionSource {
  RemoteWorkInstructionSource({
    DevWorkDocService? docs,
    List<ActiveWorkInstructionRef>? memoryCatalog,
  }) : _docs = docs ?? DevWorkDocService(),
       _memory = List<ActiveWorkInstructionRef>.from(memoryCatalog ?? const []);

  final DevWorkDocService _docs;
  final List<ActiveWorkInstructionRef> _memory;

  void seedMemory(List<ActiveWorkInstructionRef> items) {
    _memory
      ..clear()
      ..addAll(items);
  }

  Future<List<ActiveWorkInstructionRef>> listActive(String artifactType) async {
    final normalized = ArtifactType.normalize(artifactType);
    final fromDisk = await _docs.listActiveInstructions(normalized);
    if (fromDisk.isNotEmpty) {
      return fromDisk
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
    }
    return _memory.where((e) => e.artifactType == normalized).toList();
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
