import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/seen/sighting_storage.dart';

void main() {
  test('sighting photos use the Firebase storage bucket', () {
    final url = Uri.parse(sightingPhotoUrl('sightings/u/new.jpg'));
    expect(url.host, 'firebasestorage.googleapis.com');
    expect(url.path, contains(sightingStorageBucket));
    expect(url.path, contains('sightings%2Fu%2Fnew.jpg'));
    expect(sightingPhotoUrl(''), '');
  });

  test('storage rules keep review photos off guests and anonymous uploads', () {
    final rules = File('firebase/storage.rules').readAsStringSync();
    expect(rules, contains("sign_in_provider != 'anonymous'"));
    expect(rules, contains('firestore.get'));
    expect(rules, contains("status == 'public'"));
    expect(rules, contains('allow read: if owns(uid) || sightingPublic(file)'));
    expect(rules, contains('allow create, update: if owns(uid)'));
    expect(rules.contains('allow read: if true'), isFalse);
    expect(rules.contains("status == 'review'"), isFalse);
  });

  test('an in-review photo url carries the owner token', () {
    const token = '11111111-2222-4333-8444-555555555555';
    final url = Uri.parse(sightingPhotoUrl('sightings/u/1.jpg', token: token));
    expect(url.queryParameters['alt'], 'media');
    expect(url.queryParameters['token'], token);
    expect(sightingPhotoUrl('sightings/u/1.jpg'), isNot(contains('token=')));
    expect(sightingTokenOk(token), isTrue);
    expect(sightingTokenOk('short'), isFalse);
    expect(downloadTokenFromUrl(url.toString()), token);
  });
}
