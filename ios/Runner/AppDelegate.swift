import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    UIApplication.shared.setMinimumBackgroundFetchInterval(
      TimeInterval(15 * 60)
    )

    WorkmanagerPlugin.registerTask(
      withIdentifier: "com.neuralarc.voidmail.emailCheck"
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
