class DevWorkDocState {
  const DevWorkDocState({
    required this.supported,
    required this.hasRoot,
    this.rootFolderName,
    this.permissionGranted = false,
  });

  final bool supported;
  final bool hasRoot;
  final String? rootFolderName;
  final bool permissionGranted;
}

class DevWorkDocWriteResult {
  const DevWorkDocWriteResult({
    required this.ok,
    required this.mode,
    this.activePathHint,
    this.versionPathHint,
    this.message,
    this.errorCode,
    this.checksum,
    this.fileName,
  });

  /// folder | download | failed
  final String mode;
  final bool ok;
  final String? activePathHint;
  final String? versionPathHint;
  final String? message;
  final String? errorCode;
  final String? checksum;
  final String? fileName;
}
