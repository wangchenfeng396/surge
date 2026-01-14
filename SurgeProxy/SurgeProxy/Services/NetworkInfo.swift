//
//  NetworkInfo.swift
//  SurgeProxy
//
//  Network information helper for detecting connection type and Wi-Fi SSID
//

import Foundation
import SystemConfiguration
import CoreWLAN

class NetworkInfo: ObservableObject {
    @Published var connectionType: String = "Unknown"
    @Published var wifiName: String? = nil
    
    func updateNetworkInfo() {
        // Get Wi-Fi interface
        let wifiClient = CWWiFiClient.shared()
        if let interface = wifiClient.interface() {
            
            // Check if connected to Wi-Fi
            if let ssid = interface.ssid() {
                connectionType = "Wi-Fi"
                wifiName = ssid
                return
            }
        }
        
        // Check for Ethernet or other connections
        if isEthernetConnected() {
            connectionType = "Ethernet"
            wifiName = nil
        } else {
            connectionType = "Not Connected"
            wifiName = nil
        }
    }
    
    private func isEthernetConnected() -> Bool {
        // Check if any network interface is active
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return false }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            
            // Check for Ethernet interfaces (en0, en1, etc.)
            if name.hasPrefix("en") && !name.contains("awdl") {
                // Check if interface has an IP address
                let flags = Int32(interface.ifa_flags)
                if (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) {
                    return true
                }
            }
        }
        
        return false
    }
    
    var displayText: String {
        if connectionType == "Wi-Fi", let ssid = wifiName {
            return ssid
        }
        return connectionType
    }
}
