import Flutter
import UIKit

public class UpdateApplicationPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Constants
    private enum Method: String {
        case getPackageInfo
        case getIosAppStoreInfo
        case openIOSAppStore
    }

    private struct ErrorCode {
        static let invalidArgument = "INVALID_ARGUMENT"
        static let httpError = "HTTP_ERROR"
        static let noData = "NO_DATA"
        static let parseError = "PARSE_ERROR"
        static let noResults = "NO_RESULTS"
        static let bundleIdError = "BUNDLE_ID_ERROR"
        static let invalidUrl = "INVALID_URL"
        static let openFailed = "OPEN_FAILED"
    }

    // MARK: - Flutter Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "update_application/methods",
            binaryMessenger: registrar.messenger()
        )
        let instance = UpdateApplicationPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method Call Handling
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = Method(rawValue: call.method) else {
            return result(FlutterMethodNotImplemented)
        }

        switch method {
        case .getPackageInfo:
            handleGetPackageInfo(result: result)
        case .getIosAppStoreInfo:
            handleGetIosAppStoreInfo(call: call, result: result)
        case .openIOSAppStore:
            handleopenIOSAppStore(result: result)
        }
    }

    // MARK: - Private Methods

    private func handleGetPackageInfo(result: @escaping FlutterResult) {
        let bundle = Bundle.main
        let bundleId = bundle.bundleIdentifier ?? "unknown"
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        result([
            "packageName": bundleId,
            "version": version
        ])
    }

    private func handleGetIosAppStoreInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let bundleId = args["bundleId"] as? String,
            let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)")
        else {
            return sendFlutterError(result, code: ErrorCode.invalidArgument, message: "Missing or invalid 'bundleId'")
        }

        fetchAppStoreInfo(from: url, result: result)
    }

    private func handleopenIOSAppStore(result: @escaping FlutterResult) {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            return sendFlutterError(result, code: ErrorCode.bundleIdError, message: "Unable to retrieve bundle identifier")
        }

        fetchAppStoreInfoInternal(from: url) { infoResult in
            guard let trackViewUrlString = infoResult["trackViewUrl"] as? String,
                  let trackViewUrl = URL(string: trackViewUrlString) else {
                return self.sendFlutterError(result, code: ErrorCode.noResults, message: "Invalid App Store URL")
            }

            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(trackViewUrl) {
                    UIApplication.shared.open(trackViewUrl, options: [:]) { success in
                        success ? result(true) :
                            self.sendFlutterError(result, code: ErrorCode.openFailed, message: "Failed to open App Store URL")
                    }
                } else {
                    self.sendFlutterError(result, code: ErrorCode.invalidUrl, message: "Cannot open App Store URL")
                }
            }
        }
    }

    // MARK: - Fetch Methods

    /// Public wrapper for FlutterResult
    private func fetchAppStoreInfo(from url: URL, result: @escaping FlutterResult) {
        fetchAppStoreInfoInternal(from: url) { infoResult in
            DispatchQueue.main.async {
                result(infoResult)
            }
        }
    }

    /// Internal network call to App Store API
    private func fetchAppStoreInfoInternal(from url: URL, completion: @escaping ([String: Any]) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                return self.sendFlutterError(completion, code: ErrorCode.httpError, message: error.localizedDescription)
            }

            guard let data = data else {
                return self.sendFlutterError(completion, code: ErrorCode.noData, message: "No data received")
            }

            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                    let results = json["results"] as? [[String: Any]],
                    let appInfo = results.first
                else {
                    return self.sendFlutterError(completion, code: ErrorCode.noResults, message: "No results from App Store")
                }

                let version = appInfo["version"] as? String ?? "0.0.0"
                let trackViewUrl = appInfo["trackViewUrl"] as? String ?? ""

                completion([
                    "version": version,
                    "trackViewUrl": trackViewUrl
                ])
            } catch {
                self.sendFlutterError(completion, code: ErrorCode.parseError, message: "Failed to parse App Store response")
            }
        }.resume()
    }

    // MARK: - Error Helpers
    private func sendFlutterError(_ result: @escaping FlutterResult, code: String, message: String) {
        DispatchQueue.main.async {
            print("❌ FlutterError [\(code)]: \(message)")
            result(FlutterError(code: code, message: message, details: nil))
        }
    }

    private func sendFlutterError(_ completion: @escaping ([String: Any]) -> Void, code: String, message: String) {
        DispatchQueue.main.async {
            print("❌ FlutterError [\(code)]: \(message)")
            completion([
                "error": [
                    "code": code,
                    "message": message
                ]
            ])
        }
    }
}
