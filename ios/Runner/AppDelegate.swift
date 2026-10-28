import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
    // The plugin keeps a token it already stored. This covers the case
    // where it has not handed the token to Firebase yet.
    assignApnsToken(deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Hands the APNs token to Firebase with the profile's environment.
/// `FIRMessaging` is linked by firebase_messaging. The default app is
/// missing until Dart finishes `Firebase.initializeApp`.
private func assignApnsToken(_ deviceToken: Data) {
  guard let appClass = NSClassFromString("FIRApp") else { return }
  let defaultApp = NSSelectorFromString("defaultApp")
  guard let appMethod = class_getClassMethod(appClass, defaultApp),
        let configured = unsafeBitCast(
          method_getImplementation(appMethod),
          to: (@convention(c) (AnyClass, Selector) -> AnyObject?).self
        )(appClass, defaultApp)
  else {
    return
  }
  _ = configured
  guard let messagingClass = NSClassFromString("FIRMessaging") else { return }
  let shared = NSSelectorFromString("messaging")
  guard let messagingMethod = class_getClassMethod(messagingClass, shared),
        let messaging = unsafeBitCast(
          method_getImplementation(messagingMethod),
          to: (@convention(c) (AnyClass, Selector) -> NSObject?).self
        )(messagingClass, shared)
  else {
    return
  }
  messaging.setValue(deviceToken, forKey: "APNSToken")
}
