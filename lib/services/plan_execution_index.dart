/// instructionId 기준 실행 mirror 인덱스 (sotong24work_projects + jobs).
library;

import '../models/business_planning.dart';
import '../models/remote_agent_models.dart';
import '../models/sotong24_remote_models.dart';
import 'plan_execution_status.dart';

class PlanExecutionIndex {
  PlanExecutionIndex({
    Map<String, Sotong24RemoteProject>? projectsByInstructionId,
    Map<String, RemoteJobDoc>? jobsByInstructionId,
    Map<String, PlanExecutionRemoteHints>? hintsByInstructionId,
  }) : _projects = projectsByInstructionId ?? const {},
       _jobs = jobsByInstructionId ?? const {},
       _hints = hintsByInstructionId ?? const {};

  final Map<String, Sotong24RemoteProject> _projects;
  final Map<String, RemoteJobDoc> _jobs;
  final Map<String, PlanExecutionRemoteHints> _hints;

  static PlanExecutionIndex fromRemoteProjects(
    List<Sotong24RemoteProject> projects, {
    List<RemoteJobDoc> jobs = const [],
    Map<String, PlanExecutionRemoteHints> extraHints = const {},
  }) {
    final byInstr = <String, Sotong24RemoteProject>{};
    for (final p in projects) {
      if (p.isDemo) continue;
      final id = p.projectId.trim();
      if (id.isEmpty) continue;
      byInstr[id] = p;
      // wi_plan_* projectId == instructionId
      if (id.startsWith('wi_')) {
        byInstr.putIfAbsent(id, () => p);
      }
    }

    final byJob = <String, RemoteJobDoc>{};
    for (final j in jobs) {
      final key = _jobInstructionKey(j);
      if (key.isNotEmpty) byJob[key] = j;
    }

    return PlanExecutionIndex(
      projectsByInstructionId: byInstr,
      jobsByInstructionId: byJob,
      hintsByInstructionId: extraHints,
    );
  }

  static String _jobInstructionKey(RemoteJobDoc job) {
    final iid = job.instructionId.trim();
    if (iid.isNotEmpty) return iid;
    final title = job.title.trim();
    if (title.startsWith('wi_')) return title;
    return '';
  }

  PlanExecutionSnapshot snapshotFor(BusinessPlanDocument plan) {
    final iid = plan.stableInstructionId.trim();
    return PlanExecutionStatusResolver.resolve(
      plan,
      remoteProject: iid.isEmpty ? null : _projects[iid],
      remoteJob: iid.isEmpty ? null : _jobs[iid],
      hints: iid.isEmpty ? null : _hints[iid],
    );
  }

  Map<String, PlanExecutionSnapshot> snapshotsForPlans(
    List<BusinessPlanDocument> plans,
  ) {
    return {for (final p in plans) p.id: snapshotFor(p)};
  }

  Sotong24RemoteProject? projectFor(String instructionId) =>
      _projects[instructionId.trim()];
}
