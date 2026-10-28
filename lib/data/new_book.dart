import 'package:whats_that_mushroom/data/models.dart';

/// Newest days kept whole while the species count stays in this band.
/// A day is shortened only when leaving it whole would pass the maximum
/// before the minimum is met. The plants app uses the same band.
const newBookMin = 15;
const newBookMax = 25;

/// Species added on one calendar day, newest day first.
class NewDay {
  final String dateKey;
  final DateTime date;
  final List<Species> species;

  const NewDay({
    required this.dateKey,
    required this.date,
    required this.species,
  });
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Today or yesterday, matched on the calendar day. Null asks for a full date.
String? newDayWord(
  DateTime date,
  DateTime now, {
  required String today,
  required String yesterday,
}) {
  if (_sameDay(date, now)) return today;
  final previous = DateTime(now.year, now.month, now.day - 1);
  if (_sameDay(date, previous)) return yesterday;
  return null;
}

/// The last [newBookMin] to [newBookMax] species, grouped by the day they
/// were added. Within a day the higher catalog id comes first.
List<NewDay> newInBook(
  List<Species> species, {
  int minCount = newBookMin,
  int maxCount = newBookMax,
}) {
  final byDate = <String, List<Species>>{};
  for (final item in species) {
    final key = item.added.trim();
    if (addedDate(key) == null) continue;
    byDate.putIfAbsent(key, () => []).add(item);
  }
  final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
  final days = <NewDay>[
    for (final key in keys)
      NewDay(
        dateKey: key,
        date: addedDate(key)!,
        species: [...byDate[key]!]
          ..sort((a, b) {
            final byId = b.id.compareTo(a.id);
            if (byId != 0) return byId;
            return a.name.compareTo(b.name);
          }),
      ),
  ];
  return selectNewDays(days, minCount: minCount, maxCount: maxCount);
}

/// Whole newest days, then a shortened day only to reach the band.
List<NewDay> selectNewDays(
  List<NewDay> newestFirst, {
  int minCount = newBookMin,
  int maxCount = newBookMax,
}) {
  final chosen = <NewDay>[];
  var count = 0;
  for (final day in newestFirst) {
    final next = count + day.species.length;
    if (count >= minCount && next > maxCount) break;
    if (next <= maxCount) {
      chosen.add(day);
      count = next;
      continue;
    }
    final room = maxCount - count;
    final kept = day.species.length <= room
        ? day.species
        : day.species.sublist(0, room);
    chosen.add(NewDay(dateKey: day.dateKey, date: day.date, species: kept));
    break;
  }
  return chosen;
}

int newBookCount(List<NewDay> days) {
  var count = 0;
  for (final day in days) {
    count += day.species.length;
  }
  return count;
}
