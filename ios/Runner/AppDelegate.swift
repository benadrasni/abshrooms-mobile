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

    let fold = FlutterMethodChannel(
      name: "sk.ab.shrooms/fold",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    guideFoldChannel = fold
    fold.setMethodCallHandler { call, result in
      guard call.method == "regions" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guideAttachFoldProbe()
      result(guideFoldRegions())
    }
    DispatchQueue.main.async {
      guideAttachFoldProbe()
    }
  }
}

private var guideFoldChannel: FlutterMethodChannel?
private var guideFoldProbeView: UIView?

/// True while the hinge is partly open. UIKit's division rect is empty in
/// this Flutter window, so the layout uses a centered band only then.
private var guideHingePartial = false

/// Active division of a partly folded iPhone Duo, in window points.
/// Flat and closed poses return an empty list. The camera occlusion is not
/// the hinge, so it is logged and then left out of the layout rect.
private func guideFoldRegions() -> [[String: Double]] {
  guard #available(iOS 27.1, *) else { return [] }
  return guideFoldSnapshot().regions
}

private struct GuideFoldSnapshot {
  var regions: [[String: Double]] = []
  var note: String = ""
}

@available(iOS 27.1, *)
private func guideFoldSnapshot() -> GuideFoldSnapshot {
  var snapshot = GuideFoldSnapshot()
  var notes: [String] = []
  for view in guideFoldViews() {
    let division = view.reservedRegions(kind: .division, options: [.includeInactive])
    let occlusion = view.reservedRegions(kind: .occlusion, options: [.includeInactive])
    var divisionNote = ""
    for region in division {
      let frame = region.frame
      if !divisionNote.isEmpty { divisionNote += "|" }
      let state = region.isActive ? "on" : "off"
      divisionNote += "\(state) \(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height))"
      let wide = frame.width >= 1 && frame.height >= 1
      if snapshot.regions.isEmpty && region.isActive && wide {
        let moved = view.convert(frame, to: view.window)
        let entry: [String: Double] = [
          "x": Double(moved.origin.x),
          "y": Double(moved.origin.y),
          "w": Double(moved.size.width),
          "h": Double(moved.size.height),
        ]
        snapshot.regions = [entry]
      }
    }
    let name = String(describing: type(of: view))
    notes.append(
      "\(name) \(Int(view.bounds.width))x\(Int(view.bounds.height)) division=[\(divisionNote)] occlusion=\(occlusion.count)"
    )
  }
  if snapshot.regions.isEmpty && guideHingePartial, let window = guideFoldViews().first {
    // The division rect already includes its margins when UIKit sends one.
    // This stand-in is the centered crease, 40 points, used only when the
    // hinge is partly open and that rect is missing.
    let bounds = window.bounds
    let span = 40.0
    if bounds.height >= bounds.width {
      let entry: [String: Double] = [
        "x": Double((bounds.width - span) / 2),
        "y": 0,
        "w": span,
        "h": Double(bounds.height),
      ]
      snapshot.regions = [entry]
      notes.append("fallback")
    }
  }
  snapshot.note = notes.joined(separator: " ")
  return snapshot
}

@available(iOS 27.1, *)
private func guideFoldViews() -> [UIView] {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  var views: [UIView] = []
  for scene in scenes {
    guard let window = scene.keyWindow ?? scene.windows.first else { continue }
    views.append(window)
    if let root = window.rootViewController?.view, root !== window {
      views.append(root)
    }
  }
  return views
}

private func guideAttachFoldProbe() {
  guard #available(iOS 27.1, *) else { return }
  guard let root = guideFoldViews().last else { return }
  if guideFoldProbeView?.superview === root { return }
  guideFoldProbeView?.removeFromSuperview()
  let probe = GuideFoldProbe(frame: root.bounds)
  probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  root.addSubview(probe)
  guideFoldProbeView = probe
}

/// Watches layout and the hinge. Folding does not resize the window, so a
/// metrics change is not enough to hear the crease turn on.
@available(iOS 27.1, *)
private final class GuideFoldProbe: UIView {
  private var lastNote = ""
  private var pending = false
  private var hingeNote = "hinge=?"

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
    alpha = 0
    addInteraction(UIHingeInteraction { [weak self] _, update in
      guard let self else { return }
      if let hinge = update.hinge {
        guideHingePartial = hinge.status == .partiallyOpen
        self.hingeNote = "hinge=\(hinge.status.rawValue) angle=\(hinge.angle)"
      } else {
        guideHingePartial = false
        self.hingeNote = "hinge=nil"
      }
      self.report()
    })
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    report()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    report()
  }

  private func report() {
    guard !pending else { return }
    pending = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.pending = false
      let snapshot = guideFoldSnapshot()
      let note = "\(self.hingeNote) \(snapshot.note) regions=\(snapshot.regions.count)"
      guard note != self.lastNote else { return }
      self.lastNote = note
      NSLog("guide fold %@", note)
      guideFoldChannel?.invokeMethod("update", arguments: snapshot.regions)
    }
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
