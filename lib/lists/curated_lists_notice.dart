import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/shell/scope.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

/// The shared read failed. Find and Book both show this and retry the same snapshot.
class CuratedListsNotice extends StatelessWidget {
  const CuratedListsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GuideScope.of(context);
    if (!scope.curatedLists.failed) return const SizedBox.shrink();
    final colors = GuideColors.of(context);
    final copy = scope.copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.listsFailed,
            style: TextStyle(
              fontFamily: GuideType.sans,
              fontSize: 14,
              height: 1.3,
              color: colors.ink2,
            ),
          ),
          TextButton(onPressed: scope.reloadLists, child: Text(copy.retry)),
        ],
      ),
    );
  }
}
