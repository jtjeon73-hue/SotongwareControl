import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/services/dev_work_doc_fs.dart';
import 'package:sotong_ware_control/services/dev_work_doc_paths.dart';
import 'package:sotong_ware_control/services/dev_work_doc_save_pipeline.dart';
import 'package:sotong_ware_control/services/dev_work_doc_types.dart';
import 'package:sotong_ware_control/services/work_instruction_validator.dart';

/// create:false는 미존재 시 실패, create:true만 생성 — 느슨한 fake 금지.
class StrictMemoryFs extends MemoryDevWorkDocFs {
  /// Active 쓰기만 실패시키는 플래그 (부분 성공 테스트).
  bool failActiveWrite = false;

  @override
  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  ) async {
    if (failActiveWrite &&
        dirSegments.length >= 2 &&
        dirSegments[1] == 'Active') {
      throw FsNotFoundException(
        step: DevWorkDocSaveStep.activeFileWrite,
        relativePath: [...dirSegments, fileName].join('/'),
        message: 'simulated Active write NotFound',
      );
    }
    await super.writeFile(dirSegments, fileName, content);
  }
}

void main() {
  const iid = 'wi_plan_ebook_test';
  const artifact = 'ebook';

  String jsonFor({
    required String id,
    required int version,
    String extra = '',
  }) {
    final map = <String, dynamic>{
      'instructionId': id,
      'instructionVersion': '$version',
      'artifactType': artifact,
      'title': '테스트$extra',
      'checksum': 'field_$version$extra',
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  StrictMemoryFs seededFs() {
    final fs = StrictMemoryFs();
    // 실제 운영과 동일: 정적 폴더만 + .gitkeep
    fs.dirs.addAll({
      '/Ebook/',
      '/Ebook/Active/',
      '/Ebook/Versions/',
      '/Ebook/Archive/',
    });
    fs.files['/Ebook/Active/.gitkeep'] = '';
    fs.files['/Ebook/Versions/.gitkeep'] = '';
    return fs;
  }

  group('MemoryDevWorkDocFs create contract', () {
    test('create:false on missing instructionId dir throws NotFound', () async {
      final fs = seededFs();
      expect(
        () => fs.ensureDir(['Ebook', 'Versions', iid], create: false),
        throwsA(isA<FsNotFoundException>()),
      );
      expect(await fs.dirExists(['Ebook', 'Versions', iid]), isFalse);
    });

    test('create:true creates dynamic instructionId folder', () async {
      final fs = seededFs();
      await fs.ensureDir(['Ebook', 'Versions', iid], create: true);
      expect(await fs.dirExists(['Ebook', 'Versions', iid]), isTrue);
    });
  });

  group('DevWorkDocSavePipeline', () {
    test('1-5: first v1 save with only static folders and gitkeep', () async {
      final fs = seededFs();
      final pipeline = DevWorkDocSavePipeline(fs);
      final json = jsonFor(id: iid, version: 1);

      final result = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: json,
      );

      expect(result.ok, isTrue);
      expect(result.outcome, DevWorkDocSaveOutcome.completeSuccess);
      expect(result.activeVerified, isTrue);
      expect(result.versionsVerified, isTrue);
      expect(result.activeBytes, greaterThan(0));
      expect(result.versionsBytes, greaterThan(0));
      expect(result.activePathHint, 'Ebook/Active/WI_$iid.json');
      expect(result.versionPathHint, 'Ebook/Versions/$iid/WI_${iid}_v1.json');

      expect(await fs.dirExists(['Ebook', 'Versions', iid]), isTrue);
      final active = await fs.readFile(['Ebook', 'Active'], 'WI_$iid.json');
      final version = await fs.readFile([
        'Ebook',
        'Versions',
        iid,
      ], 'WI_${iid}_v1.json');
      expect(active.text, json);
      expect(version.text, json);
      // gitkeep 유지
      expect(fs.files.containsKey('/Ebook/Active/.gitkeep'), isTrue);
    });

    test('6: Versions saved before Active (order)', () async {
      final fs = seededFs();
      final order = <String>[];
      final tracking = _OrderTrackingFs(fs, order);
      final pipeline = DevWorkDocSavePipeline(tracking);
      await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: jsonFor(id: iid, version: 1),
      );
      final versionWrite = order.indexWhere(
        (e) => e.startsWith('write:Ebook/Versions/'),
      );
      final activeWrite = order.indexWhere(
        (e) => e.startsWith('write:Ebook/Active/'),
      );
      expect(versionWrite, greaterThanOrEqualTo(0));
      expect(activeWrite, greaterThan(versionWrite));
    });

    test('7: v1 then v2 creates second version file', () async {
      final fs = seededFs();
      final pipeline = DevWorkDocSavePipeline(fs);
      final v1 = jsonFor(id: iid, version: 1);
      final v2 = jsonFor(id: iid, version: 2, extra: '_v2');

      expect(
        (await pipeline.saveInstruction(
          artifactType: artifact,
          instructionId: iid,
          version: 1,
          jsonText: v1,
        )).ok,
        isTrue,
      );
      expect(
        (await pipeline.saveInstruction(
          artifactType: artifact,
          instructionId: iid,
          version: 2,
          jsonText: v2,
          isNewVersion: true,
        )).ok,
        isTrue,
      );

      expect(
        (await fs.readFile([
          'Ebook',
          'Versions',
          iid,
        ], 'WI_${iid}_v1.json')).text,
        v1,
      );
      expect(
        (await fs.readFile([
          'Ebook',
          'Versions',
          iid,
        ], 'WI_${iid}_v2.json')).text,
        v2,
      );
      expect((await fs.readFile(['Ebook', 'Active'], 'WI_$iid.json')).text, v2);
    });

    test('8: same checksum resave does not duplicate', () async {
      final fs = seededFs();
      final pipeline = DevWorkDocSavePipeline(fs);
      final json = jsonFor(id: iid, version: 1);
      final first = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: json,
      );
      final second = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: json,
      );
      expect(first.outcome, DevWorkDocSaveOutcome.completeSuccess);
      expect(second.outcome, DevWorkDocSaveOutcome.alreadyExists);
      expect(second.checksum, contentChecksum(json));
      // 버전 파일 하나
      final versionKeys = fs.files.keys
          .where((k) => k.contains('/Versions/$iid/'))
          .toList();
      expect(versionKeys.length, 1);
    });

    test(
      '9: Versions ok Active fail then retry recovers Active only',
      () async {
        final fs = seededFs();
        final pipeline = DevWorkDocSavePipeline(fs);
        final json = jsonFor(id: iid, version: 1);

        fs.failActiveWrite = true;
        final partial = await pipeline.saveInstruction(
          artifactType: artifact,
          instructionId: iid,
          version: 1,
          jsonText: json,
        );
        expect(partial.ok, isFalse);
        expect(partial.outcome, DevWorkDocSaveOutcome.partialSuccess);
        expect(partial.versionsVerified, isTrue);
        expect(partial.activeVerified, isFalse);
        expect(
          (await fs.readFile([
            'Ebook',
            'Versions',
            iid,
          ], 'WI_${iid}_v1.json')).text,
          json,
        );
        expect(
          (await fs.readFile(['Ebook', 'Active'], 'WI_$iid.json')).text,
          isNull,
        );

        fs.failActiveWrite = false;
        final retry = await pipeline.saveInstruction(
          artifactType: artifact,
          instructionId: iid,
          version: 1,
          jsonText: json,
        );
        // Versions already same → may be alreadyExists if Active also written,
        // or completeSuccess after Active write
        expect(retry.ok, isTrue);
        expect(
          (await fs.readFile(['Ebook', 'Active'], 'WI_$iid.json')).text,
          json,
        );
      },
    );

    test('10: forbidden chars in instructionId sanitized for path', () async {
      final fs = seededFs();
      final pipeline = DevWorkDocSavePipeline(fs);
      const rawId = r'wi_plan/a\b:c*d?e"f<g>h|i';
      final safe = DevWorkDocPaths.sanitizeInstructionId(rawId);
      expect(safe.contains('/'), isFalse);
      expect(safe.contains(r'\'), isFalse);
      expect(safe.contains(':'), isFalse);

      final json = jsonFor(id: rawId, version: 1);
      final result = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: rawId,
        version: 1,
        jsonText: json,
      );
      expect(result.ok, isTrue);
      expect(result.versionPathHint, contains('Versions/$safe/'));
      expect(result.activePathHint, contains('WI_$safe.json'));
      // JSON 내부 id는 원본
      final active = await fs.readFile(['Ebook', 'Active'], 'WI_$safe.json');
      expect(jsonDecode(active.text!)['instructionId'], rawId);
    });

    test('11: step NotFound error includes stage and relative path', () async {
      final fs = StrictMemoryFs(); // no Ebook at all
      // create:false style: block create by overriding ensureDir
      final blocking = _NoCreateFs(fs);
      final pipeline = DevWorkDocSavePipeline(blocking);
      final result = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: jsonFor(id: iid, version: 1),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('실패 단계'));
      expect(result.message, contains('NotFoundError'));
      expect(result.message, contains('Ebook'));
    });

    test('12: download factory is not folder success', () {
      final d = DevWorkDocWriteResult.download(
        fileName: 'x.json',
        message: '다운로드만',
        activePathHint: 'Ebook/Active/x.json',
        versionPathHint: 'Ebook/Versions/x/x_v1.json',
      );
      expect(d.ok, isFalse);
      expect(d.mode, 'download');
      expect(d.isFolderCompleteSuccess, isFalse);
    });

    test('13: reread verifies Active and Versions content', () async {
      final fs = seededFs();
      final pipeline = DevWorkDocSavePipeline(fs);
      final json = jsonFor(id: iid, version: 1);
      final result = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: json,
      );
      expect(result.checksum, contentChecksum(json));
      expect(result.activeBytes, json.length);
      expect(result.versionsBytes, json.length);
    });

    test('4: exists probe NotFound is not fatal — creates new file', () async {
      final fs = seededFs();
      // 프로브만 하고 없는 파일
      expect(
        (await fs.readFile(['Ebook', 'Active'], 'WI_$iid.json')).text,
        isNull,
      );
      final pipeline = DevWorkDocSavePipeline(fs);
      final result = await pipeline.saveInstruction(
        artifactType: artifact,
        instructionId: iid,
        version: 1,
        jsonText: jsonFor(id: iid, version: 1),
      );
      expect(result.ok, isTrue);
    });
  });
}

class _OrderTrackingFs implements DevWorkDocFsAdapter {
  _OrderTrackingFs(this.inner, this.order);
  final DevWorkDocFsAdapter inner;
  final List<String> order;

  @override
  Future<bool> dirExists(List<String> segments) => inner.dirExists(segments);

  @override
  Future<void> ensureDir(List<String> segments, {required bool create}) {
    order.add('ensureDir:${segments.join('/')}:create=$create');
    return inner.ensureDir(segments, create: create);
  }

  @override
  Future<bool> fileExists(List<String> dirSegments, String fileName) =>
      inner.fileExists(dirSegments, fileName);

  @override
  Future<({String? text, int size})> readFile(
    List<String> dirSegments,
    String fileName,
  ) => inner.readFile(dirSegments, fileName);

  @override
  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  ) {
    order.add('write:${[...dirSegments, fileName].join('/')}');
    return inner.writeFile(dirSegments, fileName, content);
  }
}

class _NoCreateFs implements DevWorkDocFsAdapter {
  _NoCreateFs(this.inner);
  final MemoryDevWorkDocFs inner;

  @override
  Future<bool> dirExists(List<String> segments) => inner.dirExists(segments);

  @override
  Future<void> ensureDir(List<String> segments, {required bool create}) async {
    if (create) {
      throw FsNotFoundException(
        step: DevWorkDocSaveStep.artifactDir,
        relativePath: segments.join('/'),
        message: 'create blocked for test',
      );
    }
    await inner.ensureDir(segments, create: false);
  }

  @override
  Future<bool> fileExists(List<String> dirSegments, String fileName) =>
      inner.fileExists(dirSegments, fileName);

  @override
  Future<({String? text, int size})> readFile(
    List<String> dirSegments,
    String fileName,
  ) => inner.readFile(dirSegments, fileName);

  @override
  Future<void> writeFile(
    List<String> dirSegments,
    String fileName,
    String content,
  ) => inner.writeFile(dirSegments, fileName, content);
}
