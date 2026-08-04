import 'package:intl/intl.dart';

/// Windows 안전 파일명 생성.
class WorkInstructionFilename {
  static final _unsafe = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final _spaces = RegExp(r'\s+');

  static String sanitizeSegment(String raw, {int maxLen = 40}) {
    var s = raw.replaceAll(_unsafe, '').replaceAll(_spaces, '');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.isEmpty) s = 'untitled';
    if (s.length > maxLen) s = s.substring(0, maxLen);
    return s;
  }

  /// 예: WI_20260804_001_시골월수익300만원_ebook_v1.json
  static String build({
    required DateTime now,
    required int sequence,
    required String topic,
    required String deliverableType,
    required int version,
  }) {
    final date = DateFormat('yyyyMMdd').format(now.toLocal());
    final seq = sequence.clamp(1, 999).toString().padLeft(3, '0');
    final slug = sanitizeSegment(topic, maxLen: 36);
    final type = sanitizeSegment(deliverableType, maxLen: 24);
    return 'WI_${date}_${seq}_${slug}_${type}_v$version.json';
  }
}
