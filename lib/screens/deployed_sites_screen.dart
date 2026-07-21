import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/deployed_site.dart';
import '../services/deployed_sites_repository.dart';
import '../services/deployed_sites_service.dart';
import '../services/firebase_ready.dart';
import '../theme/control_theme.dart';
import '../utils/external_url.dart';
import '../widgets/ops_ui.dart';
import '../widgets/page_hero.dart';

class DeployedSitesScreen extends StatefulWidget {
  const DeployedSitesScreen({super.key});

  @override
  State<DeployedSitesScreen> createState() => _DeployedSitesScreenState();
}

class _DeployedSitesScreenState extends State<DeployedSitesScreen> {
  final _repo = DeployedSitesRepository();
  late final _service = DeployedSitesService(_repo);
  var _filter = const DeployedSitesFilter();
  var _seeding = false;
  var _autoSeedAttempted = false;
  String? _seedMessage;

  Future<void> _seedOrImport({required bool missingOnly}) async {
    if (_seeding) return;
    setState(() {
      _seeding = true;
      _seedMessage = null;
    });
    try {
      final message = missingOnly
          ? await _service.importMissingVerifiedSites()
          : await _service.seedVerifiedSitesIfNeeded();
      if (!mounted) return;
      setState(() => _seedMessage = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _seedMessage = '$e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _maybeAutoSeed(List<DeployedSiteDoc> sites) {
    if (_autoSeedAttempted || _seeding || sites.isNotEmpty) return;
    _autoSeedAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seedOrImport(missingOnly: false);
    });
  }

  Future<void> _openEditor({DeployedSiteDoc? site}) async {
    final result = await showDialog<DeployedSiteDoc>(
      context: context,
      builder: (context) => _SiteEditorDialog(site: site),
    );
    if (result == null) return;
    final existing = await _repo.fetchSitesOnce();
    if (DeployedSitesService.isDuplicate(
      existing,
      liveUrl: result.liveUrl,
      firebaseProjectId: result.firebaseProjectId,
      excludeId: site?.id,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('같은 운영 주소 또는 Project ID가 이미 있습니다.')),
      );
      return;
    }
    await _repo.upsertSite(result, isNew: site == null);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('배포사이트 정보를 저장했습니다.')));
  }

  Future<void> _showDetail(DeployedSiteDoc site) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SiteDetailDialog(
        site: site,
        onEdit: () {
          Navigator.of(context).pop();
          _openEditor(site: site);
        },
        onStatus: (status) async {
          await _repo.setStatus(site.id, status);
          if (context.mounted) Navigator.of(context).pop();
        },
        onFavorite: () => _repo.setFavorite(site.id, !site.isFavorite),
        onRecordCheck: () async {
          Navigator.of(context).pop();
          await _openCheckDialog(site);
        },
      ),
    );
  }

  Future<void> _openCheckDialog(DeployedSiteDoc site) async {
    final issues = TextEditingController(text: site.issues);
    final next = TextEditingController(text: site.nextAction);
    final memo = TextEditingController(text: site.adminMemo);
    var mobile = site.mobileChecked;
    var desktop = site.desktopChecked;
    var https = site.httpsChecked;
    var status = site.status == DeployedSiteStatus.inactive
        ? DeployedSiteStatus.operating
        : site.status;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('${site.nameKo} 점검 기록'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: '상태'),
                        items: [
                          for (final s in DeployedSiteStatus.all)
                            DropdownMenuItem(
                              value: s,
                              child: Text(DeployedSiteStatus.labelKo(s)),
                            ),
                        ],
                        onChanged: (v) => setLocal(() => status = v ?? status),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('모바일 확인'),
                        value: mobile,
                        onChanged: (v) => setLocal(() => mobile = v ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('데스크톱 확인'),
                        value: desktop,
                        onChanged: (v) => setLocal(() => desktop = v ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('HTTPS 확인'),
                        value: https,
                        onChanged: (v) => setLocal(() => https = v ?? false),
                      ),
                      TextField(
                        controller: issues,
                        decoration: const InputDecoration(labelText: '문제·주의사항'),
                        maxLines: 2,
                      ),
                      TextField(
                        controller: next,
                        decoration: const InputDecoration(labelText: '다음 작업'),
                      ),
                      TextField(
                        controller: memo,
                        decoration: const InputDecoration(labelText: '관리자 메모'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) return;
    await _repo.recordCheck(
      id: site.id,
      issues: issues.text,
      nextAction: next.text,
      adminMemo: memo.text,
      mobileChecked: mobile,
      desktopChecked: desktop,
      httpsChecked: https,
      status: status,
    );
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('주소를 복사했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseReady()) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePanel(
          title: '웹 배포사이트',
          message: 'Firebase 연결 후 배포사이트 관제를 사용할 수 있습니다.',
        ),
      );
    }

    return StreamBuilder<List<DeployedSiteDoc>>(
      stream: _repo.watchSites(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStatePanel(
              title: '배포사이트 로딩 오류',
              message: '${snapshot.error}',
            ),
          );
        }
        final sites = snapshot.data ?? const <DeployedSiteDoc>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            sites.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        _maybeAutoSeed(sites);

        final kpis = DeployedSitesService.computeKpis(sites);
        final filtered = DeployedSitesService.applyFilter(sites, _filter);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHero(
                title: '웹 배포사이트',
                subtitle:
                    'Firebase Hosting 등 실제 운영 중인 소통웨어 웹사이트를 한곳에서 확인하고 관리합니다.',
                badge: '배포 관제',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _seeding
                          ? null
                          : () => _seedOrImport(missingOnly: true),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(_seeding ? '등록 중…' : '확인 사이트 불러오기'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('사이트 등록'),
                    ),
                  ],
                ),
              ),
              if (_seedMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _seedMessage!,
                  style: const TextStyle(color: ControlColors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  KpiCard(label: '전체 사이트', value: '${kpis.total}'),
                  KpiCard(label: '정상 운영', value: '${kpis.operating}'),
                  KpiCard(label: '점검 필요', value: '${kpis.needsCheck}'),
                  KpiCard(
                    label: '개발·배포 준비',
                    value: '${kpis.preparingOrDeploying}',
                  ),
                  KpiCard(label: '비활성', value: '${kpis.inactive}'),
                  KpiCard(label: '최근 7일 배포', value: '${kpis.recentlyDeployed}'),
                ],
              ),
              const SizedBox(height: 16),
              _FilterBar(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 16),
              if (sites.isEmpty)
                EmptyStatePanel(
                  title: '등록된 배포사이트가 없습니다',
                  message:
                      '확인된 Firebase Hosting 사이트를 불러오거나 직접 등록하십시오. '
                      '확인되지 않은 주소는 임의로 만들지 않습니다.',
                  actionLabel: '확인 사이트 불러오기',
                  onAction: _seeding
                      ? null
                      : () => _seedOrImport(missingOnly: true),
                )
              else if (filtered.isEmpty)
                const EmptyStatePanel(
                  title: '검색 결과가 없습니다',
                  message: '필터 조건을 바꿔 다시 확인하십시오.',
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1180
                        ? 3
                        : constraints.maxWidth >= 720
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final site in filtered)
                          SizedBox(
                            width: width,
                            child: _SiteCard(
                              site: site,
                              onOpen: site.hasLiveUrl
                                  ? () => ExternalUrl.open(site.liveUrl)
                                  : null,
                              onGithub: site.hasGithubUrl
                                  ? () => ExternalUrl.open(site.githubUrl)
                                  : null,
                              onCopy: site.hasLiveUrl
                                  ? () => _copyUrl(site.liveUrl)
                                  : null,
                              onDetail: () => _showDetail(site),
                              onEdit: () => _openEditor(site: site),
                              onFavorite: () =>
                                  _repo.setFavorite(site.id, !site.isFavorite),
                              onStatus: (status) =>
                                  _repo.setStatus(site.id, status),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              const Text(
                '접속 상태는 브라우저 CORS 제한 때문에 자동 장애 판정을 하지 않습니다. '
                '관리자 점검 결과·배포 기록·HTTPS 등록 여부를 기준으로 관리합니다.',
                style: TextStyle(color: ControlColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final DeployedSitesFilter filter;
  final ValueChanged<DeployedSitesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '사이트명 검색',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => onChanged(filter.copyWith(query: v)),
              ),
            ),
            DropdownButton<String?>(
              value: filter.category,
              hint: const Text('사업 분야'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 분야')),
                for (final c in DeployedSiteCategory.all)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => onChanged(
                filter.copyWith(category: v, clearCategory: v == null),
              ),
            ),
            DropdownButton<String?>(
              value: filter.status,
              hint: const Text('배포 상태'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 상태')),
                for (final s in DeployedSiteStatus.all)
                  DropdownMenuItem(
                    value: s,
                    child: Text(DeployedSiteStatus.labelKo(s)),
                  ),
              ],
              onChanged: (v) =>
                  onChanged(filter.copyWith(status: v, clearStatus: v == null)),
            ),
            DropdownButton<String?>(
              value: filter.hostingType,
              hint: const Text('호스팅'),
              items: [
                const DropdownMenuItem(value: null, child: Text('전체 호스팅')),
                for (final h in DeployedHostingType.all)
                  DropdownMenuItem(value: h, child: Text(h)),
              ],
              onChanged: (v) => onChanged(
                filter.copyWith(hostingType: v, clearHostingType: v == null),
              ),
            ),
            FilterChip(
              label: const Text('즐겨찾기만'),
              selected: filter.favoritesOnly,
              onSelected: (v) => onChanged(filter.copyWith(favoritesOnly: v)),
            ),
            DropdownButton<DeployedSitesSort>(
              value: filter.sort,
              items: const [
                DropdownMenuItem(
                  value: DeployedSitesSort.recentDeploy,
                  child: Text('최근 배포순'),
                ),
                DropdownMenuItem(
                  value: DeployedSitesSort.name,
                  child: Text('이름순'),
                ),
                DropdownMenuItem(
                  value: DeployedSitesSort.needsCheckFirst,
                  child: Text('점검 필요 우선'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(filter.copyWith(sort: v));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.onOpen,
    required this.onGithub,
    required this.onCopy,
    required this.onDetail,
    required this.onEdit,
    required this.onFavorite,
    required this.onStatus,
  });

  final DeployedSiteDoc site;
  final VoidCallback? onOpen;
  final VoidCallback? onGithub;
  final VoidCallback? onCopy;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onFavorite;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final statusColor = DeployedSiteStatus.color(site.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ControlColors.tealSoft,
                  child: Icon(site.materialIcon, color: ControlColors.teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.nameKo,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (site.nameEn.isNotEmpty)
                        Text(
                          site.nameEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ControlColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onFavorite,
                  icon: Icon(
                    site.isFavorite ? Icons.star : Icons.star_border,
                    color: site.isFavorite
                        ? ControlColors.accentWarm
                        : ControlColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              site.description.isEmpty ? '설명 미등록' : site.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusBadge(label: site.category),
                StatusBadge(
                  label: DeployedSiteStatus.labelKo(site.status),
                  color: statusColor,
                ),
                StatusBadge(
                  label: site.hostingType,
                  color: ControlColors.sandBeige,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Project: ${site.firebaseProjectId.isEmpty ? '확인 필요' : site.firebaseProjectId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '운영: ${site.hasLiveUrl ? site.liveUrl : '주소 미등록'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'GitHub: ${site.hasGithubUrl ? site.githubUrl : '확인 필요'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text('마지막 배포: ${_fmt(site.lastDeployedAt)}'),
            Text('마지막 점검: ${_fmt(site.lastCheckedAt)}'),
            if (site.adminMemo.isNotEmpty)
              Text(
                '메모: ${site.adminMemo}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (site.issues.isNotEmpty)
              Text(
                '점검: ${site.issues}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ControlColors.accentWarm),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton(onPressed: onOpen, child: const Text('사이트 열기')),
                OutlinedButton(
                  onPressed: onGithub,
                  child: const Text('GitHub'),
                ),
                OutlinedButton(onPressed: onCopy, child: const Text('주소 복사')),
                TextButton(onPressed: onDetail, child: const Text('상세보기')),
                TextButton(onPressed: onEdit, child: const Text('수정')),
                PopupMenuButton<String>(
                  tooltip: '상태 변경',
                  onSelected: onStatus,
                  itemBuilder: (context) => [
                    for (final s in DeployedSiteStatus.all)
                      PopupMenuItem(
                        value: s,
                        child: Text(DeployedSiteStatus.labelKo(s)),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text('상태 변경'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime? d) =>
      d == null ? '기록 없음' : DateFormat('yyyy-MM-dd HH:mm').format(d);
}

class _SiteDetailDialog extends StatelessWidget {
  const _SiteDetailDialog({
    required this.site,
    required this.onEdit,
    required this.onStatus,
    required this.onFavorite,
    required this.onRecordCheck,
  });

  final DeployedSiteDoc site;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onFavorite;
  final VoidCallback onRecordCheck;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(site.nameKo),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line('영문명', site.nameEn.isEmpty ? '확인 필요' : site.nameEn),
              _line(
                '설명',
                site.description.isEmpty ? '확인 필요' : site.description,
              ),
              _line('사업 분야', site.category),
              _line('상태', DeployedSiteStatus.labelKo(site.status)),
              _line('호스팅', site.hostingType),
              _line(
                'Firebase Project ID',
                site.firebaseProjectId.isEmpty
                    ? '확인 필요'
                    : site.firebaseProjectId,
              ),
              _line('운영 주소', site.hasLiveUrl ? site.liveUrl : '주소 미등록'),
              _line('GitHub', site.hasGithubUrl ? site.githubUrl : '확인 필요'),
              _line(
                '최근 작업',
                site.recentWork.isEmpty ? '기록 없음' : site.recentWork,
              ),
              _line(
                '최근 배포결과',
                site.lastDeployResult.isEmpty ? '기록 없음' : site.lastDeployResult,
              ),
              _line('모바일 확인', site.mobileChecked ? '확인' : '미확인'),
              _line('데스크톱 확인', site.desktopChecked ? '확인' : '미확인'),
              _line('HTTPS 확인', site.httpsChecked ? '확인' : '미확인'),
              _line('마지막 점검', _SiteCard._fmt(site.lastCheckedAt)),
              _line('문제·주의사항', site.issues.isEmpty ? '없음' : site.issues),
              _line('다음 작업', site.nextAction.isEmpty ? '없음' : site.nextAction),
              _line('관리자 메모', site.adminMemo.isEmpty ? '없음' : site.adminMemo),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: onFavorite, child: const Text('즐겨찾기')),
        TextButton(onPressed: onRecordCheck, child: const Text('점검 기록')),
        TextButton(onPressed: onEdit, child: const Text('수정')),
        PopupMenuButton<String>(
          onSelected: onStatus,
          itemBuilder: (context) => [
            for (final s in DeployedSiteStatus.all)
              PopupMenuItem(
                value: s,
                child: Text(DeployedSiteStatus.labelKo(s)),
              ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('상태 변경'),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText('$label: $value'),
    );
  }
}

class _SiteEditorDialog extends StatefulWidget {
  const _SiteEditorDialog({this.site});

  final DeployedSiteDoc? site;

  @override
  State<_SiteEditorDialog> createState() => _SiteEditorDialogState();
}

class _SiteEditorDialogState extends State<_SiteEditorDialog> {
  late final _nameKo = TextEditingController(text: widget.site?.nameKo ?? '');
  late final _nameEn = TextEditingController(text: widget.site?.nameEn ?? '');
  late final _description = TextEditingController(
    text: widget.site?.description ?? '',
  );
  late final _projectId = TextEditingController(
    text: widget.site?.firebaseProjectId ?? '',
  );
  late final _liveUrl = TextEditingController(text: widget.site?.liveUrl ?? '');
  late final _githubUrl = TextEditingController(
    text: widget.site?.githubUrl ?? '',
  );
  late final _memo = TextEditingController(text: widget.site?.adminMemo ?? '');
  late final _issues = TextEditingController(text: widget.site?.issues ?? '');
  late final _next = TextEditingController(text: widget.site?.nextAction ?? '');
  late String _category = widget.site?.category ?? DeployedSiteCategory.other;
  late String _hosting =
      widget.site?.hostingType ?? DeployedHostingType.firebase;
  late String _status = widget.site?.status ?? DeployedSiteStatus.needsCheck;
  late bool _favorite = widget.site?.isFavorite ?? false;

  @override
  void dispose() {
    _nameKo.dispose();
    _nameEn.dispose();
    _description.dispose();
    _projectId.dispose();
    _liveUrl.dispose();
    _githubUrl.dispose();
    _memo.dispose();
    _issues.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.site == null ? '사이트 등록' : '사이트 수정'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameKo,
                decoration: const InputDecoration(labelText: '한글 사이트명 *'),
              ),
              TextField(
                controller: _nameEn,
                decoration: const InputDecoration(labelText: '영문 프로젝트명'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: '설명'),
                maxLines: 2,
              ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: '사업 분야'),
                items: [
                  for (final c in DeployedSiteCategory.all)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              DropdownButtonFormField<String>(
                initialValue: _hosting,
                decoration: const InputDecoration(labelText: '호스팅 방식'),
                items: [
                  for (final h in DeployedHostingType.all)
                    DropdownMenuItem(value: h, child: Text(h)),
                ],
                onChanged: (v) => setState(() => _hosting = v ?? _hosting),
              ),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '상태'),
                items: [
                  for (final s in DeployedSiteStatus.all)
                    DropdownMenuItem(
                      value: s,
                      child: Text(DeployedSiteStatus.labelKo(s)),
                    ),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              TextField(
                controller: _projectId,
                decoration: const InputDecoration(
                  labelText: 'Firebase Project ID',
                ),
              ),
              TextField(
                controller: _liveUrl,
                decoration: const InputDecoration(labelText: '운영 주소'),
              ),
              TextField(
                controller: _githubUrl,
                decoration: const InputDecoration(labelText: 'GitHub 주소'),
              ),
              TextField(
                controller: _issues,
                decoration: const InputDecoration(labelText: '점검 필요 사항'),
              ),
              TextField(
                controller: _next,
                decoration: const InputDecoration(labelText: '다음 작업'),
              ),
              TextField(
                controller: _memo,
                decoration: const InputDecoration(labelText: '관리자 메모'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('즐겨찾기'),
                value: _favorite,
                onChanged: (v) => setState(() => _favorite = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameKo.text.trim().isEmpty) return;
            final base =
                widget.site ??
                DeployedSiteDoc(id: '', nameKo: _nameKo.text.trim());
            Navigator.pop(
              context,
              base.copyWith(
                nameKo: _nameKo.text.trim(),
                nameEn: _nameEn.text.trim(),
                description: _description.text.trim(),
                category: _category,
                hostingType: _hosting,
                firebaseProjectId: _projectId.text.trim(),
                liveUrl: _liveUrl.text.trim(),
                githubUrl: _githubUrl.text.trim(),
                status: _status,
                isFavorite: _favorite,
                issues: _issues.text.trim(),
                nextAction: _next.text.trim(),
                adminMemo: _memo.text.trim(),
                isActive: _status != DeployedSiteStatus.inactive,
                httpsChecked: _liveUrl.text.trim().startsWith('https://'),
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
