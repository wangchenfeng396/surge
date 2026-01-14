//
//  SurgeConfigManager.swift
//  SurgeProxy
//
//  Direct configuration file manager for surge.conf
//  Provides high-efficiency file-based config read/write
//

import Foundation

class SurgeConfigManager: ObservableObject {
    static let shared = SurgeConfigManager()
    
    @Published var proxies: [SurgeProxy] = []
    @Published var proxyGroups: [SurgeProxyGroup] = []
    @Published var rules: [String] = []
    
    private var configPath: URL?
    private var fileMonitor: DispatchSourceFileSystemObject?
    
    init() {
        // Check environment variable first
        if let workspacePath = ProcessInfo.processInfo.environment["SURGE_CONFIG_PATH"] {
            configPath = URL(fileURLWithPath: workspacePath)
        } else {
            // Primary path: ~/Library/Application Support/SurgeProxy/surge.conf
            let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("SurgeProxy")
                .appendingPathComponent("surge.conf")
            
            if let path = appSupportPath, FileManager.default.fileExists(atPath: path.path) {
                configPath = path
            } else {
                // Fallback paths for development
                let fallbackPaths = [
                    FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Application Support/SurgeProxy/surge.conf"),
                    Bundle.main.bundleURL
                        .deletingLastPathComponent()
                        .appendingPathComponent("surge.conf")
                ]
                configPath = fallbackPaths.first { FileManager.default.fileExists(atPath: $0.path) }
            }
        }
        
        print("SurgeConfigManager: Using config path: \(configPath?.path ?? "nil")")
    }
    
    // MARK: - Public API
    
    func setConfigPath(_ path: URL) {
        self.configPath = path
        loadConfig()
    }
    
    func loadConfig() {
        guard let path = configPath else {
            print("Config path not set")
            return
        }
        
        do {
            let content = try String(contentsOf: path, encoding: .utf8)
            parseConfig(content)
        } catch {
            print("Failed to load config: \(error)")
        }
    }
    
    func saveConfig() {
        guard let path = configPath else { return }
        
        let content = generateConfigString()
        
        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
    
    // MARK: - Parsing
    
    private func parseConfig(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        var parsedProxies: [SurgeProxy] = []
        var parsedGroups: [SurgeProxyGroup] = []
        var parsedRules: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            // Section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                continue
            }
            
            switch currentSection {
            case "Proxy":
                if let proxy = parseProxyLine(trimmed) {
                    parsedProxies.append(proxy)
                }
            case "Proxy Group":
                if let group = parseProxyGroupLine(trimmed) {
                    parsedGroups.append(group)
                }
            case "Rule":
                parsedRules.append(trimmed)
            default:
                break
            }
        }
        
        DispatchQueue.main.async {
            self.proxies = parsedProxies
            self.proxyGroups = parsedGroups
            self.rules = parsedRules
        }
    }
    
    private func parseProxyLine(_ line: String) -> SurgeProxy? {
        // Format: name = type, server, port, key=value, key=value...
        let parts = line.components(separatedBy: "=")
        guard parts.count >= 2 else { return nil }
        
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let rest = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
        
        let components = rest.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= 3 else { return nil }
        
        let type = components[0]
        let server = components[1]
        let port = Int(components[2]) ?? 443
        
        var proxy = SurgeProxy(name: name, type: type, server: server, port: port)
        
        // Parse key=value pairs
        for i in 3..<components.count {
            let kv = components[i].components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = kv[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "username", "uuid":
                proxy.uuid = value
            case "password":
                proxy.password = value
            case "encrypt-method":
                proxy.encryption = value
            case "ws":
                proxy.ws = value == "true"
            case "ws-path":
                proxy.wsPath = value
            case "tls":
                proxy.tls = value == "true"
            case "sni":
                proxy.sni = value
            case "skip-cert-verify":
                proxy.skipCertVerify = value == "true"
            case "flow":
                proxy.flow = value
            case "up":
                proxy.uploadSpeed = Int(value)
            case "down":
                proxy.downloadSpeed = Int(value)
            default:
                proxy.extra[key] = value
            }
        }
        
        return proxy
    }
    
    private func parseProxyGroupLine(_ line: String) -> SurgeProxyGroup? {
        // Format: name = type, proxy1, proxy2, ... [, key=value]
        let parts = line.components(separatedBy: "=")
        guard parts.count >= 2 else { return nil }
        
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let rest = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
        
        let components = rest.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= 2 else { return nil }
        
        let type = components[0]
        var proxies: [String] = []
        var url: String?
        var interval: Int?
        
        for i in 1..<components.count {
            let item = components[i]
            if item.contains("=") {
                let kv = item.components(separatedBy: "=")
                if kv.count == 2 {
                    let key = kv[0].trimmingCharacters(in: .whitespaces)
                    let value = kv[1].trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "url":
                        url = value
                    case "interval":
                        interval = Int(value)
                    default:
                        break
                    }
                }
            } else {
                proxies.append(item)
            }
        }
        
        return SurgeProxyGroup(
            name: name,
            type: type,
            proxies: proxies,
            url: url,
            interval: interval
        )
    }
    
    // MARK: - Serialization
    
    private func generateConfigString() -> String {
        var output = ""
        
        // [General] - preserve existing
        output += "[General]\n"
        output += "loglevel = notify\n"
        output += "dns-server = 223.5.5.5, 114.114.114.114\n"
        output += "http-api = 127.0.0.1:19090\n\n"
        
        // [Proxy]
        output += "[Proxy]\n"
        for proxy in proxies {
            output += serializeProxy(proxy) + "\n"
        }
        output += "\n"
        
        // [Proxy Group]
        output += "[Proxy Group]\n"
        for group in proxyGroups {
            output += serializeProxyGroup(group) + "\n"
        }
        output += "\n"
        
        // [Rule]
        output += "[Rule]\n"
        for rule in rules {
            output += rule + "\n"
        }
        
        return output
    }
    
    private func serializeProxy(_ proxy: SurgeProxy) -> String {
        var parts = [proxy.type, proxy.server, String(proxy.port)]
        
        if let uuid = proxy.uuid, !uuid.isEmpty {
            parts.append("username=\(uuid)")
        }
        if let password = proxy.password, !password.isEmpty {
            parts.append("password=\(password)")
        }
        if let encryption = proxy.encryption, !encryption.isEmpty {
            parts.append("encrypt-method=\(encryption)")
        }
        if proxy.ws {
            parts.append("ws=true")
        }
        if let wsPath = proxy.wsPath, !wsPath.isEmpty {
            parts.append("ws-path=\(wsPath)")
        }
        if proxy.tls {
            parts.append("tls=true")
        }
        if let sni = proxy.sni, !sni.isEmpty {
            parts.append("sni=\(sni)")
        }
        if proxy.skipCertVerify {
            parts.append("skip-cert-verify=true")
        }
        if let flow = proxy.flow, !flow.isEmpty {
            parts.append("flow=\(flow)")
        }
        
        for (key, value) in proxy.extra {
            parts.append("\(key)=\(value)")
        }
        
        return "\(proxy.name) = \(parts.joined(separator: ", "))"
    }
    
    private func serializeProxyGroup(_ group: SurgeProxyGroup) -> String {
        var parts = [group.type] + group.proxies
        
        if let url = group.url {
            parts.append("url=\(url)")
        }
        if let interval = group.interval {
            parts.append("interval=\(interval)")
        }
        
        return "\(group.name) = \(parts.joined(separator: ", "))"
    }
    
    // MARK: - CRUD Operations
    
    func addProxy(_ proxy: SurgeProxy) {
        proxies.append(proxy)
        saveConfig()
    }
    
    func updateProxy(_ proxy: SurgeProxy) {
        if let index = proxies.firstIndex(where: { $0.name == proxy.name }) {
            proxies[index] = proxy
            saveConfig()
        }
    }
    
    func deleteProxy(name: String) {
        proxies.removeAll { $0.name == name }
        saveConfig()
    }
    
    func addProxyGroup(_ group: SurgeProxyGroup) {
        proxyGroups.append(group)
        saveConfig()
    }
    
    func updateProxyGroup(_ group: SurgeProxyGroup) {
        if let index = proxyGroups.firstIndex(where: { $0.name == group.name }) {
            proxyGroups[index] = group
            saveConfig()
        }
    }
    
    func deleteProxyGroup(name: String) {
        proxyGroups.removeAll { $0.name == name }
        saveConfig()
    }
}

// MARK: - Surge Proxy Model

struct SurgeProxy: Identifiable {
    var id: String { name }
    var name: String
    var type: String
    var server: String
    var port: Int
    
    // Common
    var uuid: String?
    var password: String?
    var encryption: String?
    
    // WebSocket
    var ws: Bool = false
    var wsPath: String?
    var wsHeaders: [String: String]?
    
    // TLS
    var tls: Bool = false
    var sni: String?
    var skipCertVerify: Bool = false
    
    // VLESS specific
    var flow: String?
    
    // Hysteria2 specific
    var uploadSpeed: Int?
    var downloadSpeed: Int?
    
    // Extra parameters
    var extra: [String: String] = [:]
    
    // Status (runtime only)
    var latency: Int?
    var testStatus: ProxyTestStatus = .idle
}

// MARK: - Surge Proxy Group Model

struct SurgeProxyGroup: Identifiable {
    var id: String { name }
    var name: String
    var type: String  // select, url-test, fallback, relay, smart
    var proxies: [String]
    var url: String?
    var interval: Int?
    
    // Runtime
    var currentSelection: String?
    
    var isChain: Bool { type == "relay" }
    var isAutoTest: Bool { type == "url-test" }
    var isManual: Bool { type == "select" }
    var isSmart: Bool { type == "smart" }
    
    var displayType: String {
        switch type {
        case "select": return "Manual Selection Group"
        case "url-test": return "Automatic Testing Group"
        case "fallback": return "Fallback Group"
        case "relay": return "Chain Proxy"
        case "smart": return "Smart Group"
        default: return type
        }
    }
    
    var emoji: String {
        switch type {
        case "select": return "📋"
        case "url-test": return "⚡"
        case "fallback": return "🔄"
        case "relay": return "🔗"
        case "smart": return "🧠"
        default: return "📁"
        }
    }
}

// MARK: - Proxy Test Status

enum ProxyTestStatus {
    case idle
    case testing
    case success
    case failed
}

