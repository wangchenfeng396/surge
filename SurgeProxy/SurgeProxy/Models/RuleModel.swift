//
//  RuleModel.swift
//  SurgeProxy
//
//  Rule model
//

import Foundation

struct ProxyRule: Identifiable, Codable {
    var id = UUID()
    var enabled: Bool = true
    var type: String
    var value: String
    var policy: String
    var noResolve: Bool = false
    var used: Int = 0
    var comment: String = ""
    var backendID: Int? // Store the index from backend
    var notification: Bool = false
    var notificationText: String = ""
    var notificationInterval: Int = 300
    var extendedMatching: Bool = false
    var preMatching: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case type, value, policy
        case noResolve = "no-resolve"
        case enabled, used, comment
        case backendID = "id" // Map from API 'id'
        case notification
        case notificationText = "notification_text"
        case notificationInterval = "notification_interval"
        case extendedMatching = "extended_matching"
        case preMatching = "pre_matching"
    }
    
    init(id: UUID = UUID(), backendID: Int? = nil, enabled: Bool = true, type: String, value: String, policy: String, noResolve: Bool = false, used: Int = 0, comment: String = "", notification: Bool = false, notificationText: String = "", notificationInterval: Int = 300, extendedMatching: Bool = false, preMatching: Bool = false) {
        self.id = id
        self.backendID = backendID
        self.enabled = enabled
        self.type = type
        self.value = value
        self.policy = policy
        self.noResolve = noResolve
        self.used = used
        self.comment = comment
        self.notification = notification
        self.notificationText = notificationText
        self.notificationInterval = notificationInterval
        self.extendedMatching = extendedMatching
        self.preMatching = preMatching
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        value = try container.decode(String.self, forKey: .value)
        policy = try container.decode(String.self, forKey: .policy)
        noResolve = try container.decodeIfPresent(Bool.self, forKey: .noResolve) ?? false
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        used = try container.decodeIfPresent(Int.self, forKey: .used) ?? 0
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        backendID = try container.decodeIfPresent(Int.self, forKey: .backendID)
        notification = try container.decodeIfPresent(Bool.self, forKey: .notification) ?? false
        notificationText = try container.decodeIfPresent(String.self, forKey: .notificationText) ?? ""
        notificationInterval = try container.decodeIfPresent(Int.self, forKey: .notificationInterval) ?? 300
        extendedMatching = try container.decodeIfPresent(Bool.self, forKey: .extendedMatching) ?? false
        preMatching = try container.decodeIfPresent(Bool.self, forKey: .preMatching) ?? false
    }
    
    var ruleString: String {
        var components = [type, value, policy]
        if noResolve {
            components.append("no-resolve")
        }
        // Note: New fields (notification etc) are likely client-side only or require specific serialization
        // For now, we only serialize the standard surge rule parts to string.
        return components.joined(separator: ",")
    }
}
