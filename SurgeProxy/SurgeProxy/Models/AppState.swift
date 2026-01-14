//
//  AppState.swift
//  SurgeProxy
//
//  Shared application state for cross-view synchronization
//

import Foundation
import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var proxyMode: PolicyMode = .ruleBased
    
    private init() {
        // Load saved mode from UserDefaults
        if let savedMode = UserDefaults.standard.string(forKey: "ProxyMode"),
           let mode = PolicyMode(rawValue: savedMode) {
            proxyMode = mode
        }
    }
    
    func setProxyMode(_ mode: PolicyMode) {
        proxyMode = mode
        // Save to UserDefaults
        UserDefaults.standard.set(mode.rawValue, forKey: "ProxyMode")
    }
}
