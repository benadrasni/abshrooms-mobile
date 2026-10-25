import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/curated_lists.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/repository.dart';
import 'package:whats_that_mushroom/shell/settings.dart';

class GuideScope extends InheritedWidget {
  final CatalogRepository catalog;
  final Notebook notebook;
  final GuideSettings settings;
  final Future<void> Function() reload;
  final Future<void> Function() reloadLists;
  final void Function(int index) selectTab;

  /// Snapshots taken when this widget is built. The repository, notebook,
  /// and settings objects are mutated in place, so comparing those fields
  /// on the old and new widgets always sees the same values.
  final Catalog? catalogData;
  final bool catalogLoading;
  final Object? catalogError;
  final CuratedListsSnapshot curatedLists;
  final int notebookEpoch;
  final String language;
  final ThemeMode themeMode;

  GuideScope({
    super.key,
    required this.catalog,
    required this.notebook,
    required this.settings,
    required this.reload,
    required this.selectTab,
    required super.child,
    Future<void> Function()? reloadLists,
  }) : reloadLists = reloadLists ?? _ignore,
       catalogData = catalog.data,
       catalogLoading = catalog.loading,
       catalogError = catalog.error,
       curatedLists = catalog.curatedLists,
       notebookEpoch = notebook.epoch,
       language = settings.language,
       themeMode = settings.themeMode;

  static Future<void> _ignore() async {}

  static GuideScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GuideScope>();
    assert(scope != null, 'GuideScope is missing');
    return scope!;
  }

  Copy get copy => Copy(settings.language);

  @override
  bool updateShouldNotify(GuideScope oldWidget) {
    return catalogData != oldWidget.catalogData ||
        catalogLoading != oldWidget.catalogLoading ||
        catalogError != oldWidget.catalogError ||
        curatedLists != oldWidget.curatedLists ||
        notebookEpoch != oldWidget.notebookEpoch ||
        language != oldWidget.language ||
        themeMode != oldWidget.themeMode;
  }
}
