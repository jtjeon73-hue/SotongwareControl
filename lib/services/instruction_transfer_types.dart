class FolderPermissionState {
  const FolderPermissionState({
    required this.supported,
    required this.hasHandle,
    this.folderName,
    this.permissionGranted = false,
  });

  final bool supported;
  final bool hasHandle;
  final String? folderName;
  final bool permissionGranted;
}

class TransferWriteResult {
  const TransferWriteResult({
    required this.ok,
    required this.mode,
    this.fileName,
    this.message,
    this.errorCode,
  });

  /// folder | download | failed
  final String mode;
  final bool ok;
  final String? fileName;
  final String? message;
  final String? errorCode;
}
