/// Cross-track design change → revision contract (v1 foundation).
/// Site STEP15 already implements the live loop; other tracks share this model.
library;

import 'design_system_catalog.dart';

class DesignChangeRequest {
  const DesignChangeRequest({
    required this.fromProfileCode,
    required this.toProfileCode,
    this.fromRevision = 'r1',
    this.changeType = 'design_change_requested',
    this.designSystemVersion = DesignSystemCatalog.kVersion,
    this.comment = '',
    this.functionalScopeRequested = false,
  });

  final String fromProfileCode;
  final String toProfileCode;
  final String fromRevision;
  final String changeType;
  final String designSystemVersion;
  final String comment;
  final bool functionalScopeRequested;

  Map<String, dynamic> toJson() => {
    'changeType': changeType,
    'fromProfileCode': fromProfileCode,
    'toProfileCode': toProfileCode,
    'fromRevision': fromRevision,
    'designSystemVersion': designSystemVersion,
    'designSource': 'revision_change',
    'functionalScopeRequested': functionalScopeRequested,
    'comment': comment,
    'preserve': const [
      'business_logic',
      'data_model',
      'core_features',
      'api_contract',
      'user_inputs',
      'primary_content',
      'seo_content',
      'project_identity',
      'artifact_revision_history',
    ],
    'mutable': const [
      'layout',
      'typography',
      'colors',
      'component_style',
      'navigation_presentation',
      'card_layout',
      'spacing',
      'illustration_image_direction',
      'animation',
      'visual_hierarchy',
    ],
  };
}

class RevisionDesignMetadata {
  const RevisionDesignMetadata({
    required this.revision,
    required this.parentRevision,
    required this.designProfileId,
    required this.designProfileCode,
    this.designProfileVersion = '1.0.0',
    this.designSystemVersion = DesignSystemCatalog.kVersion,
    this.changeType = '',
    this.createdAt = '',
    this.previewUrl = '',
    this.artifact = '',
    this.userDecision = '',
  });

  final int revision;
  final int parentRevision;
  final String designProfileId;
  final String designProfileCode;
  final String designProfileVersion;
  final String designSystemVersion;
  final String changeType;
  final String createdAt;
  final String previewUrl;
  final String artifact;
  final String userDecision;

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'parentRevision': parentRevision,
    'designProfileId': designProfileId,
    'designProfileCode': designProfileCode,
    'designProfileVersion': designProfileVersion,
    'designSystemVersion': designSystemVersion,
    'changeType': changeType,
    'createdAt': createdAt,
    'previewUrl': previewUrl,
    'artifact': artifact,
    'userDecision': userDecision,
  };
}
