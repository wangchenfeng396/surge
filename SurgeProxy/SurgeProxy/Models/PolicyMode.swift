//
//  PolicyMode.swift
//  SurgeProxy
//
//  Proxy mode enumeration
//

import Foundation

enum PolicyMode: String, Codable, CaseIterable {
    case direct = "Direct Outbound"
    case global = "Global Proxy"
    case ruleBased = "Rule-Based Proxy"
    
    var apiValue: String {
        switch self {
        case .direct: return "direct"
        case .global: return "global"
        case .ruleBased: return "rule"
        }
    }
}
