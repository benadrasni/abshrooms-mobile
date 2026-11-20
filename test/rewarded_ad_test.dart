import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/ads/rewarded_ad.dart';
import 'package:whats_that_mushroom/person/auth.dart';

void main() {
  tearDown(() {
    Auth.appUser = null;
  });

  test('a rewarded view has no account to credit when signed out', () {
    Auth.appUser = null;
    expect(rewardedAdAccountId(), isNull);
  });
}
