import Flutter
import UIKit

class TorrentPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()

        let methodChannel = FlutterMethodChannel(name: "com.dirxplore.torrent", binaryMessenger: messenger)
        let instance = TorrentPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(name: "com.dirxplore.torrent_events", binaryMessenger: messenger)
        eventChannel.setStreamHandler(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let manager = TorrentEngineManager.shared

        switch call.method {
        case "initialize":
            let args = call.arguments as? [String: Any]
            let downloadDir = args?["downloadDirectory"] as? String
            manager.initialize(downloadDir: downloadDir) { success in
                result(success)
            }

        case "shutdown":
            manager.shutdown()
            result(true)

        case "addMagnet":
            if let args = call.arguments as? [String: Any],
               let magnetUri = args["magnetUri"] as? String {
                let savePath = args["savePath"] as? String
                manager.addMagnet(magnetUri: magnetUri, savePath: savePath) { dict in
                    if let dict = dict {
                        result(dict)
                    } else {
                        result(FlutterError(code: "ADD_FAILED", message: "Failed to add magnet link", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing magnetUri parameter", details: nil))
            }

        case "addTorrentFile":
            if let args = call.arguments as? [String: Any],
               let filePath = args["filePath"] as? String {
                let savePath = args["savePath"] as? String
                manager.addTorrentFile(filePath: filePath, savePath: savePath) { dict in
                    if let dict = dict {
                        result(dict)
                    } else {
                        result(FlutterError(code: "ADD_FAILED", message: "Failed to add torrent file", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing filePath parameter", details: nil))
            }

        case "removeTorrent":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String {
                let deleteData = args["deleteData"] as? Bool ?? false
                manager.removeTorrent(infoHash: infoHash, deleteData: deleteData) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
            }

        case "pauseTorrent":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String {
                manager.pauseTorrent(infoHash: infoHash) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
            }

        case "resumeTorrent":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String {
                manager.resumeTorrent(infoHash: infoHash) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
            }

        case "forceStartTorrent":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String {
                manager.forceStartTorrent(infoHash: infoHash) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
            }

        case "recheckTorrent":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String {
                manager.recheckTorrent(infoHash: infoHash) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash parameter", details: nil))
            }

        case "setFilePriority":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String,
               let fileIndex = args["fileIndex"] as? Int,
               let priority = args["priority"] as? Int {
                manager.setFilePriority(infoHash: infoHash, fileIndex: fileIndex, priority: priority) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing file priority parameters", details: nil))
            }

        case "setSequentialDownload":
            if let args = call.arguments as? [String: Any],
               let infoHash = args["infoHash"] as? String,
               let enabled = args["enabled"] as? Bool {
                manager.setSequentialDownload(infoHash: infoHash, enabled: enabled) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters", details: nil))
            }

        case "getTorrents":
            result(manager.getTorrents())

        case "getSessionStats":
            result(manager.getSessionStats())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler Protocol

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        TorrentEngineManager.shared.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        TorrentEngineManager.shared.eventSink = nil
        return nil
    }
}
