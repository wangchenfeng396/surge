//
//  NetworkMonitor.swift
//  SurgeProxy
//
//  Monitor network changes and connectivity
//

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: String = "Unknown"
    @Published var hasChanged = false
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
                self?.hasChanged = true
                
                // Reset change flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.hasChanged = false
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = "Wi-Fi"
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = "Ethernet"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = "Cellular"
        } else {
            connectionType = "Unknown"
        }
    }
}
