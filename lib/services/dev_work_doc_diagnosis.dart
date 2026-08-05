/// DevWorkDoc Versions/Active 진단 결과.
library;

class DevWorkDocVersionFileInfo {
  const DevWorkDocVersionFileInfo({
    required this.version,
    required this.relativePath,
    required this.exists,
    this.size = 0,
    this.stableChecksum = '',
    this.instructionId = '',
    this.parseOk = false,
  });

  final int version;
  final String relativePath;
  final bool exists;
  final int size;
  final String stableChecksum;
  final String instructionId;
  final bool parseOk;
}

class DevWorkDocDiagnosis {
  const DevWorkDocDiagnosis({
    required this.instructionId,
    required this.artifactType,
    required this.versions,
    required this.activeExists,
    this.activeVersion,
    this.activeStableChecksum = '',
    this.activeBytes = 0,
    this.activeRelativePath = '',
    this.appVersion,
    this.appStableChecksum = '',
    this.recommendedVersion,
    this.coreDiffersFromApp = false,
    this.metadataOnlyVsApp = false,
    this.summary = '',
    this.nextAction = '',
  });

  final String instructionId;
  final String artifactType;
  final List<DevWorkDocVersionFileInfo> versions;
  final bool activeExists;
  final int? activeVersion;
  final String activeStableChecksum;
  final int activeBytes;
  final String activeRelativePath;
  final int? appVersion;
  final String appStableChecksum;
  final int? recommendedVersion;
  final bool coreDiffersFromApp;
  final bool metadataOnlyVsApp;
  final String summary;
  final String nextAction;

  DevWorkDocVersionFileInfo? get latestValidVersion {
    final ok = versions.where((v) => v.exists && v.parseOk).toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return ok.isEmpty ? null : ok.first;
  }
}
