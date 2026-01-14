//
//  CaptureRequest.swift
//  SurgeProxy
//
//  Model for captured request/connection
//

import Foundation

struct CaptureRequest: Identifiable, Codable, Hashable {
    let id: String
    let url: String
    let method: String
    let status: Int
    let duration: Double
    let timestamp: Date
    let policy: String
    let rule: String
    let sourceIP: String
    let uploadBytes: UInt64
    let downloadBytes: UInt64
    let failed: Bool
    let notes: String
    
    enum CodingKeys: String, CodingKey {
        case id, url, method, status, duration, timestamp, policy, rule
        case sourceIP = "source_ip"
        case uploadBytes = "upload"
        case downloadBytes = "download"
        case failed, notes
    }
}
