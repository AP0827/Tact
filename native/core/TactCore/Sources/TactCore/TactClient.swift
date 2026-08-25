import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor TactClient {
    public static let shared = TactClient()

    private var task: URLSessionWebSocketTask?
    private var session: URLSession { URLSession(configuration: .default) }
    private var host: String?
    private var port: Int?
    private var token: String?
    private var manuallyDisconnected = false
    private var requestCounter = 0
    private var reconnectTask: Task<Void, Never>?
    private var continuations: [String: CheckedContinuation<AnySendable, Error>] = [:]
    private var streamContinuation: AsyncStream<TactMessage>.Continuation?
    private var statusContinuation: AsyncStream<TactConnectionState>.Continuation?

    public nonisolated var messages: AsyncStream<TactMessage> {
        AsyncStream { continuation in
            Task { await self.setMessageContinuation(continuation) }
        }
    }

    public nonisolated var status: AsyncStream<TactConnectionState> {
        AsyncStream { continuation in
            Task { await self.setStatusContinuation(continuation) }
        }
    }

    private func setMessageContinuation(_ c: AsyncStream<TactMessage>.Continuation) { streamContinuation = c }
    private func setStatusContinuation(_ c: AsyncStream<TactConnectionState>.Continuation) { statusContinuation = c }

    public func connect(host: String, port: Int, token: String) async throws {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.port = port
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        manuallyDisconnected = false
        reconnectTask?.cancel()
        try await openSocket()
    }

    private func emit(_ state: TactConnectionState) { statusContinuation?.yield(state) }

    private func openSocket() async throws {
        guard !manuallyDisconnected, let host, let port, let token else { return }
        emit(.connecting)
        task?.cancel(with: .goingAway, reason: nil)
        let url = URL(string: "ws://\(host):\(port)/ws")!
        let socket = session.webSocketTask(with: url)
        task = socket
        socket.resume()
        try await sendJSON(["type": "auth", "token": token, "label": "tact-native-client"])
        emit(.connected)
        Task { await self.receiveLoop(socket) }
    }

    private func receiveLoop(_ socket: URLSessionWebSocketTask) async {
        do {
            while !manuallyDisconnected {
                let message = try await socket.receive()
                switch message {
                case .string(let text):
                    handle(text.data(using: .utf8) ?? Data())
                case .data(let data):
                    handle(data)
                @unknown default: break
                }
            }
        } catch {
            guard !manuallyDisconnected else { return }
            emit(.reconnecting)
            scheduleReconnect()
        }
    }

    private func handle(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let type = object["type"] as? String else { return }
        let payload = (object["payload"] as? [String: Any] ?? [:]).mapValues(AnySendable.init)
        let message = TactMessage(type: type, payload: payload, actionID: object["action_id"] as? String, requestID: object["request_id"] as? String, result: object["result"].map(AnySendable.init), raw: object.mapValues(AnySendable.init))
        streamContinuation?.yield(message)
        if type == "action_result" {
            let key = (object["request_id"] as? String) ?? (object["action_id"] as? String)
            if let key, let continuation = continuations.removeValue(forKey: key) { continuation.resume(returning: message.result ?? AnySendable(NSNull())) }
        }
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await task?.send(.string(String(data: data, encoding: .utf8) ?? "{}"))
    }

    public func sendAction(_ actionID: String, payload: [String: AnySendable] = [:]) async throws -> AnySendable {
        guard task != nil else { throw TactError.notConnected }
        requestCounter += 1
        let requestID = "r\(requestCounter)"
        return try await withCheckedThrowingContinuation { continuation in
            continuations[requestID] = continuation
            Task {
                do {
                    try await self.sendJSON([
                        "type": "action",
                        "action_id": actionID,
                        "request_id": requestID,
                        "payload": payload.mapValues(\.value)
                    ])
                } catch {
                    self.failRequest(requestID, error: error)
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.failRequest(requestID, error: TactError.timeout)
            }
        }
    }

    private func failRequest(_ id: String, error: Error) {
        if let continuation = continuations.removeValue(forKey: id) { continuation.resume(throwing: error) }
    }

    public func disconnect() {
        manuallyDisconnected = true
        reconnectTask?.cancel(); reconnectTask = nil
        task?.cancel(with: .normalClosure, reason: nil); task = nil
        for (_, c) in continuations { c.resume(throwing: TactError.notConnected) }
        continuations.removeAll()
        emit(.disconnected)
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            var delay: UInt64 = 500_000_000
            while !Task.isCancelled && !manuallyDisconnected {
                try? await Task.sleep(nanoseconds: delay)
                do { try await openSocket(); return } catch { delay = min(delay * 2, 8_000_000_000) }
            }
        }
    }
}

public enum TactError: LocalizedError {
    case notConnected, timeout
    public var errorDescription: String? {
        switch self { case .notConnected: return "Tact is not connected."; case .timeout: return "The Tact agent did not respond in time." }
    }
}
