/// 작업지시서 핵심 내용 checksum·비교 (canonical_v2 + 구형 호환).
library;

import 'dart:convert';

/// 새 파일에 기록하는 알고리즘 식별자.
const checksumAlgorithmCanonicalV2 = 'canonical_v2';
const checksumAlgorithmLegacyFullJson = 'legacy_full_json';

/// canonical payload에 포함하지 않는 휘발성·전달·UI 키.
const instructionVolatileKeys = <String>{
  'updatedAt',
  'createdAt',
  'checksum',
  'contentChecksum',
  'checksumAlgorithm',
  'sourceFileName',
  'status',
  'lastSavedAt',
  'exportedAt',
  'generatedAt',
  'pathHint',
  'activePathHint',
  'versionPathHint',
  'lastTransferAt',
  'lastTransferFileName',
  'lastTransferMode',
  'lastTransferChecksum',
  'folderPermission',
  'errorInfo',
  'retryAt',
  'executionUiState',
  'downloadState',
  'permissionState',
};

/// 핵심 콘텐츠 화이트리스트 (이 외 키는 canonical에서 무시).
const instructionCoreKeys = <String>{
  'schemaVersion',
  'instructionId',
  'instructionVersion',
  'projectId',
  'businessIdea',
  'businessPurpose',
  'customerProblem',
  'targetCustomer',
  'deliverableTypes',
  'recommendedSequence',
  'valueProposition',
  'requiredMaterials',
  'workflowSteps',
  'completionCriteria',
  'qualityChecks',
  'risks',
  'monetizationOptions',
  'deploymentTargets',
  'promotionChannels',
  'approvalItems',
  'executionStatus',
  'notes',
  'primaryTrack',
  'followUpTracks',
  'artifactType',
  'contentSubtype',
  'identity',
  'projectDefinition',
  'positioning',
  'scope',
  'productionSpec',
  'qualityCriteria',
  'aiGuards',
  'workflow',
  'approval',
  'validation',
  'aiExecution',
};

const _sortableStringListKeys = <String>{
  'deliverableTypes',
  'recommendedSequence',
  'requiredMaterials',
  'completionCriteria',
  'qualityChecks',
  'risks',
  'monetizationOptions',
  'deploymentTargets',
  'promotionChannels',
  'approvalItems',
  'followUpTracks',
};

enum InstructionContentRelation { sameCore, differentCore, incomparable }

class InstructionContentDiff {
  const InstructionContentDiff({
    required this.relation,
    required this.stableChecksumA,
    required this.stableChecksumB,
    required this.entries,
    this.metadataOnlyDifferences = const [],
    this.storedChecksumA = '',
    this.storedChecksumB = '',
    this.legacyCompatible = false,
    this.schemaNormalized = false,
    this.coreDiffFieldCount = 0,
  });

  final InstructionContentRelation relation;
  final String stableChecksumA;
  final String stableChecksumB;
  final List<InstructionDiffEntry> entries;
  final List<String> metadataOnlyDifferences;
  final String storedChecksumA;
  final String storedChecksumB;
  final bool legacyCompatible;
  final bool schemaNormalized;
  final int coreDiffFieldCount;

  bool get isMetadataOnly =>
      relation == InstructionContentRelation.sameCore &&
      metadataOnlyDifferences.isNotEmpty;

  bool get isSameCore => relation == InstructionContentRelation.sameCore;
}

class InstructionDiffEntry {
  const InstructionDiffEntry({
    required this.label,
    required this.left,
    required this.right,
    this.isMetadata = false,
  });

  final String label;
  final String left;
  final String right;
  final bool isMetadata;
}

/// 바이트/문자열 그대로의 FNV 해시 (구형 legacy_full_json).
String contentChecksumRaw(String content) {
  var hash = 2166136261;
  for (final unit in content.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// 스키마 호환 정규화 후 핵심 payload.
Map<String, dynamic> normalizeInstructionMap(Map<String, dynamic> source) {
  final raw = Map<String, dynamic>.from(source);

  // version ↔ instructionVersion
  final ver = '${raw['instructionVersion'] ?? raw['version'] ?? ''}'.trim();
  if (ver.isNotEmpty) {
    raw['instructionVersion'] = ver;
  }
  raw.remove('version');

  // followUpTracks / followupTracks 통합
  final follow =
      (raw['followUpTracks'] as List?)?.map((e) => '$e').toList() ??
      (raw['followupTracks'] as List?)?.map((e) => '$e').toList() ??
      const <String>[];
  raw['followUpTracks'] = follow;
  raw.remove('followupTracks');

  // 빈 문자열·null 선택 필드 정규화
  for (final key in ['contentSubtype', 'notes', 'sourceFileName', 'status']) {
    if (raw[key] == null || '${raw[key]}'.trim().isEmpty) {
      raw[key] = '';
    }
  }

  // workflowSteps: 의미 필드만 + order 기준 정렬
  final steps = raw['workflowSteps'];
  if (steps is List) {
    final normalized = <Map<String, dynamic>>[];
    for (final s in steps) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      normalized.add({
        'order': (m['order'] as num?)?.toInt() ?? 0,
        'id': '${m['id'] ?? ''}',
        'title': '${m['title'] ?? ''}',
        'applicable': m['applicable'] != false,
        'completionCriteria': '${m['completionCriteria'] ?? ''}',
        'notes': '${m['notes'] ?? ''}',
      });
    }
    normalized.sort((a, b) {
      final oa = a['order'] as int;
      final ob = b['order'] as int;
      if (oa != ob) return oa.compareTo(ob);
      return '${a['id']}'.compareTo('${b['id']}');
    });
    raw['workflowSteps'] = normalized;
  }

  // 문자열 리스트 정규화
  for (final key in _sortableStringListKeys) {
    final v = raw[key];
    if (v is List) {
      raw[key] = v.map((e) => '$e').toList();
    }
  }

  return raw;
}

/// 화이트리스트 + 정규화 + 키 정렬 canonical map.
Map<String, dynamic> canonicalContentMap(Map<String, dynamic> source) {
  final normalized = normalizeInstructionMap(source);
  final core = <String, dynamic>{};
  for (final key in instructionCoreKeys) {
    if (!normalized.containsKey(key)) continue;
    final v = normalized[key];
    if (v == null) continue;
    if (v is String && v.isEmpty && key != 'notes' && key != 'contentSubtype') {
      // 필수 문자열은 유지, 완전 빈 optional은 notes/contentSubtype만 허용
    }
    core[key] = v;
  }
  // notes / contentSubtype 빈 값도 동일성 위해 포함
  core.putIfAbsent('notes', () => '');
  core.putIfAbsent('contentSubtype', () => '');
  return _canonicalize(core) as Map<String, dynamic>;
}

String stableContentChecksum(Object jsonOrText) {
  final map = _asMap(jsonOrText);
  if (map == null) {
    final raw = jsonOrText is String ? jsonOrText : jsonEncode(jsonOrText);
    return contentChecksumRaw(raw);
  }
  final encoded = const JsonEncoder().convert(canonicalContentMap(map));
  return contentChecksumRaw(encoded);
}

/// DevWorkDoc·저장 검증용 — canonical_v2 안정 checksum.
String contentChecksum(String content) => stableContentChecksum(content);

/// 파일에 저장된 checksum 문자열 (호환용, 비교 기준 아님).
String storedChecksumOf(Object jsonOrText) {
  final map = _asMap(jsonOrText);
  if (map == null) return '';
  final c = '${map['contentChecksum'] ?? map['checksum'] ?? ''}'.trim();
  return c;
}

String storedAlgorithmOf(Object jsonOrText) {
  final map = _asMap(jsonOrText);
  if (map == null) return '';
  final a = '${map['checksumAlgorithm'] ?? ''}'.trim();
  if (a.isNotEmpty) return a;
  // 구형: 알고리즘 필드 없음
  if (storedChecksumOf(map).isNotEmpty) return checksumAlgorithmLegacyFullJson;
  return '';
}

/// 새 저장용: canonical checksum 필드를 JSON 맵에 주입.
Map<String, dynamic> withCanonicalChecksumFields(Map<String, dynamic> source) {
  final map = Map<String, dynamic>.from(source);
  final sum = stableContentChecksum(map);
  map['checksumAlgorithm'] = checksumAlgorithmCanonicalV2;
  map['contentChecksum'] = sum;
  map['checksum'] = sum; // 하위 호환
  return map;
}

InstructionContentRelation compareInstructionContent(Object a, Object b) {
  return diffInstructionContent(a, b).relation;
}

InstructionContentDiff diffInstructionContent(Object a, Object b) {
  final mapA = _asMap(a) ?? <String, dynamic>{};
  final mapB = _asMap(b) ?? <String, dynamic>{};
  final sumA = mapA.isEmpty
      ? stableContentChecksum(a)
      : stableContentChecksum(mapA);
  final sumB = mapB.isEmpty
      ? stableContentChecksum(b)
      : stableContentChecksum(mapB);
  final storedA = storedChecksumOf(mapA);
  final storedB = storedChecksumOf(mapB);
  final algoA = storedAlgorithmOf(mapA);
  final algoB = storedAlgorithmOf(mapB);

  final coreDiffKeys = <String>[];
  if (mapA.isNotEmpty && mapB.isNotEmpty) {
    final ca = canonicalContentMap(mapA);
    final cb = canonicalContentMap(mapB);
    final keys = {...ca.keys, ...cb.keys};
    for (final k in keys) {
      final ea = const JsonEncoder().convert(ca[k]);
      final eb = const JsonEncoder().convert(cb[k]);
      if (ea != eb) coreDiffKeys.add(k);
    }
  }

  // 핵심 canonical 필드 차이가 0이면 반드시 동일 (저장된 checksum 문자열 무시)
  final relation = mapA.isEmpty || mapB.isEmpty
      ? InstructionContentRelation.incomparable
      : (coreDiffKeys.isEmpty
            ? InstructionContentRelation.sameCore
            : InstructionContentRelation.differentCore);

  final normA = mapA.isEmpty
      ? <String, dynamic>{}
      : normalizeInstructionMap(mapA);
  final normB = mapB.isEmpty
      ? <String, dynamic>{}
      : normalizeInstructionMap(mapB);

  final labelFor = <String, String>{
    'businessIdea': '제목·주제',
    'targetCustomer': '대상 사용자',
    'customerProblem': '해결할 문제',
    'businessPurpose': '목표 결과',
    'artifactType': '제작 형태',
    'primaryTrack': '주 트랙',
    'deliverableTypes': '주요 결과물',
    'workflowSteps': '단계별 작업지시',
    'instructionVersion': '버전',
    'valueProposition': '가치제안',
    'risks': '리스크',
    'notes': '메모',
  };

  final differingCore = <InstructionDiffEntry>[];
  for (final k in coreDiffKeys) {
    differingCore.add(
      InstructionDiffEntry(
        label: labelFor[k] ?? k,
        left: k == 'workflowSteps'
            ? _workflowSummary(normA[k])
            : _display(normA[k]),
        right: k == 'workflowSteps'
            ? _workflowSummary(normB[k])
            : _display(normB[k]),
      ),
    );
  }

  final meta = <String>[];
  for (final key in instructionVolatileKeys) {
    final la = '${mapA[key] ?? ''}';
    final lb = '${mapB[key] ?? ''}';
    if (la != lb) meta.add(key);
  }
  if (storedA != storedB && (storedA.isNotEmpty || storedB.isNotEmpty)) {
    meta.add('storedChecksum');
  }
  if (algoA != algoB && (algoA.isNotEmpty || algoB.isNotEmpty)) {
    meta.add('checksumAlgorithm');
  }

  final legacyCompatible =
      relation == InstructionContentRelation.sameCore &&
      (algoA == checksumAlgorithmLegacyFullJson ||
          algoB == checksumAlgorithmLegacyFullJson ||
          algoA.isEmpty ||
          algoB.isEmpty ||
          (storedA.isNotEmpty && storedA != sumA) ||
          (storedB.isNotEmpty && storedB != sumB));

  final schemaNormalized =
      mapA.containsKey('version') ||
      mapB.containsKey('version') ||
      mapA.containsKey('followupTracks') ||
      mapB.containsKey('followupTracks');

  return InstructionContentDiff(
    relation: relation,
    stableChecksumA: sumA,
    stableChecksumB: sumB,
    entries: [
      ...differingCore,
      InstructionDiffEntry(
        label: '구형 저장 checksum(기존)',
        left: storedA.isEmpty ? '(없음)' : storedA,
        right: sumA,
        isMetadata: true,
      ),
      InstructionDiffEntry(
        label: '구형 저장 checksum(현재)',
        left: storedB.isEmpty ? '(없음)' : storedB,
        right: sumB,
        isMetadata: true,
      ),
      InstructionDiffEntry(label: '재계산 안정 checksum', left: sumA, right: sumB),
    ],
    metadataOnlyDifferences: meta,
    storedChecksumA: storedA,
    storedChecksumB: storedB,
    legacyCompatible: legacyCompatible,
    schemaNormalized: schemaNormalized,
    coreDiffFieldCount: coreDiffKeys.length,
  );
}

/// 충돌 진단용 짧은 요약 (개인정보·전체 JSON 금지).
String formatConflictDiagnosis(InstructionContentDiff diff) {
  final buf = StringBuffer()
    ..writeln(
      '구형 저장 checksum: ${diff.storedChecksumA.isEmpty ? '(없음)' : diff.storedChecksumA}',
    )
    ..writeln('기존 JSON 재계산 안정 checksum: ${diff.stableChecksumA}')
    ..writeln('현재 스냅샷 안정 checksum: ${diff.stableChecksumB}')
    ..writeln('핵심 내용 차이 필드 수: ${diff.coreDiffFieldCount}')
    ..writeln('메타데이터만 다른지: ${diff.isSameCore ? '예 (또는 동일)' : '아니오'}')
    ..writeln('스키마 호환 변환: ${diff.schemaNormalized ? '적용' : '해당 없음'}')
    ..writeln('구형 체크섬 호환: ${diff.legacyCompatible ? '예' : '아니오'}');
  if (diff.coreDiffFieldCount > 0) {
    buf.writeln('차이 필드:');
    for (final e in diff.entries) {
      if (e.isMetadata ||
          e.label.startsWith('재계산') ||
          e.label.startsWith('구형')) {
        continue;
      }
      if (e.left != e.right) {
        buf.writeln('- ${e.label}');
      }
    }
  }
  return buf.toString().trim();
}

String _workflowSummary(Object? steps) {
  if (steps is! List) return '';
  final parts = <String>[];
  for (final s in steps.take(5)) {
    if (s is Map) {
      parts.add('${s['title'] ?? s['id'] ?? s}');
    } else {
      parts.add('$s');
    }
  }
  if (steps.length > 5) parts.add('…+${steps.length - 5}');
  return parts.join(' → ');
}

String _display(Object? v) {
  if (v == null) return '(없음)';
  if (v is List) return v.map(_display).join(', ');
  if (v is Map) return const JsonEncoder().convert(v);
  final s = '$v'.trim();
  return s.isEmpty ? '(빈 값)' : s;
}

Map<String, dynamic>? _asMap(Object jsonOrText) {
  if (jsonOrText is Map<String, dynamic>) return jsonOrText;
  if (jsonOrText is Map) return Map<String, dynamic>.from(jsonOrText);
  if (jsonOrText is String) {
    if (jsonOrText.trim().isEmpty) return null;
    try {
      final d = jsonDecode(jsonOrText);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {
      return null;
    }
  }
  return null;
}

dynamic _canonicalize(dynamic value, [String? parentKey]) {
  if (value is Map) {
    final keys = value.keys.map((k) => '$k').toList()..sort();
    final out = <String, dynamic>{};
    for (final k in keys) {
      out[k] = _canonicalize(value[k], k);
    }
    return out;
  }
  if (value is List) {
    final mapped = value.map((e) => _canonicalize(e)).toList();
    if (parentKey != null && _sortableStringListKeys.contains(parentKey)) {
      final asStrings = mapped.every(
        (e) => e is String || e is num || e is bool,
      );
      if (asStrings) {
        mapped.sort((a, b) => '$a'.compareTo('$b'));
      }
    }
    return mapped;
  }
  return value;
}
