//
//  SystemInfoExporter.swift
//  SurgeProxy
//
//  Export system information and diagnostics
//

import Foundation

class SystemInfoExporter {
    static func exportAsJSON() -> String {
        let info: [String: Any] = [
            "timestamp": Date().ISO8601Format(),
            "network": [
                "type": "Unknown",
                "connected": true
            ],
            "proxy": [
                "mode": UserDefaults.standard.string(forKey: "ProxyMode") ?? "Unknown",
                "profile": UserDefaults.standard.string(forKey: "LastImportedConfigFile") ?? "None"
            ],
            "system": [
                "platform": "macOS",
                "version": ProcessInfo.processInfo.operatingSystemVersionString
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    static func exportAsMarkdown() -> String {
        let mode = UserDefaults.standard.string(forKey: "ProxyMode") ?? "Unknown"
        let profile = UserDefaults.standard.string(forKey: "LastImportedConfigFile") ?? "None"
        
        return """
        # System Information Report
        
        **Generated**: \(Date().formatted())
        
        ## Network
        - Type: Unknown
        - Connected: Yes
        
        ## Proxy Configuration
        - Mode: \(mode)
        - Profile: \(profile)
        
        ## System
        - Platform: macOS
        - Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
    }
}
