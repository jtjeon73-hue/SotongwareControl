import 'dart:convert';

import 'package:http/http.dart' as http;

class GithubCommitInfo {
  const GithubCommitInfo({
    required this.message,
    required this.author,
    required this.date,
    required this.url,
    required this.sha,
    required this.repo,
  });

  final String message;
  final String author;
  final DateTime? date;
  final String url;
  final String sha;
  final String repo;
}

class GithubRepositoryInspection {
  const GithubRepositoryInspection({
    required this.repo,
    required this.defaultBranch,
    required this.lastPushedAt,
    required this.hasReadme,
    required this.hasTests,
    required this.hasFirebaseConfig,
    required this.hasFlutterProject,
    required this.hasWebProject,
    required this.recentCommits,
  });

  final String repo;
  final String defaultBranch;
  final DateTime? lastPushedAt;
  final bool hasReadme;
  final bool hasTests;
  final bool hasFirebaseConfig;
  final bool hasFlutterProject;
  final bool hasWebProject;
  final List<GithubCommitInfo> recentCommits;
}

class GithubService {
  /// owner/repo 형태의 공개 저장소만 조회. 토큰 사용 안 함.
  Future<List<GithubCommitInfo>> fetchRecentCommits({
    required String owner,
    required String repo,
    int limit = 5,
  }) async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repo/commits', {
      'per_page': '$limit',
    });
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode == 404) {
      throw Exception('저장소를 찾을 수 없거나 비공개입니다.');
    }
    if (res.statusCode != 200) {
      throw Exception('GitHub 조회 실패 (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      final commit = m['commit'] as Map<String, dynamic>? ?? {};
      final author = commit['author'] as Map<String, dynamic>? ?? {};
      return GithubCommitInfo(
        message: (commit['message'] as String?)?.split('\n').first ?? '',
        author: (author['name'] as String?) ?? '',
        date: DateTime.tryParse((author['date'] as String?) ?? ''),
        url: (m['html_url'] as String?) ?? '',
        sha: _shortSha((m['sha'] as String?) ?? ''),
        repo: '$owner/$repo',
      );
    }).toList();
  }

  Future<GithubRepositoryInspection> inspectPublicRepository({
    required String owner,
    required String repo,
  }) async {
    final metadataUri = Uri.https('api.github.com', '/repos/$owner/$repo');
    final metadataResponse = await http.get(
      metadataUri,
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (metadataResponse.statusCode != 200) {
      throw Exception(
        metadataResponse.statusCode == 404
            ? '저장소를 찾을 수 없거나 비공개입니다.'
            : 'GitHub 저장소 조회 실패 (${metadataResponse.statusCode})',
      );
    }
    final metadata = jsonDecode(metadataResponse.body) as Map<String, dynamic>;
    final branch = '${metadata['default_branch'] ?? 'main'}';
    final treeUri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/git/trees/$branch',
      {'recursive': '1'},
    );
    final treeResponse = await http.get(
      treeUri,
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (treeResponse.statusCode != 200) {
      throw Exception('GitHub 파일 구조 조회 실패 (${treeResponse.statusCode})');
    }
    final tree = jsonDecode(treeResponse.body) as Map<String, dynamic>;
    final paths = (tree['tree'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => '${e['path'] ?? ''}'.toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final commits = await fetchRecentCommits(
      owner: owner,
      repo: repo,
      limit: 5,
    );

    return GithubRepositoryInspection(
      repo: '$owner/$repo',
      defaultBranch: branch,
      lastPushedAt: DateTime.tryParse('${metadata['pushed_at'] ?? ''}'),
      hasReadme: paths.any(
        (p) => p == 'readme.md' || p == 'readme' || p.startsWith('readme.'),
      ),
      hasTests: paths.any(
        (p) =>
            p.startsWith('test/') ||
            p.startsWith('tests/') ||
            p.contains('/test/') ||
            p.contains('/tests/'),
      ),
      hasFirebaseConfig: paths.contains('firebase.json'),
      hasFlutterProject: paths.contains('pubspec.yaml'),
      hasWebProject:
          paths.contains('web/index.html') || paths.contains('package.json'),
      recentCommits: commits,
    );
  }

  static String _shortSha(String sha) =>
      sha.length <= 7 ? sha : sha.substring(0, 7);

  static ({String owner, String repo})? parseGithubUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.host != 'github.com') return null;
    final parts = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return null;
    return (owner: parts[0], repo: parts[1].replaceAll('.git', ''));
  }
}
