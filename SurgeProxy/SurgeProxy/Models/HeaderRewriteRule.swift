//
//  HeaderRewriteRule.swift
//  SurgeProxy
//
//  Header rewrite rule model
//

import Foundation

struct HeaderRewriteRule: Codable, Identifiable {
    var id = UUID()
    var pattern: String  // URL pattern
    var header: String   // Header name
    var value: String    // Header value (replacement)
    var type: RewriteType
    var enabled: Bool = true
    
    enum RewriteType: String, Codable, CaseIterable {
        case request = "request"
        case response = "response"
        
        var displayName: String {
            switch self {
            case .request: return "请求"
            case .response: return "响应"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case pattern, header, value, type, enabled
    }
}
