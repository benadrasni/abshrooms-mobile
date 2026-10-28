import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whats_that_mushroom/copy.dart';
import 'package:whats_that_mushroom/purchase/billing.dart';
import 'package:whats_that_mushroom/shell/app_version.dart';
import 'package:whats_that_mushroom/shell/play_update.dart';
import 'package:whats_that_mushroom/shell/theme.dart';

/// Shared with the app builder so a block covers every route, not only the shell.
class VersionGateController extends ChangeNotifier {
  VersionGateController._();

  static final instance = VersionGateController._();

  VersionPrompt prompt = VersionPrompt.none;

  void apply(VersionPrompt next) {
    if (prompt == next) return;
    prompt = next;
    notifyListeners();
  }

  void resetForTest() {
    prompt = VersionPrompt.none;
    notifyListeners();
  }
}

Future<bool> _openExternal(String path) async {
  try {
    return await launchUrl(
      Uri.parse(path),
      mode: LaunchMode.externalApplication,
    );
  } catch (error) {
    debugPrint('store listing: $error');
    return false;
  }
}

/// Opens the store. A required Android update tries Play's immediate flow
/// first. A denial leaves the gate up. No Play offer falls through to the listing.
Future<void> openAppUpdate({required bool requiredUpdate}) async {
  if (requiredUpdate && Platform.isAndroid) {
    final outcome = await playImmediateUpdate();
    if (outcome != PlayUpdateOutcome.unavailable) return;
  }
  if (Platform.isAndroid) {
    if (await _openExternal(playMarket)) return;
    await _openExternal(playListing);
    return;
  }
  await _openExternal(appleListing);
}

class VersionRequiredPage extends StatefulWidget {
  final Copy copy;
  final Future<void> Function() onUpdate;

  const VersionRequiredPage({
    super.key,
    required this.copy,
    required this.onUpdate,
  });

  @override
  State<VersionRequiredPage> createState() => _VersionRequiredPageState();
}

class _VersionRequiredPageState extends State<VersionRequiredPage> {
  bool _opening = false;

  Future<void> _tap() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onUpdate();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    final copy = widget.copy;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              key: const Key('version-required'),
              children: [
                const Spacer(),
                Text.rich(
                  TextSpan(
                    style: GuideType.wordmark(colors),
                    children: [
                      TextSpan(text: copy.brandLead),
                      TextSpan(
                        text: copy.brandName,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          color: colors.madder,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  copy.versionRequired,
                  style: GuideType.section(colors),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('version-required-update'),
                  onPressed: _opening ? null : _tap,
                  child: Text(copy.offlineUpdate),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VersionBanner extends StatelessWidget {
  final Copy copy;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const VersionBanner({
    super.key,
    required this.copy,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GuideColors.of(context);
    return Material(
      key: const Key('version-banner'),
      color: colors.cream,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                copy.versionBanner,
                style: TextStyle(
                  fontFamily: GuideType.sans,
                  color: colors.ink,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              key: const Key('version-banner-update'),
              onPressed: onUpdate,
              child: Text(copy.offlineUpdate),
            ),
            IconButton(
              key: const Key('version-banner-dismiss'),
              tooltip: copy.close,
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
