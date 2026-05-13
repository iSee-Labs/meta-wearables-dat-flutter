import Flutter
import UIKit

/// Forwards inbound URL contexts to the meta_wearables_dat_flutter plugin
/// so the Meta AI registration callback reaches `Wearables.shared.handleUrl`.
/// See `example/ios/Runner/SceneDelegate.swift` for the full rationale.
class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    forward(urlContexts: connectionOptions.urlContexts, on: scene)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    forward(urlContexts: URLContexts, on: scene)
  }

  private func forward(urlContexts: Set<UIOpenURLContext>, on scene: UIScene) {
    guard
      let windowScene = scene as? UIWindowScene,
      let controller = windowScene.windows.first?.rootViewController
        as? FlutterViewController
    else { return }

    let channel = FlutterMethodChannel(
      name: "meta_wearables_dat_flutter",
      binaryMessenger: controller.binaryMessenger
    )
    for context in urlContexts {
      channel.invokeMethod(
        "handleUrl",
        arguments: ["url": context.url.absoluteString]
      )
    }
  }
}
