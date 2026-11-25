import Flutter
import PhotosUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PHPickerViewControllerDelegate {
  private var pendingResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "passiton/media_picker",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "pickCompressedImages" {
        let args = call.arguments as? [String: Any]
        let maxCount = min(max((args?["maxCount"] as? Int) ?? 3, 1), 5)
        self.presentPhotoPicker(maxCount: maxCount, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presentPhotoPicker(maxCount: Int, result: @escaping FlutterResult) {
    if pendingResult != nil {
      result(FlutterError(code: "BUSY", message: "Picker already active", details: nil))
      return
    }
    guard let rootVC = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })?.rootViewController else {
      result([])
      return
    }

    pendingResult = result
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = maxCount
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    rootVC.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let callback = pendingResult else { return }
    pendingResult = nil

    if results.isEmpty {
      callback([])
      return
    }

    let group = DispatchGroup()
    var encoded = [String]()
    let lock = NSLock()

    for item in results {
      if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
        group.enter()
        item.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
          defer { group.leave() }
          guard let image = object as? UIImage else { return }
          let resized = self.scaleDown(image: image, maxDim: 800)
          if let data = resized.jpegData(compressionQuality: 0.75) {
            let url = "data:image/jpeg;base64," + data.base64EncodedString()
            lock.lock()
            encoded.append(url)
            lock.unlock()
          }
        }
      }
    }

    group.notify(queue: .main) {
      callback(encoded)
    }
  }

  private func scaleDown(image: UIImage, maxDim: CGFloat) -> UIImage {
    let size = image.size
    let longest = max(size.width, size.height)
    guard longest > maxDim else { return image }
    let ratio = maxDim / longest
    let target = CGSize(width: size.width * ratio, height: size.height * ratio)
    let renderer = UIGraphicsImageRenderer(size: target)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
