/// A push payload, without Firebase. The keys match the plants app so one
/// sender shape opens a list, a species, or a link.
const pushAction = 'action';
const pushActionList = 'list';
const pushActionPlant = 'plant';
const pushActionBrowse = 'browse';
const pushPath = 'path';
const pushUri = 'uri';
const pushName = 'name';

/// Shared preferences key and the `users/{uid}` field.
const pushTokenKey = 'token';

final _datedListPath = RegExp(r'^lists_custom/\d{4}-\d{2}-\d{2}(/list)?$');

/// A new-mushrooms notification opens New in the book.
///
/// The plants sender uses `lists_custom/DATE/list`. The book also keeps
/// `lists_custom/new` and `lists_custom/new/DATE`.
bool notificationPathOpensNewInBook(String path) {
  var value = path.trim();
  if (value.startsWith('/')) value = value.substring(1);
  if (value == 'lists_custom/new' || value.startsWith('lists_custom/new/')) {
    return true;
  }
  return _datedListPath.hasMatch(value);
}

/// The curated-list id is the last segment of the path. A new-in-book path
/// is not a list id.
String? notificationListId(String path) {
  var value = path.trim();
  if (value.startsWith('/')) value = value.substring(1);
  final parts = value.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  return parts.last;
}

String pushField(Map<String, dynamic> data, String key) {
  final value = data[key];
  return value is String ? value : '';
}

String? pushOptionalText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class PushNotice {
  final String action;
  final String path;
  final String uri;
  final String name;
  final String? title;
  final String? body;

  const PushNotice({
    required this.action,
    required this.path,
    required this.uri,
    required this.name,
    this.title,
    this.body,
  });

  factory PushNotice.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    return PushNotice(
      action: pushField(data, pushAction),
      path: pushField(data, pushPath),
      uri: pushField(data, pushUri),
      name: pushField(data, pushName),
      title: title ?? pushOptionalText(data['title']),
      body: body ?? pushOptionalText(data['body']),
    );
  }
}

/// Where a tap goes. An unknown action, an empty name, or a missing list
/// id opens nothing.
sealed class PushDestination {
  const PushDestination();
}

class PushNowhere extends PushDestination {
  const PushNowhere();
}

class PushNewInBook extends PushDestination {
  const PushNewInBook();
}

class PushCuratedList extends PushDestination {
  final String id;

  const PushCuratedList(this.id);
}

class PushSpecies extends PushDestination {
  final String name;

  const PushSpecies(this.name);
}

class PushLink extends PushDestination {
  final Uri uri;

  const PushLink(this.uri);
}

PushDestination pushDestination(PushNotice notice) {
  switch (notice.action) {
    case pushActionList:
      if (notificationPathOpensNewInBook(notice.path)) {
        return const PushNewInBook();
      }
      final id = notificationListId(notice.path);
      if (id == null) return const PushNowhere();
      return PushCuratedList(id);
    case pushActionPlant:
      final name = notice.name.trim();
      if (name.isEmpty) return const PushNowhere();
      return PushSpecies(name);
    case pushActionBrowse:
      final uri = Uri.tryParse(notice.uri.trim());
      if (uri == null || !uri.hasScheme) return const PushNowhere();
      return PushLink(uri);
    default:
      return const PushNowhere();
  }
}
