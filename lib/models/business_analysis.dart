import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _analysisDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class BusinessAnalysisReport {
  const BusinessAnalysisReport({
    required this.id,
    required this.overallStatus,
    required this.overallScore,
    required this.summary,
    required this.businessResults,
    required this.projectResults,
    required this.weaknesses,
    required this.recommendations,
    required this.priorities,
    required this.sourceMetrics,
    this.comparison = const {},
    this.analysisMethod = 'rules_based',
    this.githubStatus = 'not_requested',
    this.githubError = '',
    this.createdAt,
    this.sourceDataUpdatedAt,
  });

  final String id;
  final String overallStatus;
  final int overallScore;
  final String summary;
  final List<Map<String, dynamic>> businessResults;
  final List<Map<String, dynamic>> projectResults;
  final List<String> weaknesses;
  final List<String> recommendations;
  final List<String> priorities;
  final Map<String, dynamic> sourceMetrics;
  final Map<String, dynamic> comparison;
  final String analysisMethod;
  final String githubStatus;
  final String githubError;
  final DateTime? createdAt;
  final DateTime? sourceDataUpdatedAt;

  factory BusinessAnalysisReport.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    List<Map<String, dynamic>> maps(dynamic value) =>
        (value as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    List<String> strings(dynamic value) =>
        (value as List? ?? const []).map((e) => '$e').toList();

    return BusinessAnalysisReport(
      id: doc.id,
      overallStatus: '${data['overallStatus'] ?? '확인 필요'}',
      overallScore: (data['overallScore'] as num?)?.round() ?? 0,
      summary: '${data['summary'] ?? ''}',
      businessResults: maps(data['businessResults']),
      projectResults: maps(data['projectResults']),
      weaknesses: strings(data['weaknesses']),
      recommendations: strings(data['recommendations']),
      priorities: strings(data['priorities']),
      sourceMetrics: Map<String, dynamic>.from(
        data['sourceMetrics'] as Map? ?? const {},
      ),
      comparison: Map<String, dynamic>.from(
        data['comparison'] as Map? ?? const {},
      ),
      analysisMethod: '${data['analysisMethod'] ?? 'rules_based'}',
      githubStatus: '${data['githubStatus'] ?? 'not_requested'}',
      githubError: '${data['githubError'] ?? ''}',
      createdAt: _analysisDate(data['createdAt']),
      sourceDataUpdatedAt: _analysisDate(data['sourceDataUpdatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) => {
    'overallStatus': overallStatus,
    'overallScore': overallScore,
    'summary': summary,
    'businessResults': businessResults,
    'projectResults': projectResults,
    'weaknesses': weaknesses,
    'recommendations': recommendations,
    'priorities': priorities,
    'sourceMetrics': sourceMetrics,
    'comparison': comparison,
    'analysisMethod': analysisMethod,
    'githubStatus': githubStatus,
    'githubError': githubError,
    'sourceDataUpdatedAt': sourceDataUpdatedAt == null
        ? null
        : Timestamp.fromDate(sourceDataUpdatedAt!),
    if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
  };
}
