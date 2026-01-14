//
//  URLRewriteRule.swift
//  SurgeProxy
//
//  URL rewrite rule configuration
//

import Foundation

struct URLRewriteRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled: Bool = true
    var pattern: String
    var replacement: String
    var type: RewriteType = .redirect302
    
    enum RewriteType: String, Codable, CaseIterable {
        case redirect302 = "302"
        case redirect307 = "307"
        case reject = "reject"
        case header = "header"
        
        var displayName: String {
            switch self {
            case .redirect302: return "302 Redirect"
            case .redirect307: return "307 Redirect"
            case .reject: return "Reject"
            case .header: return "Header Modify"
            }
        }
    }
    
    init(id: UUID = UUID(), enabled: Bool = true, pattern: String, replacement: String, type: RewriteType = .redirect302) {
        self.id = id
        self.enabled = enabled
        self.pattern = pattern
        self.replacement = replacement
        self.type = type
    }
}
