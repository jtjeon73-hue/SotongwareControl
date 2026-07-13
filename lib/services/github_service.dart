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
        sha: ((m['sha'] as String?) ?? '').substring(0, 7),
        repo: '$owner/$repo',
      );
    }).toList();
  }

  static ({String owner, String repo})? parseGithubUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.host != 'github.com') return null;
    final parts = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return null;
    return (owner: parts[0], repo: parts[1].replaceAll('.git', ''));
  }
}
