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
          .where((s) => s.status == DeployedSiteStatus.operating)
          .length,
      needsCheck: active
          .where((s) => s.status == DeployedSiteStatus.needsCheck)
          .length,
      preparingOrDeploying: active
          .where(
            (s) =>
                s.status == DeployedSiteStatus.preparing ||
                s.status == DeployedSiteStatus.deploying,
          )
          .length,
      inactive: sites
          .where((s) => !s.isActive || s.status == DeployedSiteStatus.inactive)
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
      if (filter.status != null && s.status != filter.status) return false;
      if (filter.hostingType != null && s.hostingType != filter.hostingType) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.nameKo.toLowerCase().contains(q) ||
          s.nameEn.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.liveUrl.toLowerCase().contains(q) ||
          s.firebaseProjectId.toLowerCase().contains(q);
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
          final aw = a.status == DeployedSiteStatus.needsCheck ? 0 : 1;
          final bw = b.status == DeployedSiteStatus.needsCheck ? 0 : 1;
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
    String? excludeId,
  }) {
    final url = liveUrl.trim().toLowerCase();
    final projectId = firebaseProjectId.trim().toLowerCase();
    for (final site in existing) {
      if (excludeId != null && site.id == excludeId) continue;
      if (url.isNotEmpty && site.liveUrl.trim().toLowerCase() == url) {
        return true;
      }
      if (projectId.isNotEmpty &&
          site.firebaseProjectId.trim().toLowerCase() == projectId) {
        return true;
      }
    }
    return false;
  }

  Future<String> seedVerifiedSitesIfNeeded({
    bool forcePreviewOnly = false,
  }) async {
    final existing = await _repo.fetchSitesOnce();
    if (forcePreviewOnly) {
      return '미리보기 전용: 확인된 후보 ${DeployedSitesCatalog.verifiedSeeds.length}건';
    }
    if (existing.isNotEmpty || await _repo.isCatalogSeeded()) {
      return '이미 등록된 배포사이트가 있어 초기 시드를 건너뛰었습니다.';
    }

    var created = 0;
    for (final seed in DeployedSitesCatalog.verifiedSeeds) {
      if (isDuplicate(
        existing,
        liveUrl: seed.liveUrl,
        firebaseProjectId: seed.firebaseProjectId,
      )) {
        continue;
      }
      await _repo.upsertSite(
        seed.copyWith(lastDeployedAt: DateTime.now()),
        isNew: true,
      );
      created++;
      existing.add(seed);
    }
    await _repo.markCatalogSeeded(count: created);
    return '확인된 배포사이트 $created건을 등록했습니다.';
  }

  Future<String> importMissingVerifiedSites() async {
    final existing = await _repo.fetchSitesOnce();
    var created = 0;
    for (final seed in DeployedSitesCatalog.verifiedSeeds) {
      if (isDuplicate(
        existing,
        liveUrl: seed.liveUrl,
        firebaseProjectId: seed.firebaseProjectId,
      )) {
        continue;
      }
      await _repo.upsertSite(
        seed.copyWith(lastDeployedAt: DateTime.now()),
        isNew: true,
      );
      created++;
      existing.add(seed);
    }
    if (!await _repo.isCatalogSeeded()) {
      await _repo.markCatalogSeeded(count: created);
    }
    return created == 0
        ? '추가할 신규 확인 사이트가 없습니다.'
        : '누락된 확인 사이트 $created건을 추가했습니다.';
  }
}
