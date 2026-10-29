import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a sighting document does not store a download token', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    final start = rules.indexOf('match /sightings/{id}');
    expect(start, greaterThan(0));
    final block = rules.substring(start, rules.indexOf('allow delete:', start));
    expect(block.contains('photoToken'), isFalse);
    expect(
      block,
      contains("keys().hasOnly(['uid', 'latin', 'millis', 'status', 'photo'])"),
    );
    expect(block.contains('allow update: if false'), isTrue);
    expect(
      rules,
      contains(
        "allow read: if resource.data.status == 'public' ||\n"
        '        (request.auth != null && resource.data.uid == request.auth.uid)',
      ),
    );
  });

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
