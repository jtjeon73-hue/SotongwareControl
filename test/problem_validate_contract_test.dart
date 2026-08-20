import 'package:flutter_test/flutter_test.dart';
import 'package:sotong_ware_control/models/problem_validate_contract.dart';

void main() {
  test('STEP 2 공개 근거 계약은 생성기/검증기 고정값을 반영한다', () {
    expect(ProblemValidateContract.minPublicSourceUrls, 5);
    expect(ProblemValidateContract.minIndependentDomains, 3);
    expect(ProblemValidateContract.minProblemSignals, 10);
    expect(ProblemValidateContract.requiredProfiles, 2);
    expect(ProblemValidateContract.completionCriteria, contains('HTTPS 출처 5개'));
    expect(ProblemValidateContract.completionCriteria, contains('독립 도메인 3개'));
    expect(ProblemValidateContract.completionCriteria, contains('문제 신호 10건'));
    expect(ProblemValidateContract.completionCriteria, contains('미실시'));
  });
}
