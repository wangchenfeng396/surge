//
//  ProxyConfig.swift
//  SurgeProxy
//
//  Application-level proxy configuration
//

import Foundation

struct ProxyConfig: Codable {
    var host: String
    var port: Int
    var apiPort: Int
    var username: String?
    var password: String?
    
    init(host: String = "127.0.0.1", port: Int = 8888, apiPort: Int = 19090, username: String? = nil, password: String? = nil) {
        self.host = host
        self.port = port
        self.apiPort = apiPort
        self.username = username
        self.password = password
    }
    
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "ProxyConfig")
        }
    }
    
    static func loadFromUserDefaults() -> ProxyConfig {
        if let data = UserDefaults.standard.data(forKey: "ProxyConfig"),
           let config = try? JSONDecoder().decode(ProxyConfig.self, from: data) {
            return config
        }
        return ProxyConfig()
    }
}
