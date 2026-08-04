/// DevWorkDoc 상대 경로 헬퍼 (절대 경로 생성 금지).
class DevWorkDocPaths {
  DevWorkDocPaths._();

  static const artifactFolders = {
    'app': 'App',
    'ebook': 'Ebook',
    'contents': 'Contents',
    'site': 'Site',
    'promo_site': 'PromoSite',
  };

  static const allArtifacts = ['App', 'Ebook', 'Contents', 'Site', 'PromoSite'];

  static const subFolders = ['Active', 'Versions', 'Archive'];

  /// artifactType: app|ebook|contents|site|promo_site → App|Ebook|…
  static String artifactFolder(String artifactType) {
    final key = artifactType.trim().toLowerCase();
    final folder = artifactFolders[key];
    if (folder == null) {
      throw ArgumentError.value(
        artifactType,
        'artifactType',
        'Unknown artifact type',
      );
    }
    return folder;
  }

  static String wiBaseName(String instructionId) =>
      'WI_${sanitizeInstructionId(instructionId)}';

  static String activeRelative(String artifact, String instructionId) {
    final folder = _resolveFolder(artifact);
    return '$folder/Active/${wiBaseName(instructionId)}.json';
  }

  static String versionRelative(
    String artifact,
    String instructionId,
    int version,
  ) {
    final folder = _resolveFolder(artifact);
    final id = sanitizeInstructionId(instructionId);
    return '$folder/Versions/$id/${wiBaseName(instructionId)}_v$version.json';
  }

  static String archiveRelative(
    String artifact,
    String instructionId,
    int version,
  ) {
    final folder = _resolveFolder(artifact);
    return '$folder/Archive/${wiBaseName(instructionId)}_v$version.json';
  }

  static String versionDirRelative(String artifact, String instructionId) {
    final folder = _resolveFolder(artifact);
    final id = sanitizeInstructionId(instructionId);
    return '$folder/Versions/$id';
  }

  /// Windows·브라우저 안전 파일명용 instructionId 정규화.
  static String sanitizeInstructionId(String raw) {
    const unsafe = r'[<>:"/\\|?*\x00-\x1F]';
    var s = raw.replaceAll(RegExp(unsafe), '').replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (s.isEmpty) s = 'untitled';
    if (s.length > 80) s = s.substring(0, 80);
    return s;
  }

  static String _resolveFolder(String artifact) {
    if (allArtifacts.contains(artifact)) return artifact;
    return artifactFolder(artifact);
  }
}
