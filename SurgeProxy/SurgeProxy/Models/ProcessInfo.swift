//
//  ProcessInfo.swift
//  SurgeProxy
//
//  Model for process information
//

import Foundation

struct NetworkProcessInfo: Identifiable, Codable {
    let id = UUID()
    let pid: Int
    let name: String
    var uploadBytes: UInt64
    var downloadBytes: UInt64
    var connections: Int
    var lastActive: Date
    
    enum CodingKeys: String, CodingKey {
        case pid, name
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
        case connections
        case lastActive = "last_active"
    }
}
