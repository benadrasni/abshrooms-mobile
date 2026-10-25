import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/camera/outside_page.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/data/models.dart';
import 'package:whats_that_mushroom/data/notebook.dart';
import 'package:whats_that_mushroom/data/text.dart';
import 'package:whats_that_mushroom/search/search_page.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';
import 'package:whats_that_mushroom/species/species_page.dart';

class SeenPage extends StatelessWidget {
  const SeenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    final copy = scope.copy;
    final colors = GuideColors.of(context);
    final finds = scope.notebook.finds;
    if (finds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            copy.seenEmpty,
            style: GuideType.body(colors),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      itemCount: finds.length + 1,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.rule),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(copy.seen, style: GuideType.wordmark(colors)),
          );
        }
        return _tile(context, finds[index - 1]);
      },
    );
  }
}

Future<void> _open(
  BuildContext context,
  FindRecord find,
  Species? species,
) async {
  if (species != null) {
    openSpecies(context, species.name);
    return;
  }
  final outside = find.outsideName?.trim() ?? '';
  if (outside.isEmpty) return;
  final result = await Navigator.of(context).push<OutsideResult>(
    MaterialPageRoute(
      builder: (_) => OutsidePage(
        recordId: find.id,
        onSearch: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchPage()));
        },
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  final message = result.message;
  if (message != null && message.isNotEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
  final latin = result.species;
  if (latin != null) openSpecies(context, latin);
}

Widget _tile(BuildContext context, FindRecord find) {
  final scope = GuideScope.of(context);
  final copy = scope.copy;
  final colors = GuideColors.of(context);
  final catalog = scope.catalog.data;
  final species = find.latin == null ? null : catalog?.byName(find.latin!);
  final title = species == null
      ? (find.outsideName ?? find.latin ?? '')
      : catalog!.heading(species);
  final spoken = species != null && title != species.name;
  return InkWell(
    onTap: () => _open(context, find, species),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: _photo(find.photoPath, colors),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: spoken
                      ? GuideType.spoken(colors, size: 18)
                      : GuideType.latin(colors, size: 18),
                ),
                if (species != null && spoken)
                  Text(species.name, style: GuideType.latin(colors, size: 14)),
                Text(
                  _when(find.millis, copy),
                  style: GuideType.muted(colors, size: 13),
                ),
                Text(
                  find.confirmed ? copy.confirmed : copy.unconfirmed,
                  style: GuideType.muted(colors, size: 13),
                ),
              ],
            ),
          ),
          if (!find.confirmed)
            IconButton(
              onPressed: () => scope.notebook.confirm(find.id),
              icon: const Icon(Icons.check),
              tooltip: copy.confirm,
            ),
          IconButton(
            onPressed: () => _delete(context, find.id),
            icon: const Icon(Icons.delete_outline),
            tooltip: copy.delete,
          ),
        ],
      ),
    ),
  );
}

Widget _photo(String? path, GuideColors colors) {
  if (path == null || path.isEmpty) {
    return ColoredBox(color: colors.paper2);
  }
  final file = File(path);
  if (!file.existsSync()) return ColoredBox(color: colors.paper2);
  return Image.file(file, fit: BoxFit.cover);
}

Future<void> _delete(BuildContext context, String id) async {
  final copy = GuideScope.of(context).copy;
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        content: Text(copy.deleteAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.delete),
          ),
        ],
      );
    },
  );
  if (yes == true && context.mounted) {
    await GuideScope.of(context).notebook.remove(id);
  }
}

String _when(int millis, Copy copy) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final month = (copy.sk ? monthsSk : monthsEn)[date.month - 1];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  if (copy.sk) return '${date.day}. $month ${date.year}, $hour:$minute';
  return '$month ${date.day}, ${date.year}, $hour:$minute';
}
