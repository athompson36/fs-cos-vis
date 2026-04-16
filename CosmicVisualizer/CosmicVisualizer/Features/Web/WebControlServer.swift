import FlyingFox
import FlyingSocks
import Foundation

private struct CosmicStateWSHandler: WSMessageHandler {
    let snapshot: @Sendable () async -> String

    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        AsyncStream { continuation in
            let drain = Task {
                for await _ in client {}
            }
            let push = Task {
                while !Task.isCancelled {
                    let text = await snapshot()
                    continuation.yield(.text(text))
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                drain.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in
                push.cancel()
                drain.cancel()
            }
        }
    }
}

final class WebControlServer: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private weak var appModel: AppModel?

    func bind(appModel: AppModel) {
        self.appModel = appModel
    }

    func applySettings(_ settings: RemoteControlSettings) {
        stop()
        guard settings.remoteControlEnabled else { return }
        guard let model = appModel else { return }

        let port = UInt16(clamping: max(1024, settings.remoteControlPort))
        let token = settings.authToken
        let bindLAN = settings.bindLAN

        task = Task { [weak self] in
            guard let self else { return }
            await self.runServer(appModel: model, port: port, token: token, bindLAN: bindLAN)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func runServer(appModel: AppModel, port: UInt16, token: String, bindLAN: Bool) async {
        let address: sockaddr_in
        do {
            address = try bindLAN ? sockaddr_in.inet(port: port) : sockaddr_in.inet(ip4: "127.0.0.1", port: port)
        } catch {
            return
        }

        let server = HTTPServer(address: address, handler: nil)

        let authorized: @Sendable (HTTPRequest) -> Bool = { req in
            Self.isAuthorized(request: req, token: token)
        }

        await server.appendRoute("GET /health") { _ in
            HTTPResponse(statusCode: .ok, body: Data("{\"ok\":true}".utf8))
        }

        await server.appendRoute("GET /api/schema") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            let data = (try? JSONEncoder().encode(ControlSchema.cosmicDefault())) ?? Data()
            return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
        }

        await server.appendRoute("GET /api/state") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            let data = await MainActor.run { appModel.makeWebStateSnapshotData() }
            return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
        }

        await server.appendRoute("POST /api/command") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let body = try await req.bodyData
                let cmd = try ControlCommandHub.decode(from: body)
                appModel.applyRemoteCommand(cmd)
                return HTTPResponse(statusCode: .ok, body: Data("{\"ok\":true}".utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data("{\"error\":\"bad_command\"}".utf8))
            }
        }

        await server.appendRoute("GET /api/scenes") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let data = try await MainActor.run {
                    try appModel.makeScenesDocumentData()
                }
                return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
            } catch {
                return HTTPResponse(statusCode: .internalServerError, body: Data("{\"error\":\"scenes\"}".utf8))
            }
        }

        await server.appendRoute("PUT /api/scenes") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let body = try await req.bodyData
                try await MainActor.run {
                    try appModel.applyScenesDocument(body)
                }
                return HTTPResponse(statusCode: .ok, body: Data("{\"ok\":true}".utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data("{\"error\":\"bad_scenes\"}".utf8))
            }
        }

        await server.appendRoute("POST /api/scenes/reorder") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let body = try await req.bodyData
                let decoded = try JSONDecoder().decode(ReorderScenesBody.self, from: body)
                await MainActor.run {
                    appModel.applyRemoteCommand(RemoteControlCommand(type: "ReorderScenes", sceneOrder: decoded.sceneOrder))
                }
                return HTTPResponse(statusCode: .ok, body: Data("{\"ok\":true}".utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data("{\"error\":\"bad_reorder\"}".utf8))
            }
        }

        await server.appendRoute("GET /api/settings") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let data = try await MainActor.run {
                    try appModel.makeSettingsData()
                }
                return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
            } catch {
                return HTTPResponse(statusCode: .internalServerError, body: Data())
            }
        }

        await server.appendRoute("PUT /api/settings") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let body = try await req.bodyData
                try await MainActor.run {
                    try appModel.applySettingsDocument(body)
                }
                return HTTPResponse(statusCode: .ok, body: Data("{\"ok\":true}".utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data("{\"error\":\"bad_settings\"}".utf8))
            }
        }

        await server.appendRoute("GET /api/midi_mapping") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let data = try await MainActor.run {
                    try appModel.makeMIDIMappingData()
                }
                return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
            } catch {
                return HTTPResponse(statusCode: .internalServerError, body: Data())
            }
        }

        await server.appendRoute("PUT /api/midi_mapping") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            do {
                let body = try await req.bodyData
                try await MainActor.run {
                    try appModel.applyMIDIMappingDocument(body)
                }
                return HTTPResponse(statusCode: .ok, body: Data("{\"ok\":true}".utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data("{\"error\":\"bad_midi_map\"}".utf8))
            }
        }

        let ws = WebSocketHTTPHandler(
            handler: MessageFrameWSHandler(
                handler: CosmicStateWSHandler {
                    await MainActor.run {
                        String(data: appModel.makeWebStateSnapshotData(), encoding: .utf8) ?? "{}"
                    }
                }
            )
        )
        await server.appendRoute("GET /ws", to: ws)

        await server.appendRoute("GET *") { req in
            guard authorized(req) else { return HTTPResponse(statusCode: .unauthorized) }
            return Self.staticResponse(for: req.path, bundle: .main)
        }

        do {
            try await withTaskCancellationHandler {
                try await server.run()
            } onCancel: {
                Task { await server.stop(timeout: 0.25) }
            }
        } catch {}
    }

    private static func isAuthorized(request: HTTPRequest, token: String) -> Bool {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if request.headers[.authorization] == "Bearer \(t)" { return true }
        if request.query["token"] == t {
            return true
        }
        return false
    }

    private static func staticResponse(for path: String, bundle: Bundle) -> HTTPResponse {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        let noQuery = trimmed.split(separator: "?").first.map(String.init) ?? trimmed
        let parts = noQuery.split(separator: "/").map(String.init)
        let last = parts.last ?? ""
        let name = last.isEmpty ? "index" : last
        let ext = (name as NSString).pathExtension.lowercased()
        let base = ext.isEmpty ? name : ((name as NSString).deletingPathExtension)
        let fileExtension = ext.isEmpty ? "html" : ext

        let url = bundle.url(forResource: base, withExtension: fileExtension, subdirectory: "WebControl")
            ?? bundle.url(forResource: "index", withExtension: "html", subdirectory: "WebControl")
        guard let fileURL = url, let data = try? Data(contentsOf: fileURL) else {
            return HTTPResponse(statusCode: .notFound, body: Data())
        }
        let ctype: String
        switch fileExtension {
        case "html": ctype = "text/html; charset=utf-8"
        case "css": ctype = "text/css; charset=utf-8"
        case "js": ctype = "application/javascript; charset=utf-8"
        default: ctype = "application/octet-stream"
        }
        return HTTPResponse(statusCode: .ok, headers: [.contentType: ctype], body: data)
    }
}
