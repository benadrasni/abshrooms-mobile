import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/settings.dart';

GuideScope _scope(
  CatalogRepository catalog,
  Notebook notebook,
  GuideSettings settings,
) {
  return GuideScope(
    catalog: catalog,
    notebook: notebook,
    settings: settings,
    reload: () async {},
    selectTab: (_) {},
    child: const SizedBox(),
  );
}

void main() {
  test('notifies when catalog, notebook, or settings change in place', () {
    final catalog = CatalogRepository();
    final notebook = Notebook();
    final settings = GuideSettings();
    final before = _scope(catalog, notebook, settings);

    catalog.loading = true;
    final loading = _scope(catalog, notebook, settings);
    expect(loading.updateShouldNotify(before), isTrue);

    notebook.epoch += 1;
    final noted = _scope(catalog, notebook, settings);
    expect(noted.updateShouldNotify(loading), isTrue);

    settings.language = 'sk';
    final slovak = _scope(catalog, notebook, settings);
    expect(slovak.updateShouldNotify(noted), isTrue);

    final same = _scope(catalog, notebook, settings);
    expect(same.updateShouldNotify(slovak), isFalse);
  });
}
