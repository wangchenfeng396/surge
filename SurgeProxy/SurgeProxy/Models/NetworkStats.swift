//
//  NetworkStats.swift
//  SurgeProxy
//
//  Network statistics model for sing-box API responses
//

import Foundation

struct NetworkStats: Codable {
    let uploadBytes: UInt64
    let downloadBytes: UInt64
    let uploadSpeed: UInt64
    let downloadSpeed: UInt64
    let activeConns: Int
    let totalConns: UInt64
    let latency: LatencyInfo?
    let trafficHistory: [TrafficPoint]?
    
    // Computed properties for backward compatibility
    var upload: Int64 { Int64(uploadBytes) }
    var download: Int64 { Int64(downloadBytes) }
    var connections: Int { activeConns }
    var processCount: Int { 0 }
    var deviceCount: Int { 0 }
    var totalTraffic: Int { Int(uploadBytes + downloadBytes) }
    
    enum CodingKeys: String, CodingKey {
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
        case uploadSpeed = "upload_speed"
        case downloadSpeed = "download_speed"
        case activeConns = "active_connections"
        case totalConns = "total_connections"
        case latency
        case trafficHistory = "traffic_history"
    }
}

struct ProxyStatsDetail: Codable {
    let name: String
    let upload: Int64
    let download: Int64
    let latency: Int
    let alive: Bool
}

struct LatencyInfo: Codable {
    let router: Int
    let dns: Int
    let proxy: Int
}

struct TrafficPoint: Codable {
    let timestamp: Date 
    let upload: UInt64
    let download: UInt64
    
    // Go default JSON encoding for time.Time is RFC3339 string
}
