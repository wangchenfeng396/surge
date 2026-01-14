//
//  APIClient.swift
//  SurgeProxy
//
//  REST API client for sing-box backend communication
//

import Foundation

class APIClient {
    static let shared = APIClient()
    
    private var baseURL = "http://localhost:19090" // Default, will be updated
    private let session: URLSession
    
    // Configurable port
    func setPort(_ port: Int) {
        self.baseURL = "http://localhost:\(port)"
        print("APIClient configured to use port: \(port)")
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Stats API
    
    func fetchStats() async throws -> NetworkStats {
        let url = URL(string: "\(baseURL)/api/stats")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(NetworkStats.self, from: data)
    }
    
    // MARK: - Process API
    
    func fetchProcesses() async throws -> [NetworkProcessInfo] {
        let url = URL(string: "\(baseURL)/api/processes")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([NetworkProcessInfo].self, from: data)
    }
    
    // MARK: - Device API
    
    func fetchDevices() async throws -> [DeviceInfo] {
        let url = URL(string: "\(baseURL)/api/devices")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([DeviceInfo].self, from: data)
    }
    
    // MARK: - Test API
    
    func testDirect() async throws -> ProxyTestResponse {
        return try await testProxy(name: "DIRECT", url: "http://www.bing.com")
    }
    
    
    // DEPRECATED: Use the newer testProxy function (line 471) that returns ProxyTestResponse
    /*
    func testProxy(name: String, url: String) async throws -> TestResult {
        let endpoint = URL(string: "\(baseURL)/api/test/proxy")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": name, "url": url]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(TestResult.self, from: data)
    }
    */
    
    // MARK: - Config API
    
    func updateConfig(_ config: ProxyConfig) async throws {
        let url = URL(string: "\(baseURL)/api/config")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(config)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Proxy Control API
    
    func startProxy() async throws {
        let url = URL(string: "\(baseURL)/api/proxy/start")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func stopProxy() async throws {
        let url = URL(string: "\(baseURL)/api/proxy/stop")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func selectProxy(group: String, proxy: String) async throws {
        let encodedGroup = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? group
        let url = URL(string: "\(baseURL)/api/config/proxy-groups/\(encodedGroup)/select")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["proxy": proxy]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - sing-box Specific APIs
    
    func fetchProxies() async throws -> ProxyListResponse {
        let url = URL(string: "\(baseURL)/api/proxies")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ProxyListResponse.self, from: data)
    }
    
    func uploadSurgeConfig(_ configText: String) async throws {
        let url = URL(string: "\(baseURL)/api/config")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["config": configText]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.configUploadFailed
        }
    }
    
    func fetchRules() async throws -> RulesResponse {
        let url = URL(string: "\(baseURL)/api/rules")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(RulesResponse.self, from: data)
    }
    
    func updateRules(_ rules: [String]) async throws {
        let url = URL(string: "\(baseURL)/api/rules")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["rules": rules]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func fetchRulesDetail() async throws -> RulesDetailResponse {
        let url = URL(string: "\(baseURL)/api/rules/detail")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(RulesDetailResponse.self, from: data)
    }
    
    func resetRuleCounters() async throws {
        let url = URL(string: "\(baseURL)/api/rules/reset-counters")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func toggleRule(id: Int, enabled: Bool) async throws {
        let url = URL(string: "\(baseURL)/api/rules/\(id)/toggle")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["enabled": enabled]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func setGlobalProxy(proxy: String) async throws {
        let url = URL(string: "\(baseURL)/api/proxies/global")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["proxy": proxy]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - UI Button Support APIs
    
    func getCurrentConfig() async throws -> String {
        let url = URL(string: "\(baseURL)/api/config")!
        let (data, _) = try await session.data(from: url)
        
        struct ConfigResponse: Codable {
            let config: String
        }
        
        let response = try JSONDecoder().decode(ConfigResponse.self, from: data)
        return response.config
    }
    
    func switchProxyInGroup(group: String, proxy: String) async throws {
        try await selectProxy(group: group, proxy: proxy)
    }
    
    func toggleProxy(name: String, enabled: Bool) async throws {
        let url = URL(string: "\(baseURL)/api/proxy/toggle")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": name, "enabled": enabled] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func setProxyMode(_ mode: String) async throws {
        let url = URL(string: "\(baseURL)/api/proxy/mode")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["mode": mode]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Health Check
    
    func checkHealth() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/api/health")!
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
    
    // MARK: - Configuration Management API
    
    // General Configuration
    func fetchGeneralConfig() async throws -> GeneralConfig {
        let url = URL(string: "\(baseURL)/api/config/general")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(GeneralConfig.self, from: data)
    }
    
    func updateGeneralConfig(_ config: GeneralConfig) async throws {
        let url = URL(string: "\(baseURL)/api/config/general")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(config)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // Proxy Management
    func fetchAllProxies() async throws -> [ProxyConfigModel] {
        let url = URL(string: "\(baseURL)/api/config/proxies")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([ProxyConfigModel].self, from: data)
    }
    
    func addProxy(_ proxy: ProxyConfigModel) async throws {
        let url = URL(string: "\(baseURL)/api/config/proxies")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(proxy)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func updateProxy(name: String, proxy: ProxyConfigModel) async throws {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "\(baseURL)/api/config/proxies/\(encodedName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(proxy)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteProxy(name: String) async throws {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "\(baseURL)/api/config/proxies/\(encodedName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // Proxy Group Management
    func fetchAllProxyGroups() async throws -> [ProxyGroupConfigModel] {
        let url = URL(string: "\(baseURL)/api/config/proxy-groups")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([ProxyGroupConfigModel].self, from: data)
    }
    
    func addProxyGroup(_ group: ProxyGroupConfigModel) async throws {
        let url = URL(string: "\(baseURL)/api/config/proxy-groups")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(group)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func updateProxyGroup(name: String, group: ProxyGroupConfigModel) async throws {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "\(baseURL)/api/config/proxy-groups/\(encodedName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(group)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteProxyGroup(name: String) async throws {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = URL(string: "\(baseURL)/api/config/proxy-groups/\(encodedName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // Rule Management
    func fetchAllRules() async throws -> [RuleConfigModel] {
        let url = URL(string: "\(baseURL)/api/config/rules")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([RuleConfigModel].self, from: data)
    }
    
    func addRule(_ rule: RuleConfigModel) async throws {
        let url = URL(string: "\(baseURL)/api/config/rules")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(rule)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func updateRule(index: Int, rule: RuleConfigModel) async throws {
        let url = URL(string: "\(baseURL)/api/config/rules/\(index)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(rule)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteRule(index: Int) async throws {
        let url = URL(string: "\(baseURL)/api/config/rules/\(index)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    func moveRule(fromIndex: Int, toIndex: Int) async throws {
        let url = URL(string: "\(baseURL)/api/config/rules/move")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["from_index": fromIndex, "to_index": toIndex]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - System Integration API
    
    // System Proxy
    func enableSystemProxy(port: Int = 8888) async throws {
        let url = URL(string: "\(baseURL)/api/system-proxy/enable")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["port": port]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func disableSystemProxy() async throws {
        let url = URL(string: "\(baseURL)/api/system-proxy/disable")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func fetchSystemProxyStatus() async throws -> SystemProxyStatus {
        let url = URL(string: "\(baseURL)/api/system-proxy/status")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(SystemProxyStatus.self, from: data)
    }
    
    // TUN Mode
    func enableTUN() async throws {
        let url = URL(string: "\(baseURL)/api/tun/enable")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func disableTUN() async throws {
        let url = URL(string: "\(baseURL)/api/tun/disable")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func fetchTUNStatus() async throws -> TUNStatus {
        let url = URL(string: "\(baseURL)/api/tun/status")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TUNStatus.self, from: data)
    }
    
    // MARK: - Proxy Testing
    
    /// 通过代理服务器端口测试代理（方案B - 推荐）
    func testProxyLive(name: String, url: String = "http://cp.cloudflare.com/generate_204") async throws -> ProxyTestResponse {
        let endpoint = URL(string: "\(baseURL)/api/proxy/test-live")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 6秒超时（后端5秒 + 1秒网络余量）
        request.timeoutInterval = 6
        
        let body = [
            "name": name,
            "url": url
        ]
        
        if let bodyData = try? JSONSerialization.data(withJSONObject: body),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("🔍 APIClient: Testing proxy '\(name)' via server port (方案B)")
            print("➡️ Request Body: \(bodyString)")
            request.httpBody = bodyData
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("⬅️ Response Status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("⬅️ Response Body: \(responseString)")
            }
            
            return try JSONDecoder().decode(ProxyTestResponse.self, from: data)
        } catch {
            print("❌ APIClient Error: \(error)")
            throw error
        }
    }
    
    /// 原方法保留作为备选（方案A - 直接协议层测试）
    func testProxy(name: String, url: String) async throws -> ProxyTestResponse {
        // 默认使用新的方案B（通过代理服务器测试）
        return try await testProxyLive(name: name, url: url)
    }
    
    func testAllProxies(url: String) async throws -> [ProxyTestResponse] {
        // TODO: Implement /api/proxy/test-all on backend
        let endpoint = URL(string: "\(baseURL)/api/proxy/test-all?url=\(url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url)")!
        _ = endpoint // suppress warning
        let (data, _) = try await session.data(from: endpoint) // This will 404
        return try JSONDecoder().decode([ProxyTestResponse].self, from: data)
    }
    
    // MARK: - Connections API
    
    func fetchConnections() async throws -> [ConnectionInfo] {
        let url = URL(string: "\(baseURL)/api/connections")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ConnectionInfo].self, from: data)
    }
    
    func fetchCapture() async throws -> [CaptureRequest] {
        let url = URL(string: "\(baseURL)/api/capture")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CaptureRequest].self, from: data)
    }

    // MARK: - Config File Management
    
    func fetchConfig() async throws -> ConfigResponse {
        let url = URL(string: "\(baseURL)/api/config")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
    
    func updateConfig(_ configContent: String) async throws {
        let url = URL(string: "\(baseURL)/api/config")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["config": configContent]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Host Mapping API
    
    func fetchHosts() async throws -> [HostMapping] {
        let url = URL(string: "\(baseURL)/api/config/hosts")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([HostMapping].self, from: data)
    }
    
    func addHost(domain: String, value: String) async throws {
        let url = URL(string: "\(baseURL)/api/config/hosts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["domain": domain, "value": value]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteHost(domain: String) async throws {
        let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? domain
        let url = URL(string: "\(baseURL)/api/config/hosts/\(encodedDomain)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Diagnostics
    
    func fetchDNSDiagnostics() async throws -> [String: Int] {
        let url = URL(string: "\(baseURL)/api/dns/diagnose")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([String: Int].self, from: data)
    }
    
    func fetchSystemGateway() async throws -> (gateway: String, interface: String) {
        let url = URL(string: "\(baseURL)/api/system/gateway")!
        let (data, _) = try await session.data(from: url)
        struct GatewayResponse: Decodable {
            let gateway: String
            let interface: String
        }
        let res = try JSONDecoder().decode(GatewayResponse.self, from: data)
        return (res.gateway, res.interface)
    }
    
    // MARK: - URL Rewrite API
    
    func fetchURLRewrites() async throws -> [URLRewriteRule] {
        let url = URL(string: "\(baseURL)/api/config/url-rewrites")!
        let (data, _) = try await session.data(from: url)
        
        // Backend returns array of objects with type, regex, replacement
        struct BackendRewrite: Codable {
            let type: String
            let regex: String
            let replacement: String
            let mode: String?
        }
        
        let backendRewrites = try JSONDecoder().decode([BackendRewrite].self, from: data)
        
        return backendRewrites.map { rewrite in
            URLRewriteRule(
                pattern: rewrite.regex,
                replacement: rewrite.replacement,
                type: URLRewriteRule.RewriteType(rawValue: rewrite.type) ?? .redirect302
            )
        }
    }
    
    func addURLRewrite(_ rule: URLRewriteRule) async throws {
        let url = URL(string: "\(baseURL)/api/config/url-rewrites")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "type": rule.type.rawValue,
            "regex": rule.pattern,
            "replacement": rule.replacement
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteURLRewrite(pattern: String) async throws {
        let encodedPattern = pattern.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pattern
        let url = URL(string: "\(baseURL)/api/config/url-rewrites/\(encodedPattern)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Header Rewrite API
    
    func fetchHeaderRewrites() async throws -> [HeaderRewriteRule] {
        let url = URL(string: "\(baseURL)/api/config/header-rewrites")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([HeaderRewriteRule].self, from: data)
    }
    
    func addHeaderRewrite(_ rule: HeaderRewriteRule) async throws {
        let url = URL(string: "\(baseURL)/api/config/header-rewrites")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(rule)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func deleteHeaderRewrite(pattern: String, header: String) async throws {
        let encodedPattern = pattern.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pattern
        let encodedHeader = header.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? header
        let url = URL(string: "\(baseURL)/api/config/header-rewrites/\(encodedPattern)/\(encodedHeader)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - MITM API
    
    func fetchMITMConfig() async throws -> MITMConfig {
        let url = URL(string: "\(baseURL)/api/config/mitm")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(MITMConfig.self, from: data)
    }
    
    func updateMITMConfig(_ config: MITMConfig) async throws {
        let url = URL(string: "\(baseURL)/api/config/mitm")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(config)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    // MARK: - Config Reload API
    
    func triggerReload() async throws {
        let url = URL(string: "\(baseURL)/api/config/reload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
    
    func fetchReloadStatus() async throws -> ReloadStatusResponse {
        let url = URL(string: "\(baseURL)/api/config/reload-status")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(ReloadStatusResponse.self, from: data)
    }

    // MARK: - Rule Match API
    
    struct RuleMatchRequest: Codable {
        let url: String
        let source_ip: String
        let process: String
    }
    
    struct RuleMatchResponse: Codable {
        let rule: String
        let policy: String
        
        enum CodingKeys: String, CodingKey {
            case rule
            case policy = "adapter"
        }
    }

    func matchRule(url: String, sourceIP: String = "127.0.0.1", process: String = "") async throws -> RuleMatchResponse {
        let endpoint = URL(string: "\(baseURL)/api/rules/match")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = RuleMatchRequest(url: url, source_ip: sourceIP, process: process)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(RuleMatchResponse.self, from: data)
    }

    // MARK: - DNS API

    struct DNSQueryResult: Codable {
        let host: String
        let ips: [String]?
        let error: String?
    }

    func dnsQuery(host: String) async throws -> DNSQueryResult {
        guard let encoded = host.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/dns/query?host=\(encoded)") else {
            throw APIError.networkError
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(DNSQueryResult.self, from: data)
    }
}

// MARK: - Additional Models

struct ReloadStatusResponse: Codable {
    let reloading: Bool?
    let lastReload: String?
    let status: String?
}

// MARK: - Models

enum APIError: Error {
    case invalidResponse
    case networkError
    case decodingError
    case configUploadFailed
}

struct ProxyListResponse: Codable {
    let proxies: [ProxyRuntimeInfo] // Updated to use RuntimeInfo
}

struct ProxyRuntimeInfo: Codable {
    let name: String
    let type: String
    let now: String?
}

struct RuleDTO: Codable, Identifiable {
    let id: Int
    let type: String
    let payload: String
    let policy: String
    let hit_count: Int64
    let enabled: Bool
    let comment: String
}

struct RulesDetailResponse: Codable {
    let rules: [RuleDTO]
}

struct RulesResponse: Codable {
    let rules: [String]
}

struct ProxyTestResponse: Codable {
    let name: String
    let success: Bool?
    let latency: Int?
    let error: String?
}

struct ConfigResponse: Codable {
    let config: String
}
