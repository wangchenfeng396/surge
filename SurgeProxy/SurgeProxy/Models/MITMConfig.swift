//
//  MITMConfig.swift
//  SurgeProxy
//
//  MITM configuration model
//

import Foundation

struct MITMConfig: Codable {
    var enabled: Bool?
    var skipServerCertVerify: Bool?
    var tcpConnection: Bool?
    var h2: Bool?
    var hostname: [String]?
    var hostnameDisabled: [String]?
    var autoQuicBlock: Bool?
    var caPassphrase: String?
    var caP12: String?
    
    enum CodingKeys: String, CodingKey {
        case enabled
        case skipServerCertVerify = "skip_server_cert_verify"
        case tcpConnection = "tcp_connection"
        case h2
        case hostname
        case hostnameDisabled = "hostname_disabled"
        case autoQuicBlock = "auto_quic_block"
        case caPassphrase = "ca_passphrase"
        case caP12 = "ca_p12"
    }
}
