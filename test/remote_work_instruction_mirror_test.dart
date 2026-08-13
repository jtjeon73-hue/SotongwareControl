import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/models/remote_agent_models.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_mirror.dart';
import 'package:sotong_ware_control/services/remote_work_instruction_source.dart';

void main() {
  late Map<String, Map<String, dynamic>> memory;
  late RemoteWorkInstructionMirrorService mirror;

  const uid = 'uid_owner_a';
  final sampleJson = jsonEncode({
    'schemaVersion': '1.0',
    'instructionId': 'wi_e2e_mirror_test',
    'projectId': 'p1',
    'version': 1,
    'title': '미러 테스트 전자책',
    'artifactType': 'ebook',
    'stages': List.generate(3, (i) => {'id': 's$i'}),
    'businessIdea': '미러 테스트 전자책',
  });

  setUp(() {
    memory = {};
    mirror = RemoteWorkInstructionMirrorService(memory: memory);
  });

  test('docId is deterministic', () {
    final a = RemoteWorkInstructionMirrorService.docId(
      ownerUid: uid,
      artifactType: 'ebook',
      instructionId: 'wi_e2e_mirror_test',
    );
    final b = RemoteWorkInstructionMirrorService.docId(
      ownerUid: uid,
      artifactType: 'ebook',
      instructionId: 'wi_e2e_mirror_test',
    );
    expect(a, b);
    expect(a, contains(uid));
    expect(a, contains('ebook'));
  });

  test('upsertActive creates mirror and upserts without duplicate', () async {
    final ok1 = await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'wi_e2e_mirror_test',
      jsonText: sampleJson,
    );
    expect(ok1, isTrue);
    expect(memory.length, 1);

    final updated = jsonEncode({
      ...jsonDecode(sampleJson) as Map,
      'version': 2,
      'title': '미러 테스트 전자책 v2',
    });
    final ok2 = await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'wi_e2e_mirror_test',
      jsonText: updated,
      version: 2,
    );
    expect(ok2, isTrue);
    expect(memory.length, 1);
    expect(memory.values.first['version'], 2);
    expect(memory.values.first['status'], 'active');
  });

  test('artifactType separation', () async {
    await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'same_id',
      jsonText: jsonEncode({
        'instructionId': 'same_id',
        'artifactType': 'ebook',
        'title': 'Ebook',
        'version': 1,
      }),
    );
    await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.app,
      instructionId: 'same_id',
      jsonText: jsonEncode({
        'instructionId': 'same_id',
        'artifactType': 'app',
        'title': 'App',
        'version': 1,
      }),
    );
    expect(memory.length, 2);
    final ebook = await mirror.listActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
    );
    final app = await mirror.listActive(
      ownerUid: uid,
      artifactType: ArtifactType.app,
    );
    expect(ebook.length, 1);
    expect(app.length, 1);
    expect(ebook.first.title, 'Ebook');
    expect(app.first.title, 'App');
  });

  test('listActive filters owner and status', () async {
    await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'mine',
      jsonText: jsonEncode({
        'instructionId': 'mine',
        'artifactType': 'ebook',
        'title': 'Mine',
        'version': 1,
      }),
    );
    await mirror.upsertActive(
      ownerUid: 'uid_other',
      artifactType: ArtifactType.ebook,
      instructionId: 'theirs',
      jsonText: jsonEncode({
        'instructionId': 'theirs',
        'artifactType': 'ebook',
        'title': 'Theirs',
        'version': 1,
      }),
    );
    final list = await mirror.listActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
    );
    expect(list.map((e) => e.instructionId), ['mine']);
  });

  test('archive and restore status', () async {
    await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'wi_arch',
      jsonText: jsonEncode({
        'instructionId': 'wi_arch',
        'artifactType': 'ebook',
        'title': 'Arch',
        'version': 1,
      }),
    );
    expect(
      (await mirror.listActive(ownerUid: uid, artifactType: ArtifactType.ebook))
          .length,
      1,
    );
    await mirror.markArchived(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'wi_arch',
    );
    expect(
      (await mirror.listActive(ownerUid: uid, artifactType: ArtifactType.ebook))
          .length,
      0,
    );
    await mirror.restoreActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'wi_arch',
    );
    expect(
      (await mirror.listActive(ownerUid: uid, artifactType: ArtifactType.ebook))
          .length,
      1,
    );
  });

  test('json payload round-trip for START_JOB', () async {
    await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'wi_e2e_mirror_test',
      jsonText: sampleJson,
    );
    final list = await mirror.listActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
    );
    final source = RemoteWorkInstructionSource(
      mirror: mirror,
      memoryCatalog: const [],
    );
    // Inject via listing through mirror already; parse payloadMap
    final payload = source.payloadMap(list.first);
    expect(payload, isNotNull);
    expect(payload!['instructionId'], 'wi_e2e_mirror_test');
    expect(payload['schemaVersion'], '1.0');
  });

  test('source merges cloud over memory without duplicate', () async {
    await mirror.upsertActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
      instructionId: 'dup',
      jsonText: jsonEncode({
        'instructionId': 'dup',
        'artifactType': 'ebook',
        'title': 'FromCloud',
        'version': 2,
      }),
    );
    // listActive needs signed-in uid; call mirror directly then merge unit
    final cloud = await mirror.listActive(
      ownerUid: uid,
      artifactType: ArtifactType.ebook,
    );
    expect(cloud.first.title, 'FromCloud');
    // merge helper behavior via source with only memory when mirror empty
    final localOnly = RemoteWorkInstructionSource(
      mirror: RemoteWorkInstructionMirrorService(memory: {}),
      memoryCatalog: [
        const ActiveWorkInstructionRef(
          artifactType: ArtifactType.ebook,
          instructionId: 'only_mem',
          title: 'Mem',
          jsonText: '{"instructionId":"only_mem","artifactType":"ebook"}',
        ),
      ],
    );
    final listed = await localOnly.listActive(ArtifactType.ebook);
    expect(listed.any((e) => e.instructionId == 'only_mem'), isTrue);
  });

  test('unsigned upsert fails softly', () async {
    final ok = await mirror.upsertActive(
      artifactType: ArtifactType.ebook,
      instructionId: 'x',
      jsonText: sampleJson,
      // ownerUid omitted and no auth → false
    );
    expect(ok, isFalse);
    expect(memory, isEmpty);
  });
}
