//
//  ProxyGroup.swift
//  SurgeProxy
//
//  Proxy group model
//

import Foundation

struct ProxyGroup: Identifiable, Codable {
    var id = UUID()
    var name: String
    var type: String  // select, url-test, fallback, load-balance
    var proxies: [String]
    var url: String?
    var interval: Int?
    var tolerance: Int?
    var testURL: String?
    var policyRegexFilter: String?
    var policyPath: String?
    var includeAllProxies: Bool = false
    var hidden: Bool = false
    var noAlert: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case name, type, proxies, url, interval, tolerance
        case testURL = "test_url"
        case policyRegexFilter = "policy_regex_filter"
        case policyPath = "policy_path"
        case includeAllProxies = "include_all_proxies"
        case hidden
        case noAlert = "no_alert"
    }
    
    init(name: String, type: String, proxies: [String], url: String? = nil, interval: Int? = nil, tolerance: Int? = nil, testURL: String? = nil, policyRegexFilter: String? = nil, policyPath: String? = nil, includeAllProxies: Bool = false, hidden: Bool = false, noAlert: Bool = false) {
        self.name = name
        self.type = type
        self.proxies = proxies
        self.url = url
        self.interval = interval
        self.tolerance = tolerance
        self.testURL = testURL
        self.policyRegexFilter = policyRegexFilter
        self.policyPath = policyPath
        self.includeAllProxies = includeAllProxies
        self.hidden = hidden
        self.noAlert = noAlert
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        proxies = try container.decode([String].self, forKey: .proxies)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval)
        tolerance = try container.decodeIfPresent(Int.self, forKey: .tolerance)
        testURL = try container.decodeIfPresent(String.self, forKey: .testURL)
        policyRegexFilter = try container.decodeIfPresent(String.self, forKey: .policyRegexFilter)
        policyPath = try container.decodeIfPresent(String.self, forKey: .policyPath)
        includeAllProxies = try container.decodeIfPresent(Bool.self, forKey: .includeAllProxies) ?? false
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        noAlert = try container.decodeIfPresent(Bool.self, forKey: .noAlert) ?? false
    }
}
