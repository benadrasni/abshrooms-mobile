import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:whats_that_mushroom/person/auth.dart';

/// RFC 4122 UUID version 5. [namespace] is a UUID string.
String uuidV5(String namespace, String name) {
  final hash = sha1.convert([..._uuidBytes(namespace), ...utf8.encode(name)]);
  final bytes = Uint8List.fromList(hash.bytes.sublist(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

List<int> _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

/// Same token the Cloud Functions derive for [uid]. Apple stores it as
/// appAccountToken and Play stores it as the obfuscated account id.
String storeAccountToken(String uid) {
  return uuidV5(
    '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
    'sk.ab.shrooms:$uid',
  );
}

/// Passed to the store at purchase so a renewal can find this account.
/// A guest has none: the receipt is claimed by the account they sign into.
String? storeApplicationUserName() {
  final uid = Auth.appUser?.uid;
  if (uid == null || uid.isEmpty) return null;
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return null;
  }
  return storeAccountToken(uid);
}
