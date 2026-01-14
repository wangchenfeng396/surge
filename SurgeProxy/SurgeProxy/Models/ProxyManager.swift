//
//  ProxyManager.swift
//  SurgeProxy
//
//  Manages the Python proxy server process and system proxy configuration
//

import Foundation
import Combine

class ProxyManager: ObservableObject {
    @Published var isRunning = false
    @Published var config: ProxyConfig
    @Published var logs: [LogEntry] = []
    @Published var connectionCount = 0
    @Published var startTime: Date?
    @Published var systemProxyEnabled = false
    @Published var enhancedMode = false
    @Published var httpProxyEnabled = false
    @Published var externalIP = "Not available"
    @Published var devices: [DeviceInfo] = []
    @Published var processes: [NetworkProcessInfo] = []
    @Published var stats: NetworkStats?
    @Published var uploadHistory: [Double] = []
    @Published var downloadHistory: [Double] = []
    @Published var processCount = 0
    @Published var deviceCount = 0
    @Published var totalTrafficKB = 0
    
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var configFileURL: URL?
    
    init() {
        self.config = ProxyConfig.loadFromUserDefaults()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartProxy),
            name: NSNotification.Name("StartProxy"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStopProxy),
            name: NSNotification.Name("StopProxy"),
            object: nil
        )
    }
    
    @objc private func handleStartProxy() {
        startProxy()
    }
    
    @objc private func handleStopProxy() {
        stopProxy()
    }
    
    func startProxy() {
        guard !isRunning else { return }
        
        do {
            // Create temporary config file
            let tempDir = FileManager.default.temporaryDirectory
            configFileURL = tempDir.appendingPathComponent("surge_config.json")
            try config.save(to: configFileURL!)
            
            // Find Python 3
            let pythonPath = findPython3()
            
            // Get the proxy_server.py path
            let serverScriptPath = getProxyServerPath()
            
            // Create process
            process = Process()
            process?.executableURL = URL(fileURLWithPath: pythonPath)
            process?.arguments = [serverScriptPath, configFileURL!.path]
            process?.currentDirectoryURL = URL(fileURLWithPath: getResourcesDirectory())
            
            // Setup pipes for output
            outputPipe = Pipe()
            errorPipe = Pipe()
            process?.standardOutput = outputPipe
            process?.standardError = errorPipe
            
            // Read output
            outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    DispatchQueue.main.async {
                        self?.parseLog(output)
                    }
                }
            }
            
            errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let error = String(data: data, encoding: .utf8), !error.isEmpty {
                    DispatchQueue.main.async {
                        self?.addLog(error, level: .error)
                    }
                }
            }
            
            // Start process
            try process?.run()
            
            DispatchQueue.main.async {
                self.isRunning = true
                self.startTime = Date()
                self.addLog("Proxy server started on \(self.config.host):\(self.config.port)", level: .info)
            }
            
        } catch {
            addLog("Failed to start proxy: \(error.localizedDescription)", level: .error)
        }
    }
    
    func stopProxy() {
        guard isRunning else { return }
        
        process?.terminate()
        process = nil
        
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        
        if systemProxyEnabled {
            disableSystemProxy()
        }
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.startTime = nil
            self.addLog("Proxy server stopped", level: .info)
        }
    }
    
    func restartProxy() {
        stopProxy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startProxy()
        }
    }
    
    func updateConfig(_ newConfig: ProxyConfig) {
        config = newConfig
        config.saveToUserDefaults()
        
        if isRunning {
            restartProxy()
        }
    }
    
    func enableSystemProxy() {
        let port = String(config.port)
        
        // Get active network service
        guard let service = getActiveNetworkService() else {
            addLog("Failed to detect active network service", level: .error)
            return
        }
        
        // Set HTTP proxy
        let httpResult = shell("networksetup -setwebproxy '\(service)' 127.0.0.1 \(port)")
        let httpsResult = shell("networksetup -setsecurewebproxy '\(service)' 127.0.0.1 \(port)")
        
        if httpResult.success && httpsResult.success {
            systemProxyEnabled = true
            addLog("System proxy enabled", level: .info)
        } else {
            addLog("Failed to enable system proxy", level: .error)
        }
    }
    
    func disableSystemProxy() {
        guard let service = getActiveNetworkService() else { return }
        
        shell("networksetup -setwebproxystate '\(service)' off")
        shell("networksetup -setsecurewebproxystate '\(service)' off")
        
        systemProxyEnabled = false
        addLog("System proxy disabled", level: .info)
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func findPython3() -> String {
        let paths = ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/bin/python3" // Default fallback
    }
    
    private func getProxyServerPath() -> String {
        // First try to find it in the app bundle
        if let bundlePath = Bundle.main.resourcePath {
            let serverPath = bundlePath + "/proxy_server.py"
            if FileManager.default.fileExists(atPath: serverPath) {
                return serverPath
            }
        }
        
        // Fallback to the original location
        let projectPath = "/Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/proxy_server.py"
        return projectPath
    }
    
    private func getResourcesDirectory() -> String {
        if let bundlePath = Bundle.main.resourcePath {
            return bundlePath
        }
        return "/Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge"
    }
    
    private func getActiveNetworkService() -> String? {
        let result = shell("networksetup -listallnetworkservices")
        guard result.success else { return nil }
        
        let services = result.output.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
        
        // Try to find Wi-Fi or Ethernet
        for service in services {
            if service.contains("Wi-Fi") || service.contains("Ethernet") {
                return service
            }
        }
        
        return services.first
    }
    
    private func shell(_ command: String) -> (output: String, success: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (output, task.terminationStatus == 0)
        } catch {
            return ("", false)
        }
    }
    
    private func parseLog(_ output: String) {
        let lines = output.components(separatedBy: "\n")
        for line in lines where !line.isEmpty {
            if line.contains("ERROR") {
                addLog(line, level: .error)
            } else if line.contains("WARNING") {
                addLog(line, level: .warning)
            } else if line.contains("INFO") {
                addLog(line, level: .info)
                
                // Count connections
                if line.contains("HTTP:") || line.contains("HTTPS:") {
                    connectionCount += 1
                }
            } else {
                addLog(line, level: .debug)
            }
        }
    }
    
    private func addLog(_ message: String, level: LogLevel) {
        let entry = LogEntry(message: message, level: level)
        logs.append(entry)
        
        // Keep only last 1000 logs
        if logs.count > 1000 {
            logs.removeFirst(logs.count - 1000)
        }
    }
}

// MARK: - Log Entry Model

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
    let level: LogLevel
}

enum LogLevel {
    case debug, info, warning, error
    
    var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "primary"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .debug: return "ant.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}
