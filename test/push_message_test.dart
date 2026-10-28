import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/shell/push_message.dart';

void main() {
  test('a dated list path and lists_custom/new open New in the book', () {
    expect(
      notificationPathOpensNewInBook('lists_custom/2026-10-27/list'),
      isTrue,
    );
    expect(notificationPathOpensNewInBook('/lists_custom/2026-10-27'), isTrue);
    expect(notificationPathOpensNewInBook('lists_custom/new'), isTrue);
    expect(
      notificationPathOpensNewInBook('lists_custom/new/2026-10-27'),
      isTrue,
    );
    expect(notificationPathOpensNewInBook('new'), isFalse);
    expect(
      notificationPathOpensNewInBook('lists_custom/2026-10-27/extra'),
      isFalse,
    );
  });

  test('the list id is the last path segment', () {
    expect(
      notificationListId('/curated_lists/deadly-poisonous'),
      'deadly-poisonous',
    );
    expect(notificationListId('deadly-poisonous'), 'deadly-poisonous');
    expect(notificationListId('///'), isNull);
  });

  test('list, plant, and browse payloads pick a destination', () {
    expect(
      pushDestination(
        PushNotice.fromData({
          'action': 'list',
          'path': 'lists_custom/2026-10-27/list',
        }),
      ),
      isA<PushNewInBook>(),
    );
    expect(
      pushDestination(
        PushNotice.fromData({
          'action': 'list',
          'path': 'curated_lists/us-state-mushrooms',
        }),
      ),
      isA<PushCuratedList>().having(
        (dest) => dest.id,
        'id',
        'us-state-mushrooms',
      ),
    );
    expect(
      pushDestination(PushNotice.fromData({'action': 'list', 'path': ''})),
      isA<PushNowhere>(),
    );
    expect(
      pushDestination(
        PushNotice.fromData({'action': 'plant', 'name': ' Boletus edulis '}),
      ),
      isA<PushSpecies>().having((dest) => dest.name, 'name', 'Boletus edulis'),
    );
    expect(
      pushDestination(PushNotice.fromData({'action': 'plant', 'name': '  '})),
      isA<PushNowhere>(),
    );
    final link = pushDestination(
      PushNotice.fromData({
        'action': 'browse',
        'uri': 'https://whatsthatmushroom.com',
      }),
    );
    expect(link, isA<PushLink>());
    expect((link as PushLink).uri.toString(), 'https://whatsthatmushroom.com');
    expect(
      pushDestination(
        PushNotice.fromData({'action': 'browse', 'uri': 'not a link'}),
      ),
      isA<PushNowhere>(),
    );
    expect(
      pushDestination(PushNotice.fromData({'action': 1})),
      isA<PushNowhere>(),
    );
  });

  test('the notice title prefers the notification payload', () {
    final notice = PushNotice.fromData({
      'title': 'data',
      'body': 'data body',
      'action': 'plant',
    }, title: 'banner');
    expect(notice.title, 'banner');
    expect(notice.body, 'data body');
    expect(
      PushNotice.fromData({'title': '  ', 'action': 'list'}).title,
      isNull,
    );
  });
}
