import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/config/release_info.dart';

void main() {
  test('release label contains the version and update date', () {
    expect(ReleaseInfo.label, contains(ReleaseInfo.version));
    expect(ReleaseInfo.label, contains(ReleaseInfo.updatedAt));
  });
}
