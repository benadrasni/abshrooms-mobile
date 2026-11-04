import 'package:flutter/widgets.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';

/// Tab actions a pushed page can see. The shell writes [index] and
/// [openPerson]. The landscape rail reads them.
class GuideTabs {
  /// The shell tab under any pushed page.
  static int index = 0;

  /// Opens Person. The shell sets this; a rail on a pushed page calls it.
  static void Function(BuildContext context)? openPerson;
}

/// Opens a shell tab and drops every page pushed over it.
void guideRailSelect(BuildContext context, int index) {
  GuideScope.of(context).selectTab(index);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Person in the landscape rail. A page already on Person stays there.
void guideRailPerson(BuildContext context) {
  final open = GuideTabs.openPerson;
  if (open == null) return;
  final navigator = Navigator.of(context);
  if (ModalRoute.of(context)?.settings.name == guideScreenPerson) return;
  var found = false;
  navigator.popUntil((route) {
    if (route.settings.name == guideScreenPerson) found = true;
    return route.isFirst || found;
  });
  if (!found) open(navigator.context);
}
