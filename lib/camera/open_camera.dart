import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:whats_that_mushroom/camera/camera_page.dart';
import 'package:whats_that_mushroom/shell/guide_analytics.dart';
import 'package:whats_that_mushroom/shell/scope.dart';

/// The connectivity read. Tests set this so a tap does not ask the device.
@visibleForTesting
Future<List<ConnectivityResult>> Function()? debugCameraConnectivity;

/// Name it from a photo. With no connection, the same dialog as the plants
/// app stays on this page and the camera does not open.
Future<void> openGuideCamera(BuildContext context) async {
  if (!await _reachable(context)) return;
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(guideRoute<void>(guideScreenCamera, (_) => const CameraPage()));
}

Future<bool> _reachable(BuildContext context) async {
  final read = debugCameraConnectivity ?? Connectivity().checkConnectivity;
  final result = await read();
  if (!context.mounted) return false;
  if (!result.contains(ConnectivityResult.none)) return true;
  final copy = GuideScope.of(context).copy;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(copy.noConnectionTitle),
        content: Text(copy.noConnectionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(copy.close),
          ),
        ],
      );
    },
  );
  return false;
}
