import '../data/known_projects_catalog.dart';
import '../models/ops_models.dart';
import 'ops_repository.dart';

class KnownProjectSeedResult {
  const KnownProjectSeedResult({
    required this.created,
    required this.skipped,
    required this.failed,
  });

  final List<String> created;
  final List<String> skipped;
  final List<String> failed;

  String get message =>
      '생성 ${created.length}건 · 중복 생략 ${skipped.length}건 · 실패 ${failed.length}건';
}

class KnownProjectsSeedService {
  KnownProjectsSeedService(this._repo);

  final OpsRepository _repo;

  List<KnownProjectSpec> previewAll() => KnownProjectsCatalog.all;

  Future<KnownProjectSeedResult> createSelected(List<String> ids) async {
    final created = <String>[];
    final skipped = <String>[];
    final failed = <String>[];

    for (final spec in KnownProjectsCatalog.all.where(
      (e) => ids.contains(e.id),
    )) {
      try {
        if (await _repo.projectExists(spec.id)) {
          skipped.add(spec.name);
          continue;
        }
        await _repo.upsertProject(spec.toProjectDoc(), isNew: true);
        created.add(spec.name);
      } catch (_) {
        failed.add(spec.name);
      }
    }
    return KnownProjectSeedResult(
      created: created,
      skipped: skipped,
      failed: failed,
    );
  }
}

/// 작업 로그 유틸 (순수 로직 — 테스트 가능)
class WorkLogUtils {
  static String normalizeCommitHash(String? hash) =>
      (hash ?? '').trim().toLowerCase();

  static bool isDuplicateCommit({
    required String? newHash,
    required Iterable<String> existingHashes,
    String? excludeId,
  }) {
    final n = normalizeCommitHash(newHash);
    if (n.isEmpty) return false;
    return existingHashes.map(normalizeCommitHash).contains(n);
  }

  static List<WorkLogDoc> filterLogs({
    required List<WorkLogDoc> logs,
    String? projectId,
    String? businessUnitId,
    DateTime? from,
    DateTime? to,
  }) {
    return logs.where((l) {
      if (projectId != null &&
          projectId.isNotEmpty &&
          l.projectId != projectId) {
        return false;
      }
      if (businessUnitId != null &&
          businessUnitId.isNotEmpty &&
          l.businessUnitId != businessUnitId) {
        return false;
      }
      if (from != null && l.workedAt != null && l.workedAt!.isBefore(from)) {
        return false;
      }
      if (to != null && l.workedAt != null && l.workedAt!.isAfter(to)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aa = a.workedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.workedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });
  }

  static List<String> validateImportItem(Map<String, dynamic> m) {
    final errors = <String>[];
    if ('${m['title'] ?? ''}'.trim().isEmpty) {
      errors.add('title 필수');
    }
    return errors;
  }
}
