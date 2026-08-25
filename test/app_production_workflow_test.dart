import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/data/sotong24_workflows.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/services/apk_download_service.dart';

void main() {
  test('app work instruction uses canonical 18 production stages', () {
    final workflow = Sotong24WorkflowCatalog.forProduct(ArtifactType.app);
    expect(workflow.totalStages, 18);
    expect(workflow.stages.map((stage) => stage.id), [
      'app_idea',
      'app_problem_validate',
      'app_market_analysis',
      'app_requirements',
      'app_project_setup',
      'app_ux_flow',
      'app_design_system',
      'app_data_state',
      'app_core_implementation_1',
      'app_core_implementation_2',
      'app_integration_errors',
      'app_code_quality',
      'app_automated_tests',
      'app_android_release',
      'app_device_review_prep',
      'app_user_review_package',
      'app_revision_quality',
      'app_production_complete',
    ]);
    expect(workflow.stages[4].name, '프로젝트 셋업');
    expect(workflow.stages[13].name, 'Android Release Build');
    expect(workflow.stages.last.name, 'Production Complete');
    expect(workflow.summary, contains('출시 전 검토'));
  });

  test('APK download names preserve revision and block unsafe characters', () {
    expect(buildApkDownloadFileName('Farm Log AI', 2), 'Farm_Log_AI_r2.apk');
    expect(buildApkDownloadFileName('../나의:앱', 1), '나의_앱_r1.apk');
  });
}
