//
//  DeviceInfo.swift
//  SurgeProxy
//
//  Model for connected device information
//

import Foundation

struct DeviceInfo: Identifiable, Codable {
    let id = UUID()
    let ip: String
    let mac: String
    var hostname: String
    var uploadBytes: UInt64
    var downloadBytes: UInt64
    var connections: Int
    var firstSeen: Date
    var lastSeen: Date
    
    enum CodingKeys: String, CodingKey {
        case ip, mac, hostname
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
        case connections
        case firstSeen = "first_seen"
        case lastSeen = "last_seen"
    }
}
