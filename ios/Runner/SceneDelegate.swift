import Flutter
import UIKit

/// iPad can turn. iPhone stays portrait.
///
/// iPadOS 26 can turn the device without resizing the scene, which leaves
/// the portrait layout drawn sideways, so the iPad scene is asked to adopt
/// the device orientation.
class SceneDelegate: FlutterSceneDelegate {
  private static var observingOrientation = false

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if !Self.observingOrientation {
      UIDevice.current.beginGeneratingDeviceOrientationNotifications()
      Self.observingOrientation = true
    }
    NotificationCenter.default.removeObserver(
      self,
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(guideDeviceOrientationDidChange),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    guideAlignInterface(of: scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guideAlignInterface(of: scene)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    NotificationCenter.default.removeObserver(
      self,
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    super.sceneDidDisconnect(scene)
  }

  @available(iOS 27.0, *)
  override func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
    if UIDevice.current.userInterfaceIdiom == .pad {
      return .all
    }
    return .portrait
  }

  @objc private func guideDeviceOrientationDidChange() {
    for scene in UIApplication.shared.connectedScenes {
      guideAlignInterface(of: scene)
    }
  }

  private func guideAlignInterface(of scene: UIScene) {
    guard UIDevice.current.userInterfaceIdiom == .pad,
          let windowScene = scene as? UIWindowScene,
          let desired = guideDesiredInterfaceOrientation()
    else {
      return
    }
    if #available(iOS 16.0, *) {
      let current: UIInterfaceOrientation
      if #available(iOS 26.0, *) {
        current = windowScene.effectiveGeometry.interfaceOrientation
      } else {
        current = windowScene.interfaceOrientation
      }
      guard current != desired else { return }
      let preferences = UIWindowScene.GeometryPreferences.iOS()
      preferences.interfaceOrientations = UIInterfaceOrientationMask(rawValue: 1 << desired.rawValue)
      windowScene.requestGeometryUpdate(preferences) { error in
        NSLog("SceneDelegate geometry update failed: %@", error.localizedDescription)
      }
    }
  }

  /// Device landscape is the opposite interface orientation.
  private func guideDesiredInterfaceOrientation() -> UIInterfaceOrientation? {
    switch UIDevice.current.orientation {
    case .portrait:
      return .portrait
    case .portraitUpsideDown:
      return .portraitUpsideDown
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    default:
      return nil
    }
  }
}
