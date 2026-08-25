import Foundation

public enum TactConnectionState: Sendable, Equatable {
    case disconnected, connecting, connected, reconnecting
}

public struct TactMessage: Sendable {
    public let type: String
    public let payload: [String: AnySendable]
    public let actionID: String?
    public let requestID: String?
    public let result: AnySendable?
    public let raw: [String: AnySendable]

    public init(type: String, payload: [String: AnySendable] = [:], actionID: String? = nil, requestID: String? = nil, result: AnySendable? = nil, raw: [String: AnySendable] = [:]) {
        self.type = type
        self.payload = payload
        self.actionID = actionID
        self.requestID = requestID
        self.result = result
        self.raw = raw
    }
}

public struct AnySendable: @unchecked Sendable, Equatable {
    public let value: Any
    public init(_ value: Any) { self.value = value }
    public static func == (lhs: Self, rhs: Self) -> Bool { String(describing: lhs.value) == String(describing: rhs.value) }
}

public struct TactDevice: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let platform: String
    public let model: String
    public let os: String
    public let ip: String
    public let connected: Bool

    public init(id: String = UUID().uuidString, name: String, platform: String, model: String, os: String, ip: String, connected: Bool = false) {
        self.id = id; self.name = name; self.platform = platform; self.model = model; self.os = os; self.ip = ip; self.connected = connected
    }
}

public enum TactScreen: String, CaseIterable, Sendable {
    case general, developer, controls, media, events, deck
}

public struct TactSnapshot: Sendable {
    public var values: [String: AnySendable]
    public init(values: [String: AnySendable] = [:]) { self.values = values }

    public func number(_ key: String) -> Double? {
        if let n = values[key]?.value as? NSNumber { return n.doubleValue }
        if let n = values[key]?.value as? Double { return n }
        if let n = values[key]?.value as? Int { return Double(n) }
        return nil
    }

    public func string(_ key: String) -> String? { values[key]?.value as? String }
}
