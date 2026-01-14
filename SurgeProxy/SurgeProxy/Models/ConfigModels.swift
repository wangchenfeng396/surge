//
//  ConfigModels.swift
//  SurgeProxy
//
//  Data models for Surge configuration
//

import Foundation

// MARK: - General Configuration

struct GeneralConfig: Codable {
    var testTimeout: Int?
    var udpPriority: Bool?
    var internetTestURL: String?
    var proxyTestURL: String?
    var geoipMaxmindURL: String?
    var ipv6: Bool?
    var dnsServer: [String]?
    var dnsServers: [String]?  // alias for compatibility
    var encryptedDNSServer: [String]?
    var encryptedDNSServers: [String]?  // alias for compatibility
    var showErrorPageForReject: Bool?
    var skipProxy: [String]?
    var allowWifiAccess: Bool?
    var wifiAccessHTTPPort: Int?
    var wifiAccessSOCKS5Port: Int?
    var allowHotspotAccess: Bool?
    var wifiAssist: Bool?
    var httpApiTls: Bool?
    var httpApiWebDashboard: Bool?
    var allHybrid: Bool?
    var excludeSimpleHostnames: Bool?
    var readEtcHosts: Bool?
    var loglevel: String?
    var alwaysRealIP: [String]?
    var disableGeoIPDBAutoUpdate: Bool?
    var udpPolicyNotSupportedBehaviour: String?
    var tunIncludedRoutes: [String]?
    var tunExcludedRoutes: [String]?
    
    enum CodingKeys: String, CodingKey {
        case testTimeout = "test_timeout"
        case udpPriority = "udp_priority"
        case internetTestURL = "internet_test_url"
        case proxyTestURL = "proxy_test_url"
        case geoipMaxmindURL = "geoip_maxmind_url"
        case ipv6
        case dnsServer = "dns_server"
        case encryptedDNSServer = "encrypted_dns_server"
        case showErrorPageForReject = "show_error_page_for_reject"
        case skipProxy = "skip_proxy"
        case allowWifiAccess = "allow_wifi_access"
        case wifiAccessHTTPPort = "wifi_access_http_port"
        case wifiAccessSOCKS5Port = "wifi_access_socks5_port"
        case allowHotspotAccess = "allow_hotspot_access"
        case wifiAssist = "wifi_assist"
        case httpApiTls = "http_api_tls"
        case httpApiWebDashboard = "http_api_web_dashboard"
        case allHybrid = "all_hybrid"
        case excludeSimpleHostnames = "exclude_simple_hostnames"
        case readEtcHosts = "read_etc_hosts"
        case loglevel
        case alwaysRealIP = "always_real_ip"
        case disableGeoIPDBAutoUpdate = "disable_geoip_db_auto_update"
        case udpPolicyNotSupportedBehaviour = "udp_policy_not_supported_behaviour"
        case tunIncludedRoutes = "tun_included_routes"
        case tunExcludedRoutes = "tun_excluded_routes"
    }
}

// MARK: - Proxy Configuration

struct ProxyConfigModel: Codable, Identifiable {
    var id: String { name }
    var name: String
    var type: String
    var server: String
    var port: Int
    var username: String?
    var password: String?
    var auth: Bool?
    var tls: Bool?
    var sni: String?
    var skipCertVerify: Bool?
    var tfo: Bool?
    var udp: Bool?
    var parameters: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case name, type, server, port, username, password, auth, tls, sni
        case skipCertVerify = "skip_cert_verify"
        case tfo, udp, parameters
    }
}

// MARK: - Proxy Group Configuration

struct ProxyGroupConfigModel: Codable, Identifiable {
    var id: String { name }
    var name: String
    var type: String  // select, url-test, load-balance, fallback, relay
    var proxies: [String]
    var url: String?
    var interval: Int?
    var tolerance: Int?
    var timeout: Int?
    var updateInterval: Int?
    var policyPath: String?
    var policyRegex: String?
    var includeAll: Bool?
    var hidden: Bool?
    var noAlert: Bool?
    var evaluateBeforeUse: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, type, proxies, url, interval, tolerance, timeout
        case updateInterval = "update_interval"
        case policyPath = "policy_path"
        case policyRegex = "policy_regex_filter"
        case includeAll = "include_all_proxies"
        case hidden
        case noAlert = "no_alert"
        case evaluateBeforeUse = "evaluate_before_use"
    }
}

// MARK: - Rule Configuration

struct RuleConfigModel: Codable, Identifiable {
    var id = UUID()
    var type: String
    var value: String
    var policy: String
    var params: [String]?
    var noResolve: Bool?
    var updateInterval: Int?
    var comment: String?
    
    enum CodingKeys: String, CodingKey {
        case type, value, policy, params
        case noResolve = "no_resolve"
        case updateInterval = "update_interval"
        case comment
    }
}

// MARK: - System Status

struct SystemProxyStatus: Codable {
    var enabled: Bool
    var port: Int
    var selectedProxy: String?
    
    enum CodingKeys: String, CodingKey {
        case enabled, port
        case selectedProxy = "selected_proxy"
    }
}

struct TUNStatus: Codable {
    var enabled: Bool
}

// MARK: - Proxy Types

enum ProxyType: String, CaseIterable {
    case vmess
    case vless
    case shadowsocks = "ss"
    case trojan
    case hysteria2
    case direct
    case reject
    
    var displayName: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .shadowsocks: return "Shadowsocks"
        case .trojan: return "Trojan"
        case .hysteria2: return "Hysteria2"
        case .direct: return "Direct"
        case .reject: return "Reject"
        }
    }
}

// MARK: - Proxy Group Types

enum ProxyGroupType: String, CaseIterable {
    case select
    case urlTest = "url-test"
    case fallback
    case loadBalance = "load-balance"
    case relay
    case smart
    
    var displayName: String {
        switch self {
        case .select: return "手动选择"
        case .urlTest: return "自动选择"
        case .fallback: return "故障转移"
        case .loadBalance: return "负载均衡"
        case .relay: return "链式代理"
        case .smart: return "智能选择 (Smart)"
        }
    }
}

// MARK: - Rule Types

enum RuleType: String, CaseIterable {
    case domain = "DOMAIN"
    case domainSuffix = "DOMAIN-SUFFIX"
    case domainKeyword = "DOMAIN-KEYWORD"
    case ipCidr = "IP-CIDR"
    case ipCidr6 = "IP-CIDR6"
    case geoip = "GEOIP"
    case userAgent = "USER-AGENT"
    case urlRegex = "URL-REGEX"
    case processName = "PROCESS-NAME"
    case ruleSet = "RULE-SET"
    case final = "FINAL"
    case and = "AND"
    case or = "OR"
    case not = "NOT"
    
    var displayName: String {
        switch self {
        case .domain: return "域名 (DOMAIN)"
        case .domainSuffix: return "域名后缀 (DOMAIN-SUFFIX)"
        case .domainKeyword: return "域名关键词 (DOMAIN-KEYWORD)"
        case .ipCidr: return "IP CIDR"
        case .ipCidr6: return "IP CIDR v6"
        case .geoip: return "GeoIP"
        case .userAgent: return "User-Agent"
        case .urlRegex: return "URL 正则 (URL-REGEX)"
        case .processName: return "进程名 (PROCESS-NAME)"
        case .ruleSet: return "规则集 (RULE-SET)"
        case .final: return "最终规则 (FINAL)"
        case .and: return "AND"
        case .or: return "OR"
        case .not: return "NOT"
        }
    }
    
    var needsValue: Bool {
        self != .final
    }
    
    var description: String {
        switch self {
        case .domain: return "精确匹配域名"
        case .domainSuffix: return "匹配域名后缀"
        case .domainKeyword: return "匹配域名中的关键词"
        case .ipCidr: return "匹配 IPv4 地址段"
        case .ipCidr6: return "匹配 IPv6 地址段"
        case .geoip: return "根据 IP 地理位置匹配"
        case .userAgent: return "根据 User-Agent 匹配"
        case .urlRegex: return "使用正则表达式匹配 URL"
        case .processName: return "根据进程名匹配"
        case .ruleSet: return "使用外部规则集"
        case .final: return "所有其他规则不匹配时使用"
        case .and: return "AND 逻辑"
        case .or: return "OR 逻辑"
        case .not: return "NOT 逻辑"
        }
    }
}

