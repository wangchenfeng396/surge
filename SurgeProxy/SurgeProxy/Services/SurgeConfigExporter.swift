//
//  SurgeConfigExporter.swift
//  SurgeProxy
//
//  Export configuration to Surge format
//

import Foundation

class SurgeConfigExporter {
    
    // Export complete configuration to Surge format
    static func export(
        general: GeneralConfig,
        proxies: [EnhancedProxyServer],
        groups: [ProxyGroup],
        rules: [ProxyRule],
        urlRewrites: [URLRewriteRule],
        mitm: MITMConfig
    ) -> String {
        var output = ""
        
        output += exportGeneral(general)
        output += "\n"
        output += exportProxies(proxies)
        output += "\n"
        output += exportProxyGroups(groups)
        output += "\n"
        output += exportRules(rules)
        output += "\n"
        output += exportURLRewrites(urlRewrites)
        output += "\n"
        output += exportMITM(mitm)
        
        return output
    }
    
    // Export [General] section
    private static func exportGeneral(_ config: GeneralConfig) -> String {
        var lines = ["[General]"]
        
        lines.append("test-timeout = \(config.testTimeout)")
        lines.append("udp-priority = \(config.udpPriority)")
        lines.append("internet-test-url = \(config.internetTestURL)")
        lines.append("proxy-test-url = \(config.proxyTestURL)")
        lines.append("geoip-maxmind-url = \(config.geoipMaxmindURL)")
        lines.append("ipv6 = \(config.ipv6)")
        lines.append("dns-server = \((config.dnsServers ?? []).joined(separator: ", "))")
        
        if let encryptedServers = config.encryptedDNSServers, !encryptedServers.isEmpty {
            lines.append("encrypted-dns-server = \(encryptedServers.joined(separator: ", "))")
        }
        
        lines.append("show-error-page-for-reject = \(config.showErrorPageForReject ?? true)")
        
        if let skipProxy = config.skipProxy, !skipProxy.isEmpty {
            lines.append("skip-proxy = \(skipProxy.joined(separator: ", "))")
        }
        
        lines.append("allow-wifi-access = \(config.allowWifiAccess ?? false)")
        lines.append("wifi-access-http-port = \(config.wifiAccessHTTPPort ?? 6152)")
        lines.append("wifi-access-socks5-port = \(config.wifiAccessSOCKS5Port ?? 6153)")
        lines.append("allow-hotspot-access = \(config.allowHotspotAccess ?? false)")
        lines.append("wifi-assist = \(config.wifiAssist ?? false)")
        lines.append("http-api-tls = \(config.httpApiTls ?? false)")
        lines.append("http-api-web-dashboard = \(config.httpApiWebDashboard ?? true)")
        lines.append("all-hybrid = \(config.allHybrid ?? false)")
        lines.append("exclude-simple-hostnames = \(config.excludeSimpleHostnames ?? true)")
        lines.append("read-etc-hosts = \(config.readEtcHosts ?? true)")
        lines.append("loglevel = \(config.loglevel ?? "notify")")
        
        if let alwaysRealIP = config.alwaysRealIP, !alwaysRealIP.isEmpty {
            lines.append("always-real-ip = \(alwaysRealIP.joined(separator: ", "))")
        }
        
        lines.append("disable-geoip-db-auto-update = \(config.disableGeoIPDBAutoUpdate ?? false)")
        lines.append("udp-policy-not-supported-behaviour = \(config.udpPolicyNotSupportedBehaviour ?? "reject")")
        
        if let tunIncluded = config.tunIncludedRoutes, !tunIncluded.isEmpty {
            lines.append("tun-included-routes = \(tunIncluded.joined(separator: ", "))")
        }
        
        if let tunExcluded = config.tunExcludedRoutes, !tunExcluded.isEmpty {
            lines.append("tun-excluded-routes = \(tunExcluded.joined(separator: ", "))")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Export [Proxy] section
    private static func exportProxies(_ proxies: [EnhancedProxyServer]) -> String {
        var lines = ["[Proxy]"]
        
        for proxy in proxies {
            var parts = [proxy.proxyProtocol.rawValue, proxy.server, "\(proxy.port)"]
            
            if let username = proxy.username {
                parts.append("username=\(username)")
            }
            
            if let password = proxy.password {
                parts.append("password=\(password)")
            }
            
            if proxy.ws {
                parts.append("ws=true")
                if let wsPath = proxy.wsPath {
                    parts.append("ws-path=\(wsPath)")
                }
            }
            
            if proxy.tls {
                parts.append("tls=true")
                if let sni = proxy.sni {
                    parts.append("sni=\(sni)")
                }
            }
            
            if proxy.skipCertVerify {
                parts.append("skip-cert-verify=true")
            }
            
            if proxy.tfo {
                parts.append("tfo=true")
            }
            
            if proxy.vmessAEAD {
                parts.append("vmess-aead=true")
            }
            
            lines.append("\(proxy.name) = \(parts.joined(separator: ", "))")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Export [Proxy Group] section
    private static func exportProxyGroups(_ groups: [ProxyGroup]) -> String {
        var lines = ["[Proxy Group]"]
        
        for group in groups {
            var parts = [group.type]
            parts.append(contentsOf: group.proxies)
            
            if let testURL = group.testURL {
                parts.append("url=\(testURL)")
            }
            
            if let interval = group.interval {
                parts.append("interval=\(interval)")
            }
            
            if let filter = group.policyRegexFilter {
                parts.append("policy-regex-filter=\(filter)")
            }
            
            if group.noAlert {
                parts.append("no-alert=1")
            }
            
            if group.hidden {
                parts.append("hidden=1")
            }
            
            if group.includeAllProxies {
                parts.append("include-all-proxies=1")
            }
            
            if let path = group.policyPath {
                parts.append("policy-path=\(path)")
            }
            
            lines.append("\(group.name) = \(parts.joined(separator: ", "))")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Export [Rule] section
    private static func exportRules(_ rules: [ProxyRule]) -> String {
        var lines = ["[Rule]"]
        
        for rule in rules where rule.enabled {
            let comment = rule.comment.isEmpty ? "" : " // \(rule.comment)"
            lines.append("\(rule.type),\(rule.value),\(rule.policy)\(comment)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Export [URL Rewrite] section
    private static func exportURLRewrites(_ rewrites: [URLRewriteRule]) -> String {
        var lines = ["[URL Rewrite]"]
        
        for rewrite in rewrites where rewrite.enabled {
            lines.append("\(rewrite.pattern) \(rewrite.replacement) \(rewrite.type.rawValue)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Export [MITM] section
    private static func exportMITM(_ mitm: MITMConfig) -> String {
        var lines = ["[MITM]"]
        
        lines.append("skip-server-cert-verify = \(mitm.skipServerCertVerify)")
        lines.append("tcp-connection = \(mitm.tcpConnection)")
        lines.append("h2 = \(mitm.h2)")
        
        if let hostname = mitm.hostname, !hostname.isEmpty {
            lines.append("hostname = \(hostname.joined(separator: ", "))")
        }
        
        if let disabled = mitm.hostnameDisabled, !disabled.isEmpty {
            lines.append("hostname-disabled = \(disabled.joined(separator: ", "))")
        }
        
        if let autoQuic = mitm.autoQuicBlock, autoQuic {
            lines.append("auto-quic-block = true")
        }
        
        if let passphrase = mitm.caPassphrase {
            lines.append("ca-passphrase = \(passphrase)")
        }
        
        if let p12 = mitm.caP12 {
            lines.append("ca-p12 = \(p12)")
        }
        
        return lines.joined(separator: "\n")
    }
}
