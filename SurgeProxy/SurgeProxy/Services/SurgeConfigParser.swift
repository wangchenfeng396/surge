//
//  SurgeConfigParser.swift
//  SurgeProxy
//
//  Parser for Surge configuration format
//

import Foundation

class SurgeConfigParser {
    
    // Parse complete Surge config file
    static func parse(_ content: String) -> (
        general: GeneralConfig?,
        proxies: [EnhancedProxyServer],
        groups: [ProxyGroup],
        rules: [ProxyRule],
        urlRewrites: [URLRewriteRule],
        mitm: MITMConfig?
    ) {
        var general: GeneralConfig?
        var proxies: [EnhancedProxyServer] = []
        var groups: [ProxyGroup] = []
        var rules: [ProxyRule] = []
        var urlRewrites: [URLRewriteRule] = []
        var mitm: MITMConfig?
        
        let sections = parseSections(content)
        
        if let generalSection = sections["General"] {
            general = parseGeneral(generalSection)
        }
        
        if let proxySection = sections["Proxy"] {
            proxies = parseProxies(proxySection)
        }
        
        if let groupSection = sections["Proxy Group"] {
            groups = parseProxyGroups(groupSection)
        }
        
        if let ruleSection = sections["Rule"] {
            rules = parseRules(ruleSection)
        }
        
        if let rewriteSection = sections["URL Rewrite"] {
            urlRewrites = parseURLRewrites(rewriteSection)
        }
        
        if let mitmSection = sections["MITM"] {
            mitm = parseMITM(mitmSection)
        }
        
        return (general, proxies, groups, rules, urlRewrites, mitm)
    }
    
    // Parse sections from config
    private static func parseSections(_ content: String) -> [String: [String]] {
        var sections: [String: [String]] = [:]
        var currentSection: String?
        var currentLines: [String] = []
        
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Check for section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                // Save previous section
                if let section = currentSection {
                    sections[section] = currentLines
                }
                
                // Start new section
                currentSection = String(trimmed.dropFirst().dropLast())
                currentLines = []
            } else if currentSection != nil {
                currentLines.append(trimmed)
            }
        }
        
        // Save last section
        if let section = currentSection {
            sections[section] = currentLines
        }
        
        return sections
    }
    
    // Parse [General] section
    private static func parseGeneral(_ lines: [String]) -> GeneralConfig {
        var config = GeneralConfig()
        
        for line in lines {
            let parts = line.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            
            let key = parts[0]
            let value = parts[1...].joined(separator: "=")
            
            switch key {
            case "test-timeout":
                config.testTimeout = Int(value) ?? 10
            case "udp-priority":
                config.udpPriority = value == "true"
            case "internet-test-url":
                config.internetTestURL = value
            case "proxy-test-url":
                config.proxyTestURL = value
            case "geoip-maxmind-url":
                config.geoipMaxmindURL = value
            case "ipv6":
                config.ipv6 = value == "true"
            case "dns-server":
                config.dnsServers = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "encrypted-dns-server":
                config.encryptedDNSServers = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "loglevel":
                config.loglevel = value
            default:
                break
            }
        }
        
        return config
    }
    
    // Parse [Proxy] section
    private static func parseProxies(_ lines: [String]) -> [EnhancedProxyServer] {
        var proxies: [EnhancedProxyServer] = []
        
        for line in lines {
            let parts = line.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            
            let name = parts[0]
            let config = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            guard config.count >= 3 else { continue }
            
            let typeStr = config[0]
            let server = config[1]
            let port = Int(config[2]) ?? 0
            
            var proxy = EnhancedProxyServer(
                name: name,
                proxyProtocol: ProxyProtocol(rawValue: typeStr) ?? .http,
                server: server,
                port: port
            )
            
            // Parse additional parameters
            for param in config.dropFirst(3) {
                let kv = param.components(separatedBy: "=")
                guard kv.count == 2 else { continue }
                
                let key = kv[0].trimmingCharacters(in: .whitespaces)
                let value = kv[1].trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "username":
                    proxy.username = value
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
                case "tfo":
                    proxy.tfo = value == "true"
                default:
                    break
                }
            }
            
            proxies.append(proxy)
        }
        
        return proxies
    }
    
    // Parse [Proxy Group] section
    private static func parseProxyGroups(_ lines: [String]) -> [ProxyGroup] {
        var groups: [ProxyGroup] = []
        
        for line in lines {
            let parts = line.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            
            let name = parts[0]
            let config = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            guard !config.isEmpty else { continue }
            
            let typeStr = config[0]
            
            var group = ProxyGroup(name: name, type: typeStr, proxies: [])
            
            // Parse proxies and parameters
            for item in config.dropFirst() {
                if item.contains("=") {
                    let kv = item.components(separatedBy: "=")
                    if kv.count == 2 {
                        let key = kv[0].trimmingCharacters(in: .whitespaces)
                        let value = kv[1].trimmingCharacters(in: .whitespaces)
                        
                        switch key {
                        case "url":
                            group.testURL = value
                        case "interval":
                            group.interval = Int(value)
                        case "policy-regex-filter":
                            group.policyRegexFilter = value
                        default:
                            break
                        }
                    }
                } else {
                    group.proxies.append(item)
                }
            }
            
            groups.append(group)
        }
        
        return groups
    }
    
    // Parse [Rule] section
    private static func parseRules(_ lines: [String]) -> [ProxyRule] {
        var rules: [ProxyRule] = []
        
        for line in lines {
            let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            
            let typeStr = parts[0]
            let value = parts[1]
            let policy = parts.count > 2 ? parts[2] : "DIRECT"
            
            let rule = ProxyRule(
                enabled: true,
                type: typeStr,
                value: value,
                policy: policy
            )
            
            rules.append(rule)
        }
        
        return rules
    }
    
    // Parse [URL Rewrite] section
    private static func parseURLRewrites(_ lines: [String]) -> [URLRewriteRule] {
        var rewrites: [URLRewriteRule] = []
        
        for line in lines {
            let parts = line.components(separatedBy: " ").filter { !$0.isEmpty }
            guard parts.count >= 3 else { continue }
            
            let pattern = parts[0]
            let replacement = parts[1]
            let typeStr = parts[2]
            
            let type: URLRewriteRule.RewriteType
            switch typeStr {
            case "302":
                type = .redirect302
            case "307":
                type = .redirect307
            case "reject":
                type = .reject
            default:
                type = .redirect302
            }
            
            let rewrite = URLRewriteRule(
                enabled: true,
                pattern: pattern,
                replacement: replacement,
                type: type
            )
            
            rewrites.append(rewrite)
        }
        
        return rewrites
    }
    
    // Parse [MITM] section
    private static func parseMITM(_ lines: [String]) -> MITMConfig {
        var config = MITMConfig()
        
        for line in lines {
            let parts = line.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }
            
            let key = parts[0]
            let value = parts[1]
            
            switch key {
            case "skip-server-cert-verify":
                config.skipServerCertVerify = value == "true"
            case "tcp-connection":
                config.tcpConnection = value == "true"
            case "h2":
                config.h2 = value == "true"
            case "hostname":
                config.hostname = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "ca-passphrase":
                config.caPassphrase = value
            case "ca-p12":
                config.caP12 = value
            default:
                break
            }
        }
        
        return config
    }
}
