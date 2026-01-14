//
//  ConnectionInfo.swift
//  SurgeProxy
//
//  Model for active connection
//

import Foundation

struct ConnectionInfo: Identifiable, Codable {
    let id: String
    let metadata: Metadata
    let upload: UInt64
    let download: UInt64
    let start_time: Double // Backend returns number (timestamp)
    let rule: String
    let chain: [String]
    
    struct Metadata: Codable {
        let network: String
        let type: String
        let source_ip: String
        let source_port: String
        let destination_ip: String?
        let destination_port: String?
        let host: String
        let process: String
        let process_path: String?
        
        // Helper to get safe process name
        var safeProcess: String {
            return process.isEmpty ? "Unknown" : process
        }
    }
    
    // Computed properties for UI compatibility
    var pid: Int { 0 } // Placeholder, backend doesn't seem to return PID
    var processName: String { metadata.process }
    var sourceIP: String { metadata.source_ip }
    var sourcePort: String { metadata.source_port }
    var targetAddress: String { 
        if !metadata.host.isEmpty { return metadata.host }
        return metadata.destination_ip ?? "Unknown"
    }
    var policy: String { chain.last ?? "Direct" }
    
    // Convert backend timestamp to Date
    var startTime: Date {
        return Date(timeIntervalSince1970: start_time)
    }
    
    var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    var uploadBytes: UInt64 { upload }
    var downloadBytes: UInt64 { download }
}
