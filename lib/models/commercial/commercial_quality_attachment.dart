/// Top-level commercial attachment serialized onto WorkInstruction JSON.
/// Paths match Sotong24Work inbox enforce (HEAD 5b204b7).
library;

import '../artifact_type.dart';
import 'commercial_track_profiles.dart';
import 'work_instruction_brief.dart';

class CommercialQualityAttachment {
  const CommercialQualityAttachment({
    this.briefContractVersion = WorkInstructionBrief.kBriefContractVersion,
    this.brief = const WorkInstructionBrief(present: false),
    this.appQualityContractVersion,
    this.ebookQualityContractVersion,
    this.siteQualityContractVersion,
    this.contentQualityContractVersion,
    this.appProfile = const CommercialAppQualityProfile(present: false),
    this.ebookProfile = const CommercialEbookQualityProfile(present: false),
    this.siteProfile = const CommercialSiteQualityProfile(present: false),
    this.contentProfile = const CommercialContentQualityProfile(present: false),
  });

  final int briefContractVersion;
  final WorkInstructionBrief brief;
  final int? appQualityContractVersion;
  final int? ebookQualityContractVersion;
  final int? siteQualityContractVersion;
  final int? contentQualityContractVersion;
  final CommercialAppQualityProfile appProfile;
  final CommercialEbookQualityProfile ebookProfile;
  final CommercialSiteQualityProfile siteProfile;
  final CommercialContentQualityProfile contentProfile;

  /// Fields merged at instruction root (Work parser paths).
  Map<String, dynamic> toInstructionJsonFields() {
    final out = <String, dynamic>{};
    if (brief.present) {
      out['briefContractVersion'] = briefContractVersion;
      out['workInstructionBrief'] = brief.toJson();
    }
    if (appProfile.present) {
      out['appQualityContractVersion'] = appQualityContractVersion ?? 1;
      out['commercialAppQualityProfile'] = appProfile.toJson();
    }
    if (ebookProfile.present) {
      out['ebookQualityContractVersion'] = ebookQualityContractVersion ?? 1;
      out['commercialEbookQualityProfile'] = ebookProfile.toJson();
    }
    if (siteProfile.present) {
      out['siteQualityContractVersion'] = siteQualityContractVersion ?? 1;
      out['commercialSiteQualityProfile'] = siteProfile.toJson();
    }
    if (contentProfile.present) {
      out['contentQualityContractVersion'] = contentQualityContractVersion ?? 1;
      out['commercialContentQualityProfile'] = contentProfile.toJson();
    }
    return out;
  }

  factory CommercialQualityAttachment.fromInstructionJson(
    Map<String, dynamic> json,
  ) {
    Map<String, dynamic>? asMap(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;

    final briefNode =
        asMap(json['workInstructionBrief']) ?? asMap(json['briefContract']);
    return CommercialQualityAttachment(
      briefContractVersion: _asInt(
        json['briefContractVersion'],
        briefNode == null ? 0 : WorkInstructionBrief.kBriefContractVersion,
      ),
      brief: WorkInstructionBrief.fromJson(briefNode),
      appQualityContractVersion: json.containsKey('appQualityContractVersion')
          ? _asInt(json['appQualityContractVersion'], 0)
          : null,
      ebookQualityContractVersion:
          json.containsKey('ebookQualityContractVersion')
          ? _asInt(json['ebookQualityContractVersion'], 0)
          : null,
      siteQualityContractVersion: json.containsKey('siteQualityContractVersion')
          ? _asInt(json['siteQualityContractVersion'], 0)
          : null,
      contentQualityContractVersion:
          json.containsKey('contentQualityContractVersion')
          ? _asInt(json['contentQualityContractVersion'], 0)
          : null,
      appProfile: CommercialAppQualityProfile.fromJson(
        asMap(json['commercialAppQualityProfile']),
      ),
      ebookProfile: CommercialEbookQualityProfile.fromJson(
        asMap(json['commercialEbookQualityProfile']),
      ),
      siteProfile: CommercialSiteQualityProfile.fromJson(
        asMap(json['commercialSiteQualityProfile']),
      ),
      contentProfile: CommercialContentQualityProfile.fromJson(
        asMap(json['commercialContentQualityProfile']),
      ),
    );
  }

  bool get hasAnyCommercial =>
      brief.present ||
      appProfile.present ||
      ebookProfile.present ||
      siteProfile.present ||
      contentProfile.present;

  /// Track for which profile is expected given artifactType.
  static String expectedTrack(String artifactType) {
    final a = ArtifactType.normalize(artifactType);
    switch (a) {
      case ArtifactType.app:
        return 'app';
      case ArtifactType.ebook:
        return 'ebook';
      case ArtifactType.site:
      case ArtifactType.promoSite:
        return 'site';
      case ArtifactType.contents:
        return 'content';
      default:
        return '';
    }
  }
}

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
