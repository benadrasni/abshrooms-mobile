import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_that_mushroom/person/auth.dart';

/// Photo names left on this phone.
///
/// A guest has one name. A signed-in account has five each UTC month, and a
/// rewarded ad can add five more. Field Guide does not spend a name.
/// [identifyMushroom] counts the name before it calls Plant.id. This meter
/// mirrors that count between calls.
class NameMonth {
  final String month;
  final int namesUsed;
  final int adGrants;

  const NameMonth({this.month = '', this.namesUsed = 0, this.adGrants = 0});

  static const empty = NameMonth();

  NameMonth copyWith({String? month, int? namesUsed, int? adGrants}) {
    return NameMonth(
      month: month ?? this.month,
      namesUsed: namesUsed ?? this.namesUsed,
      adGrants: adGrants ?? this.adGrants,
    );
  }
}

class NameAllowance {
  final bool unlimited;
  final bool guest;
  final int namesLeft;
  final int extraUsed;
  final int dotCount;
  final int filledDots;

  const NameAllowance.unlimited()
    : unlimited = true,
      guest = false,
      namesLeft = 0,
      extraUsed = 0,
      dotCount = 0,
      filledDots = 0;

  const NameAllowance.guest({required this.namesLeft})
    : unlimited = false,
      guest = true,
      extraUsed = 0,
      dotCount = 1,
      filledDots = namesLeft > 0 ? 1 : 0;

  const NameAllowance.month({
    required this.namesLeft,
    required this.extraUsed,
    required this.filledDots,
  }) : unlimited = false,
       guest = false,
       dotCount = 5;
}

/// Five included names, plus ad grants, minus names already charged.
int namesRemaining(int used, int grants) {
  final spent = used < 0 ? 0 : used;
  final extra = grants < 0 ? 0 : (grants > 5 ? 5 : grants);
  final left = 5 + extra - spent;
  return left < 0 ? 0 : left;
}

/// A rewarded ad is offered when a signed-in account has used its names and
/// the month still has room for one. A guest signs in instead.
bool nameOffersAd(NameAllowance allowance) {
  return !allowance.unlimited &&
      !allowance.guest &&
      allowance.namesLeft <= 0 &&
      allowance.extraUsed < 5;
}

bool nameMonthExhausted(NameAllowance allowance) {
  return !allowance.unlimited &&
      !allowance.guest &&
      allowance.namesLeft <= 0 &&
      allowance.extraUsed >= 5;
}

/// The guest's one name is gone. The next photo asks for an account.
bool nameNeedsSignIn(NameAllowance allowance) {
  return allowance.guest && allowance.namesLeft <= 0;
}

/// A signed-in account. A guest, and a test with no Firebase app, is not one.
bool photoAccountSignedIn() {
  if (Firebase.apps.isEmpty) return false;
  return Auth.appUser != null;
}

/// The signed-in month on Person. Included names fill first, then ad grants.
/// The bar is ten parts: five included and five from ads.
class MonthNames {
  final int includedUsed;
  final int extraUsed;
  final int adsLeft;
  final DateTime resetsOn;

  const MonthNames({
    required this.includedUsed,
    required this.extraUsed,
    required this.adsLeft,
    required this.resetsOn,
  });

  int get rest {
    final value = 10 - includedUsed - extraUsed;
    return value < 0 ? 0 : value;
  }

  /// [count] from another UTC month counts as a fresh month.
  static MonthNames of(NameMonth count, DateTime now) {
    final current = count.month == quotaMonth(now) ? count : const NameMonth();
    final included = _clampCount(current.namesUsed, 5);
    final extra = _clampCount(current.adGrants, 5);
    final utc = now.toUtc();
    return MonthNames(
      includedUsed: included,
      extraUsed: extra,
      adsLeft: 5 - extra,
      resetsOn: DateTime.utc(utc.year, utc.month + 1, 1),
    );
  }
}

int _clampCount(int value, int max) {
  if (value < 0) return 0;
  if (value > max) return max;
  return value;
}

/// UTC `yyyy-mm`.
String quotaMonth(DateTime now) {
  final utc = now.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  return '${utc.year}-$month';
}

/// Reads [NameMonth] from a `photo_quota` Firestore document snapshot.
NameMonth nameMonthFromQuota(Object? raw, DateTime now) {
  final currentMonth = quotaMonth(now);
  if (raw is! Map) return NameMonth(month: currentMonth);
  final month = raw['month']?.toString() ?? currentMonth;
  if (month != currentMonth) return NameMonth(month: currentMonth);
  final used = raw['namesUsed'];
  final grants = raw['adGrants'];
  return NameMonth(
    month: currentMonth,
    namesUsed: used is num && used >= 0 ? used.toInt() : 0,
    adGrants: grants is num && grants >= 0 ? grants.toInt() : 0,
  );
}

class Names {
  static const _key = 'photo_names';
  static const _guestKey = 'guest_free_used';
  static NameMonth _count = NameMonth.empty;
  static var _guestFree = true;
  static var holdForTest = false;
  static var _epoch = 0;
  static var _serverApplied = false;
  static var lastCharged = false;
  static final revision = ValueNotifier<int>(0);

  static NameMonth get count => _count;

  static NameAllowance allowance({
    required bool fieldGuide,
    bool signedIn = true,
    DateTime? now,
  }) {
    if (fieldGuide) return const NameAllowance.unlimited();
    if (!signedIn) {
      return NameAllowance.guest(namesLeft: _guestFree ? 1 : 0);
    }
    final fresh = _for(now ?? DateTime.now());
    final left = namesRemaining(fresh.namesUsed, fresh.adGrants);
    final grants = fresh.adGrants < 0
        ? 0
        : (fresh.adGrants > 5 ? 5 : fresh.adGrants);
    return NameAllowance.month(
      namesLeft: left,
      extraUsed: grants,
      filledDots: left > 5 ? 5 : left,
    );
  }

  static Future<void> restore() async {
    if (holdForTest) return;
    final epoch = _epoch;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('names: $error');
      return;
    }
    if (epoch != _epoch || holdForTest) return;
    final wasFree = _guestFree;
    _guestFree = !(prefs.getBool(_guestKey) ?? false);
    final parsed = _parse(prefs.getString(_key));
    final month = quotaMonth(DateTime.now());
    final next = parsed.month == month ? parsed : NameMonth(month: month);
    if (next.month == _count.month &&
        next.namesUsed == _count.namesUsed &&
        next.adGrants == _count.adGrants) {
      if (wasFree != _guestFree) revision.value++;
      return;
    }
    _count = next;
    revision.value++;
    if (parsed.month.isNotEmpty && parsed.month != month) {
      await _save(prefs);
    }
  }

  static Future<void> spend({bool signedIn = true, DateTime? now}) async {
    _epoch++;
    if (!signedIn) {
      if (!_guestFree) return;
      _guestFree = false;
      revision.value++;
      unawaited(_saveGuest());
      return;
    }
    final clock = now ?? DateTime.now();
    final fresh = _for(clock);
    _count = fresh.copyWith(namesUsed: fresh.namesUsed + 1);
    revision.value++;
    unawaited(_save());
  }

  /// The function already counted this photo. [lastCharged] says whether the
  /// name was kept. A later local [spend] would count it twice.
  static void applyServer({
    required bool signedIn,
    required bool charged,
    required bool anonymousFreeUsed,
    int? namesUsed,
    int? adGrants,
    bool fromPhoto = true,
  }) {
    _epoch++;
    if (fromPhoto) _serverApplied = true;
    lastCharged = charged;
    if (!signedIn || anonymousFreeUsed) {
      if (anonymousFreeUsed || charged) _guestFree = false;
      revision.value++;
      unawaited(_saveGuest());
      return;
    }
    if (namesUsed == null || adGrants == null) return;
    _count = NameMonth(
      month: quotaMonth(DateTime.now()),
      namesUsed: namesUsed < 0 ? 0 : namesUsed,
      adGrants: adGrants < 0 ? 0 : adGrants,
    );
    revision.value++;
    unawaited(_save());
  }

  static bool takeServerApply() {
    final applied = _serverApplied;
    _serverApplied = false;
    return applied;
  }

  /// One more name after a rewarded ad. False when the month already has five.
  static Future<bool> grant({DateTime? now}) async {
    _epoch++;
    final clock = now ?? DateTime.now();
    final fresh = _for(clock);
    if (fresh.adGrants >= 5) return false;
    _count = fresh.copyWith(adGrants: fresh.adGrants + 1);
    revision.value++;
    unawaited(_save());
    return true;
  }

  static void setForTest({int used = 0, int grants = 0, DateTime? now}) {
    holdForTest = true;
    _count = NameMonth(
      month: quotaMonth(now ?? DateTime.now()),
      namesUsed: used,
      adGrants: grants,
    );
    revision.value++;
  }

  static void resetForTest() {
    holdForTest = false;
    _count = NameMonth.empty;
    _guestFree = true;
    _serverApplied = false;
    lastCharged = false;
  }

  static NameMonth _for(DateTime now) {
    final month = quotaMonth(now);
    if (_count.month != month) return NameMonth(month: month);
    return _count;
  }

  static NameMonth _parse(String? raw) {
    if (raw == null) return NameMonth.empty;
    final parts = raw.split(':');
    if (parts.length != 3) return NameMonth.empty;
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(parts[0])) return NameMonth.empty;
    final used = int.tryParse(parts[1]);
    final grants = int.tryParse(parts[2]);
    if (used == null || grants == null || used < 0 || grants < 0) {
      return NameMonth.empty;
    }
    return NameMonth(month: parts[0], namesUsed: used, adGrants: grants);
  }

  static Future<void> _save([SharedPreferences? prefs]) async {
    if (holdForTest) return;
    try {
      final store = prefs ?? await SharedPreferences.getInstance();
      final line = '${_count.month}:${_count.namesUsed}:${_count.adGrants}';
      await store.setString(_key, line);
    } catch (error) {
      debugPrint('names: $error');
    }
  }

  static Future<void> _saveGuest() async {
    if (holdForTest) return;
    try {
      final store = await SharedPreferences.getInstance();
      await store.setBool(_guestKey, !_guestFree);
    } catch (error) {
      debugPrint('names: $error');
    }
  }
}
