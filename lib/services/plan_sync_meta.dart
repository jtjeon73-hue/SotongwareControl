/// Per-plan soft-mirror sync metadata (local SharedPreferences).
/// baseRevision is only confirmed after successful write or accepted cloud reload.
class PlanSyncMeta {
  const PlanSyncMeta({required this.baseRevision, required this.state});

  static const synced = 'synced';
  static const dirty = 'dirty';
  static const conflict = 'conflict';
  static const deleted = 'deleted';

  final int baseRevision;
  final String state;

  bool get isDirty => state == dirty;
  bool get isConflict => state == conflict;
  bool get isSynced => state == synced;
  bool get isDeleted => state == deleted;

  PlanSyncMeta copyWith({int? baseRevision, String? state}) => PlanSyncMeta(
    baseRevision: baseRevision ?? this.baseRevision,
    state: state ?? this.state,
  );

  Map<String, dynamic> toJson() => {
    'baseRevision': baseRevision,
    'state': state,
  };

  factory PlanSyncMeta.fromJson(Map<String, dynamic> json) => PlanSyncMeta(
    baseRevision: (json['baseRevision'] as num?)?.toInt() ?? 0,
    state: '${json['state'] ?? synced}',
  );

  static const defaults = PlanSyncMeta(baseRevision: 0, state: synced);
}
