import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/artifact_type.dart';
import 'package:sotong_ware_control/services/dev_work_doc_paths.dart';

void main() {
  test('artifactFolder maps artifact ids to DevWorkDoc folders', () {
    expect(DevWorkDocPaths.artifactFolder('ebook'), 'Ebook');
    expect(DevWorkDocPaths.artifactFolder('app'), 'App');
    expect(DevWorkDocPaths.artifactFolder('contents'), 'Contents');
    expect(DevWorkDocPaths.artifactFolder('site'), 'Site');
    expect(DevWorkDocPaths.artifactFolder('promo_site'), 'PromoSite');
  });

  test('activeRelative uses sanitized instruction id', () {
    expect(
      DevWorkDocPaths.activeRelative('ebook', 'wi_plan/rural'),
      'Ebook/Active/WI_wi_planrural.json',
    );
  });

  test('versionRelative includes version suffix', () {
    expect(
      DevWorkDocPaths.versionRelative('app', 'wi_demo', 2),
      'App/Versions/wi_demo/WI_wi_demo_v2.json',
    );
  });

  test('ArtifactType.normalize maps legacy deliverables', () {
    expect(ArtifactType.normalize('web_marketing'), ArtifactType.promoSite);
    expect(ArtifactType.normalize('youtube_shorts'), ArtifactType.contents);
    expect(ArtifactType.normalize('industrial_automation'), ArtifactType.site);
    expect(ArtifactType.primaryTrackId(ArtifactType.ebook), 'ebook_dev');
  });
}
