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

  test('the owner can store or clear only the push token', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    expect(
      rules,
      contains(
        'match /users/{uid} {\n'
        '      allow read: if request.auth != null\n'
        '        && request.auth.uid == uid\n'
        "        && request.auth.token.firebase.sign_in_provider != 'anonymous';\n"
        '      allow create: if request.auth != null\n'
        '        && request.auth.uid == uid\n'
        "        && request.auth.token.firebase.sign_in_provider != 'anonymous'\n"
        "        && request.resource.data.keys().hasOnly(['token'])\n"
        '        && request.resource.data.token is string\n'
        '        && request.resource.data.token.size() > 0\n'
        '        && request.resource.data.token.size() < 4096;\n'
        '      allow update: if request.auth != null\n'
        '        && request.auth.uid == uid\n'
        "        && request.auth.token.firebase.sign_in_provider != 'anonymous'\n"
        '        && request.resource.data.diff(resource.data).affectedKeys().hasOnly([\'token\'])\n'
        '        && (\n'
        '          !request.resource.data.keys().hasAll([\'token\'])\n'
        '          || (\n'
        '            request.resource.data.token is string\n'
        '            && request.resource.data.token.size() > 0\n'
        '            && request.resource.data.token.size() < 4096\n'
        '          )\n'
        '        );\n'
        '      allow delete: if false;\n'
        '    }',
      ),
    );
  });
}
