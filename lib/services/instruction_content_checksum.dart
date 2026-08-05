/// 작업지시서 핵심 내용 checksum·비교 (휘발성 메타데이터 제외).
library;

import 'dart:convert';

/// checksum / 충돌 비교에서 제외하는 휘발성 키.
const instructionVolatileKeys = <String>{
  'updatedAt',
  'createdAt',
  'checksum',
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
  'folderPermission',
  'errorInfo',
  'retryAt',
};

/// 목록 순서가 의미에 영향 없는 필드 — 정렬하여 안정화.
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
  'followupTracks',
};

enum InstructionContentRelation {
  /// 핵심 내용 동일 (메타데이터만 다를 수 있음).
  sameCore,

  /// 핵심 내용이 실제로 다름.
  differentCore,

  /// 비교 불가 (파싱 실패 등).
  incomparable,
}

class InstructionContentDiff {
  const InstructionContentDiff({
    required this.relation,
    required this.stableChecksumA,
    required this.stableChecksumB,
    required this.entries,
    this.metadataOnlyDifferences = const [],
  });

  final InstructionContentRelation relation;
  final String stableChecksumA;
  final String stableChecksumB;
  final List<InstructionDiffEntry> entries;
  final List<String> metadataOnlyDifferences;

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

/// 바이트/문자열 그대로의 FNV 해시 (정규화 없음).
String contentChecksumRaw(String content) {
  var hash = 2166136261;
  for (final unit in content.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// JSON 문자열 또는 맵에서 핵심 내용만 뽑아 정규화한 뒤 해시.
String stableContentChecksum(Object jsonOrText) {
  final map = _asMap(jsonOrText);
  if (map == null) {
    final raw = jsonOrText is String ? jsonOrText : jsonEncode(jsonOrText);
    return contentChecksumRaw(raw);
  }
  final canonical = canonicalContentMap(map);
  final encoded = const JsonEncoder().convert(canonical);
  return contentChecksumRaw(encoded);
}

/// DevWorkDoc·저장 검증용 — 안정적인 핵심 내용 checksum.
String contentChecksum(String content) => stableContentChecksum(content);

Map<String, dynamic> canonicalContentMap(Map<String, dynamic> source) {
  final stripped = _stripVolatile(source);
  return _canonicalize(stripped) as Map<String, dynamic>;
}

InstructionContentRelation compareInstructionContent(Object a, Object b) {
  final mapA = _asMap(a);
  final mapB = _asMap(b);
  if (mapA == null || mapB == null) {
    return InstructionContentRelation.incomparable;
  }
  if (stableContentChecksum(mapA) == stableContentChecksum(mapB)) {
    return InstructionContentRelation.sameCore;
  }
  return InstructionContentRelation.differentCore;
}

InstructionContentDiff diffInstructionContent(Object a, Object b) {
  final mapA = _asMap(a) ?? <String, dynamic>{};
  final mapB = _asMap(b) ?? <String, dynamic>{};
  final sumA = stableContentChecksum(mapA.isEmpty ? a : mapA);
  final sumB = stableContentChecksum(mapB.isEmpty ? b : mapB);
  final relation = sumA == sumB
      ? InstructionContentRelation.sameCore
      : (mapA.isEmpty || mapB.isEmpty
            ? InstructionContentRelation.incomparable
            : InstructionContentRelation.differentCore);

  final entries = <InstructionDiffEntry>[
    _fieldDiff('제목·주제', mapA['businessIdea'], mapB['businessIdea']),
    _fieldDiff('대상 사용자', mapA['targetCustomer'], mapB['targetCustomer']),
    _fieldDiff('해결할 문제', mapA['customerProblem'], mapB['customerProblem']),
    _fieldDiff('목표 결과', mapA['businessPurpose'], mapB['businessPurpose']),
    _fieldDiff('제작 형태', mapA['artifactType'], mapB['artifactType']),
    _fieldDiff('주 트랙', mapA['primaryTrack'], mapB['primaryTrack']),
    _fieldDiff('주요 결과물', mapA['deliverableTypes'], mapB['deliverableTypes']),
    _fieldDiff(
      '단계별 작업지시',
      _workflowSummary(mapA['workflowSteps']),
      _workflowSummary(mapB['workflowSteps']),
    ),
    InstructionDiffEntry(label: '핵심 checksum', left: sumA, right: sumB),
  ].where((e) => e.left != e.right || e.label == '핵심 checksum').toList();

  final meta = <String>[];
  for (final key in instructionVolatileKeys) {
    final la = '${mapA[key] ?? ''}';
    final lb = '${mapB[key] ?? ''}';
    if (la != lb) {
      meta.add('$key: 「${_short(la)}」 ↔ 「${_short(lb)}」');
    }
  }

  return InstructionContentDiff(
    relation: relation,
    stableChecksumA: sumA,
    stableChecksumB: sumB,
    entries: entries,
    metadataOnlyDifferences: meta,
  );
}

InstructionDiffEntry _fieldDiff(String label, Object? left, Object? right) {
  return InstructionDiffEntry(
    label: label,
    left: _display(left),
    right: _display(right),
  );
}

String _workflowSummary(Object? steps) {
  if (steps is! List) return '';
  final parts = <String>[];
  for (final s in steps.take(5)) {
    if (s is Map) {
      parts.add('${s['title'] ?? s['name'] ?? s['id'] ?? s}');
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

String _short(String s) {
  if (s.length <= 40) return s.isEmpty ? '(없음)' : s;
  return '${s.substring(0, 37)}…';
}

Map<String, dynamic>? _asMap(Object jsonOrText) {
  if (jsonOrText is Map<String, dynamic>) return jsonOrText;
  if (jsonOrText is Map) {
    return Map<String, dynamic>.from(jsonOrText);
  }
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

dynamic _stripVolatile(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    for (final e in value.entries) {
      final key = '${e.key}';
      if (instructionVolatileKeys.contains(key)) continue;
      out[key] = _stripVolatile(e.value);
    }
    return out;
  }
  if (value is List) {
    return value.map(_stripVolatile).toList();
  }
  return value;
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
