/// Build/release identity shown in Control chrome.
/// Prefer dart-define injection at deploy time.
abstract final class ReleaseInfo {
  static const version = '0.2.5';

  /// Short git SHA (e.g. bff58e5). Injected via --dart-define=SOTONG_GIT_SHA=...
  static const gitSha = String.fromEnvironment(
    'SOTONG_GIT_SHA',
    defaultValue: 'local',
  );

  /// Build/deploy date YYYY-MM-DD. Injected via --dart-define=SOTONG_BUILT_AT=...
  static const builtAt = String.fromEnvironment(
    'SOTONG_BUILT_AT',
    defaultValue: '2026-09-08',
  );

  /// Backward-compatible alias used by older call sites.
  static const updatedAt = builtAt;

  static String get label {
    final sha = gitSha.trim();
    if (sha.isEmpty || sha == 'local') {
      return 'v$version · $builtAt';
    }
    return 'v$version · $sha · $builtAt';
  }
}
