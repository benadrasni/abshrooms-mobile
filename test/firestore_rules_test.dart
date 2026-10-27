import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the owner can read photo quota and cannot grant a name', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    expect(rules, contains('match /photo_quota/{uid}'));
    expect(rules, contains('request.auth.uid == uid'));
    expect(rules, contains("sign_in_provider != 'anonymous'"));
    expect(
      rules,
      contains(
        'match /photo_quota/{uid} {\n'
        '      allow read: if request.auth != null\n'
        '        && request.auth.uid == uid\n'
        "        && request.auth.token.firebase.sign_in_provider != 'anonymous';\n"
        '      allow write: if false;\n'
        '    }',
      ),
    );
    expect(rules, contains('match /admob_rewards/{id}'));
    expect(
      rules,
      contains(
        'match /admob_rewards/{id} {\n'
        '      allow read, write: if false;\n'
        '    }',
      ),
    );
  });
}
