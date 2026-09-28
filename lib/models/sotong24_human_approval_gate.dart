/// Mandatory human-approval gates: project `approvalMode=auto` must not hide
/// approve/revise actions when the stage itself requires explicit user approval.
class Sotong24HumanApprovalGate {
  Sotong24HumanApprovalGate._();

  /// Ebook STEP15/17 (+ sales_metadata alias) and site publish/review gates.
  /// Keep in sync with workerless monitoring expectations.
  static bool isMandatory(String stageId) {
    final id = stageId.trim();
    return id == 'final_user_approval' ||
        id == 'package_user_review' ||
        id == 'sales_metadata' ||
        id == 'site_user_review' ||
        id == 'site_publish';
  }
}
