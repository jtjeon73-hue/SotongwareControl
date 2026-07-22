import '../data/deployed_sites_catalog.dart';
import '../models/deployed_site.dart';
import 'deployed_sites_repository.dart';

enum DeployedSitesSort { recentDeploy, name, needsCheckFirst }

class DeployedSitesFilter {
  const DeployedSitesFilter({
    this.query = '',
    this.category,
    this.status,
    this.hostingType,
    this.favoritesOnly = false,
    this.sort = DeployedSitesSort.recentDeploy,
  });

  final String query;
  final String? category;
  final String? status;
  final String? hostingType;
  final bool favoritesOnly;
  final DeployedSitesSort sort;

  DeployedSitesFilter copyWith({
    String? query,
    String? category,
    bool clearCategory = false,
    String? status,
    bool clearStatus = false,
    String? hostingType,
    bool clearHostingType = false,
    bool? favoritesOnly,
    DeployedSitesSort? sort,
  }) {
    return DeployedSitesFilter(
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
      status: clearStatus ? null : (status ?? this.status),
      hostingType: clearHostingType ? null : (hostingType ?? this.hostingType),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sort: sort ?? this.sort,
    );
  }
}

class DeployedSitesService {
  DeployedSitesService(this._repo);

  final DeployedSitesRepository _repo;

  static DeployedSitesKpis computeKpis(List<DeployedSiteDoc> sites) {
    final active = sites.where((s) => s.isActive).toList();
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return DeployedSitesKpis(
      total: sites.length,
      operating: active
          .where((s) => s.effectiveStatus == DeployedSiteStatus.operating)
          .length,
      needsCheck: active
          .where((s) => s.effectiveStatus == DeployedSiteStatus.needsCheck)
          .length,
      preparingOrDeploying: active
          .where(
            (s) =>
                s.effectiveStatus == DeployedSiteStatus.preparing ||
                s.effectiveStatus == DeployedSiteStatus.deploying,
          )
          .length,
      inactive: sites
          .where(
            (s) =>
                !s.isActive || s.effectiveStatus == DeployedSiteStatus.inactive,
          )
          .length,
      recentlyDeployed: sites
          .where(
            (s) =>
                s.lastDeployedAt != null && s.lastDeployedAt!.isAfter(weekAgo),
          )
          .length,
    );
  }

  static List<DeployedSiteDoc> applyFilter(
    List<DeployedSiteDoc> sites,
    DeployedSitesFilter filter,
  ) {
    final q = filter.query.trim().toLowerCase();
    var list = sites.where((s) {
      if (filter.favoritesOnly && !s.isFavorite) return false;
      if (filter.category != null && s.category != filter.category) {
        return false;
      }
      if (filter.status != null && s.effectiveStatus != filter.status) {
        return false;
      }
      if (filter.hostingType != null && s.hostingType != filter.hostingType) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.nameKo.toLowerCase().contains(q) ||
          s.nameEn.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.serviceScope.toLowerCase().contains(q) ||
          s.operationPurpose.toLowerCase().contains(q) ||
          s.liveUrl.toLowerCase().contains(q) ||
          s.firebaseProjectId.toLowerCase().contains(q) ||
          s.githubUrl.toLowerCase().contains(q) ||
          s.strategyUrl.toLowerCase().contains(q);
    }).toList();

    switch (filter.sort) {
      case DeployedSitesSort.recentDeploy:
        list.sort((a, b) {
          final ad = a.lastDeployedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.lastDeployedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cmp = bd.compareTo(ad);
          if (cmp != 0) return cmp;
          return a.sortOrder.compareTo(b.sortOrder);
        });
      case DeployedSitesSort.name:
        list.sort((a, b) => a.nameKo.compareTo(b.nameKo));
      case DeployedSitesSort.needsCheckFirst:
        list.sort((a, b) {
          final aw = a.effectiveStatus == DeployedSiteStatus.needsCheck ? 0 : 1;
          final bw = b.effectiveStatus == DeployedSiteStatus.needsCheck ? 0 : 1;
          final cmp = aw.compareTo(bw);
          if (cmp != 0) return cmp;
          return a.sortOrder.compareTo(b.sortOrder);
        });
    }
    return list;
  }

  static bool isDuplicate(
    List<DeployedSiteDoc> existing, {
    required String liveUrl,
    required String firebaseProjectId,
    String githubUrl = '',
    String nameEn = '',
    String? excludeId,
  }) {
    return findMatch(
          existing,
          liveUrl: liveUrl,
          firebaseProjectId: firebaseProjectId,
          githubUrl: githubUrl,
          nameEn: nameEn,
          excludeId: excludeId,
        ) !=
        null;
  }

  static DeployedSiteDoc? findMatch(
    List<DeployedSiteDoc> existing, {
    String id = '',
    required String liveUrl,
    required String firebaseProjectId,
    String githubUrl = '',
    String nameEn = '',
    String? excludeId,
  }) {
    final url = liveUrl.trim().toLowerCase();
    final projectId = firebaseProjectId.trim().toLowerCase();
    final github = githubUrl.trim().toLowerCase().replaceAll(RegExp(r'/$'), '');
    final en = nameEn.trim().toLowerCase();
    for (final site in existing) {
      if (excludeId != null && site.id == excludeId) continue;
      if (id.isNotEmpty && site.id == id) return site;
      if (url.isNotEmpty && site.liveUrl.trim().toLowerCase() == url) {
        return site;
      }
      if (projectId.isNotEmpty &&
          site.firebaseProjectId.trim().toLowerCase() == projectId) {
        return site;
      }
      final siteGithub = site.githubUrl.trim().toLowerCase().replaceAll(
        RegExp(r'/$'),
        '',
      );
      if (github.isNotEmpty && siteGithub == github) return site;
      if (en.isNotEmpty && site.nameEn.trim().toLowerCase() == en) return site;
    }
    return null;
  }

  /// 카탈로그 시드를 기존 문서에 맞춰 생성하거나 핵심 배포정보를 갱신한다.
  /// 기존에 더 상세한 설명·범위·목적이 있으면 짧은 시드 기본값으로 덮어쓰지 않는다.
  /// operating 상태를 needsCheck 시드로 되돌리지 않는다.
  static DeployedSiteDoc mergeSeed(
    DeployedSiteDoc seed,
    DeployedSiteDoc? existing,
  ) {
    if (existing == null) {
      final created = seed.copyWith(
        lastDeployedAt: DateTime.now(),
        lastCheckedAt: DateTime.now(),
      );
      return created.copyWith(status: DeployedSiteStatus.evaluate(created));
    }

    final mergedIssues = _mergeIssues(
      existing.issues,
      seed.issues,
      seed.status,
    );
    final merged = DeployedSiteDoc(
      id: existing.id,
      nameKo: seed.nameKo.isNotEmpty ? seed.nameKo : existing.nameKo,
      nameEn: seed.nameEn.isNotEmpty ? seed.nameEn : existing.nameEn,
      description: preferRicher(existing.description, seed.description),
      serviceScope: preferRicher(existing.serviceScope, seed.serviceScope),
      operationPurpose: preferRicher(
        existing.operationPurpose,
        seed.operationPurpose,
      ),
      category: seed.category.isNotEmpty ? seed.category : existing.category,
      hostingType: seed.hostingType.isNotEmpty
          ? seed.hostingType
          : existing.hostingType,
      firebaseProjectId: seed.firebaseProjectId.isNotEmpty
          ? seed.firebaseProjectId
          : existing.firebaseProjectId,
      liveUrl: seed.liveUrl.isNotEmpty ? seed.liveUrl : existing.liveUrl,
      githubUrl: seed.githubUrl.isNotEmpty
          ? seed.githubUrl
          : existing.githubUrl,
      strategyUrl: seed.strategyUrl.isNotEmpty
          ? seed.strategyUrl
          : existing.strategyUrl,
      status: mergeStatus(existing.status, seed.status),
      isFavorite: existing.isFavorite,
      iconName: seed.iconName.isNotEmpty ? seed.iconName : existing.iconName,
      lastDeployedAt: existing.lastDeployedAt ?? DateTime.now(),
      lastCheckedAt: DateTime.now(),
      mobileChecked: existing.mobileChecked || seed.mobileChecked,
      desktopChecked: existing.desktopChecked || seed.desktopChecked,
      httpsChecked: existing.httpsChecked || seed.httpsChecked,
      lastDeployResult: seed.lastDeployResult.isNotEmpty
          ? seed.lastDeployResult
          : existing.lastDeployResult,
      recentWork: preferRicher(existing.recentWork, seed.recentWork),
      issues: mergedIssues,
      nextAction: preferRicher(existing.nextAction, seed.nextAction),
      adminMemo: existing.adminMemo.isNotEmpty
          ? existing.adminMemo
          : seed.adminMemo,
      sortOrder: seed.sortOrder,
      isActive: existing.status == DeployedSiteStatus.inactive
          ? false
          : seed.isActive,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    );
    return merged.copyWith(status: DeployedSiteStatus.evaluate(merged));
  }

  static String preferRicher(String existing, String seed) {
    final e = existing.trim();
    final s = seed.trim();
    if (e.isEmpty) return s;
    if (s.isEmpty) return e;
    // 시드가 더 상세하면 카탈로그 갱신을 반영한다.
    if (s.length > e.length) return s;
    return e;
  }

  static String mergeStatus(String existing, String seed) {
    if (existing == DeployedSiteStatus.inactive) {
      return DeployedSiteStatus.inactive;
    }
    // 수동/기존 정상 운영을 시드의 needsCheck로 되돌리지 않음
    if (existing == DeployedSiteStatus.operating &&
        seed == DeployedSiteStatus.needsCheck) {
      return DeployedSiteStatus.operating;
    }
    if (seed == DeployedSiteStatus.operating) {
      return DeployedSiteStatus.operating;
    }
    return existing.isNotEmpty ? existing : seed;
  }

  static String _mergeIssues(String existing, String seed, String seedStatus) {
    if (seedStatus == DeployedSiteStatus.operating && seed.trim().isEmpty) {
      // 시드가 정상 운영·이슈 없음이면 과거 점검 문구를 비운다.
      if (!DeployedSiteStatus.hasSeriousIssues(existing)) return '';
    }
    return preferRicher(existing, seed);
  }

  Future<String> seedVerifiedSitesIfNeeded({
    bool forcePreviewOnly = false,
  }) async {
    final existing = await _repo.fetchSitesOnce();
    if (forcePreviewOnly) {
      return '미리보기 전용: 확인된 후보 ${DeployedSitesCatalog.verifiedSeeds.length}건';
    }
    if (existing.isNotEmpty || await _repo.isCatalogSeeded()) {
      return '이미 등록된 배포사이트가 있어 초기 시드를 건너뛰었습니다. '
          '누락분·갱신은 확인 사이트 불러오기를 사용하십시오.';
    }

    final result = await syncVerifiedCatalog(existing: existing);
    await _repo.markCatalogSeeded(count: result.created + result.updated);
    return '확인된 배포사이트 ${result.created}건을 등록했습니다.';
  }

  Future<String> importMissingVerifiedSites() async {
    final existing = await _repo.fetchSitesOnce();
    final result = await syncVerifiedCatalog(existing: existing);
    if (!await _repo.isCatalogSeeded()) {
      await _repo.markCatalogSeeded(count: result.created + result.updated);
    }
    if (result.created == 0 && result.updated == 0 && result.deactivated == 0) {
      return '추가하거나 갱신할 확인 사이트가 없습니다.';
    }
    final parts = <String>[
      if (result.created > 0) '신규 ${result.created}건 등록',
      if (result.updated > 0) '기존 ${result.updated}건 배포정보 갱신',
      if (result.deactivated > 0) '중복 ${result.deactivated}건 비활성',
    ];
    return parts.join(', ');
  }

  Future<({int created, int updated, int deactivated})> syncVerifiedCatalog({
    List<DeployedSiteDoc>? existing,
  }) async {
    final current = [...(existing ?? await _repo.fetchSitesOnce())];
    var created = 0;
    var updated = 0;
    for (final seed in DeployedSitesCatalog.verifiedSeeds) {
      final match = findMatch(
        current,
        id: seed.id,
        liveUrl: seed.liveUrl,
        firebaseProjectId: seed.firebaseProjectId,
        githubUrl: seed.githubUrl,
        nameEn: seed.nameEn,
      );
      final merged = mergeSeed(seed, match);
      final isNew = match == null;
      await _repo.upsertSite(merged, isNew: isNew);
      if (isNew) {
        created++;
        current.add(merged);
      } else {
        updated++;
        final index = current.indexWhere((e) => e.id == match.id);
        if (index >= 0) current[index] = merged;
      }
    }

    final deactivated = await deactivateDuplicateSites(current);
    return (created: created, updated: updated, deactivated: deactivated);
  }

  /// 동일 Project ID·URL·GitHub·영문명 중복 문서는 최신(또는 카탈로그 id)만 남기고 비활성.
  static List<DeployedSiteDoc> pickDuplicateLosers(
    List<DeployedSiteDoc> sites,
  ) {
    final losers = <DeployedSiteDoc>[];
    final seen = <String, DeployedSiteDoc>{};

    String? keyOf(DeployedSiteDoc s) {
      final project = s.firebaseProjectId.trim().toLowerCase();
      if (project.isNotEmpty) return 'p:$project';
      final url = s.liveUrl.trim().toLowerCase();
      if (url.isNotEmpty) return 'u:$url';
      final github = s.githubUrl.trim().toLowerCase().replaceAll(
        RegExp(r'/$'),
        '',
      );
      if (github.isNotEmpty) return 'g:$github';
      final en = s.nameEn.trim().toLowerCase();
      if (en.isNotEmpty) return 'e:$en';
      return null;
    }

    int score(DeployedSiteDoc s) {
      var v = 0;
      if (DeployedSitesCatalog.verifiedSeeds.any((seed) => seed.id == s.id)) {
        v += 1000;
      }
      if (s.isActive) v += 100;
      if (s.serviceScope.isNotEmpty) v += 20;
      if (s.operationPurpose.isNotEmpty) v += 20;
      if (s.description.isNotEmpty) v += 10;
      if (s.updatedAt != null) {
        v += s.updatedAt!.millisecondsSinceEpoch ~/ 1000000;
      }
      return v;
    }

    for (final site in sites) {
      final key = keyOf(site);
      if (key == null) continue;
      final prev = seen[key];
      if (prev == null) {
        seen[key] = site;
        continue;
      }
      if (score(site) > score(prev)) {
        losers.add(prev);
        seen[key] = site;
      } else {
        losers.add(site);
      }
    }
    return losers.where((s) => s.isActive).toList();
  }

  Future<int> deactivateDuplicateSites(List<DeployedSiteDoc> sites) async {
    final losers = pickDuplicateLosers(sites);
    for (final site in losers) {
      await _repo.deactivate(site.id);
    }
    return losers.length;
  }
}
