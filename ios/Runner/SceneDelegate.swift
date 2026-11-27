import Flutter
import UIKit

/// iPad and iPhone Duo can turn. Every other iPhone stays portrait.
///
/// iPadOS 26 can turn the device without resizing the scene, which leaves
/// the portrait layout drawn sideways, so the iPad scene is asked to adopt
/// the device orientation. Duo resizes with the fold. That iPad sync would
/// fight the fold, so it stays on iPad only.
class SceneDelegate: FlutterSceneDelegate {
  private static var observingOrientation = false

  /// Stays true once this device has shown a vertical status column or a
  /// Duo display size. Inner portrait reports no vertical bar, and the mask
  /// must not flip back to portrait-only while that display is showing.
  private static var folds = false

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
    if Self.guideFolds(windowScene) {
      return [.portrait, .landscapeLeft, .landscapeRight]
    }
    return .portrait
  }

  /// Orientation capability only. Layout follows the safe area, not this.
  @available(iOS 27.0, *)
  private static func guideFolds(_ windowScene: UIWindowScene) -> Bool {
    if folds { return true }
    if #available(iOS 27.1, *) {
      if windowScene.traitCollection.verticalBarEdge != .unspecified {
        folds = true
        return true
      }
    }
    // UIScreen.main stays the outer display when the window has moved to
    // the inner one. Either size is enough to know this hardware folds.
    if guideScreenFolds(UIScreen.main.bounds.size) ||
        guideScreenFolds(windowScene.screen.bounds.size) {
      folds = true
      return true
    }
    return false
  }

  /// Outer display is about 466×678. Inner display is about 669×951.
  private static func guideScreenFolds(_ size: CGSize) -> Bool {
    let short = min(size.width, size.height)
    let long = max(size.width, size.height)
    let outer = short >= 450 && short <= 500 && long >= 640 && long <= 730
    let inner = short >= 640 && short <= 720 && long >= 900 && long <= 1000
    return outer || inner
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
