//
//  EnhancedProxyServer.swift
//  SurgeProxy
//
//  Enhanced proxy server model supporting VMess and advanced protocols
//

import Foundation

enum ProxyProtocol: String, Codable, CaseIterable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"
    case socks5TLS = "SOCKS5-TLS"
    case ssh = "SSH"
    case snell = "SNELL"
    case shadowsocks = "SS"
    case vmess = "VMESS"
    case vless = "VLESS"
    case trojan = "TROJAN"
    case tuic = "TUIC"
    case tuicV5 = "TUIC-V5"
    case hysteria2 = "HYSTERIA2"
    case wireguard = "WIREGUARD"
    
    var displayName: String {
        rawValue
    }
    
    var supportsTLS: Bool {
        switch self {
        case .vmess, .vless, .trojan, .https, .socks5TLS, .tuic, .tuicV5, .hysteria2:
            return true
        default:
            return false
        }
    }
    
    var supportsWebSocket: Bool {
        switch self {
        case .vmess, .vless:
            return true
        default:
            return false
        }
    }
}

struct EnhancedProxyServer: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var proxyProtocol: ProxyProtocol
    var server: String
    var port: Int
    
    // Authentication
    var username: String?
    var password: String?
    
    // Shadowsocks & VMess
    var encryption: String?
    var uuid: String?
    
    // VMess specific
    var vmessAEAD: Bool = true
    var alterId: Int = 0
    
    // WebSocket
    var ws: Bool = false
    var wsPath: String?
    var wsHeaders: [String: String]?
    
    // TLS
    var tls: Bool = false
    var sni: String?
    var skipCertVerify: Bool = false
    
    // Advanced
    var tfo: Bool = false // TCP Fast Open
    var mptcp: Bool = false
    var udpRelay: Bool = false
    
    // Obfs
    var obfs: String?
    var obfsHost: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case proxyProtocol = "type"
        case server, port
        case username, password, encryption, uuid
        case vmessAEAD = "vmess-aead"
        case alterId = "alter-id"
        case ws
        case wsPath = "ws-path"
        case wsHeaders = "ws-headers"
        case tls, sni
        case skipCertVerify = "skip-cert-verify"
        case tfo, mptcp
        case udpRelay = "udp-relay"
        case obfs
        case obfsHost = "obfs-host"
    }
    
    init(id: UUID = UUID(), name: String, proxyProtocol: ProxyProtocol, server: String, port: Int) {
        self.id = id
        self.name = name
        self.proxyProtocol = proxyProtocol
        self.server = server
        self.port = port
    }
}
