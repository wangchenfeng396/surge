//
//  GoProxyManager.swift
//  SurgeProxy
//
//  ProxyManager with Go backend integration
//

import Foundation
import Combine
import Network
import AppKit
import CoreWLAN


enum ProxyError: LocalizedError {
    case backendNotReady
    
    var errorDescription: String? {
        switch self {
        case .backendNotReady:
            return "Backend service is not ready"
        }
    }
}

class GoProxyManager: ObservableObject {

    @Published var isRunning = false
    @Published var isStarting = false
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
    @Published var selectedProxy: String? // Currently selected proxy in Proxy group
    
    // Network Info
    @Published var networkType: String = "Unknown"
    @Published var networkName: String? = nil
    
    // Latency Info
    @Published var routerLatency: Int = 0
    @Published var dnsLatency: Int = 0
    @Published var proxyLatency: String = "N/A"
    @Published var isMeasuringLatency = false
    
    // Mode Management
    @Published var mode: PolicyMode = .ruleBased {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "ProxyMode")
            setBackendMode(mode)
        }
    }
    
    private var goProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    let backendManager = BackendProcessManager()
    private let apiClient = APIClient.shared
    private let wsClient = WebSocketClient()
    
    private var statsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.config = ProxyConfig.loadFromUserDefaults()
        
        // Load saved mode
        if let savedMode = UserDefaults.standard.string(forKey: "ProxyMode"),
           let m = PolicyMode(rawValue: savedMode) {
            self.mode = m
        }
        
        // Initialize API Client port
        apiClient.setPort(config.apiPort)
        wsClient.setPort(config.apiPort)
        
        setupNotifications()
        setupWebSocketObserver()
        
        // Auto-start backend on app launch
        startProxy()
        
        // Start network monitoring
        updateNetworkInfo()
        // Note: Latency timer is now started in actuallyStartProxy after delay
    }
    
    deinit {
        Task {
            await backendManager.stopBackend()
        }
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppTermination),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private func setupWebSocketObserver() {
        wsClient.$latestStats
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.updateWithStats(stats)
            }
            .store(in: &cancellables)
    }
    
    @objc private func handleStartProxy() {
        startProxy()
    }
    
    @objc private func handleStopProxy() {
        stopProxy()
    }
    
    @objc private func handleAppTermination() {
        // Force synchronous cleanup on app termination
        print("GoProxyManager: Handling app termination cleanup")
        backendManager.terminate()
        // Small delay to ensure signal is sent
        usleep(100000) // 0.1s
    }
    
    func startProxy() {
        guard !isRunning && !isStarting else { return }
        
        isStarting = true
        
        Task {
            // Ensure port is set correctly before starting
            apiClient.setPort(config.apiPort)
            
            do {
                // Start backend first if not running
                if !backendManager.isRunning {
                    try await backendManager.startBackend()
                }
                
                // Then start proxy features
                await MainActor.run {
                    self.actuallyStartProxy()
                }
            } catch {
                await MainActor.run {
                    self.isStarting = false
                    self.logs.append(LogEntry(
                        message: "Failed to start backend: \(error.localizedDescription)",
                        level: .error
                    ))
                }
            }
        }
    }
    
    private func actuallyStartProxy() {
        guard !isRunning else {
            isStarting = false
            return
        }
        
        Task {
            do {
                // Ensure backend is running via the shared manager
                // Note: It should have been started by init(), but we check again
                if !backendManager.isRunning {
                     try await backendManager.startBackend()
                }
                
                // Apply current mode
                setBackendMode(self.mode)
                
                // Connect WebSocket for real-time updates
                wsClient.connect()
                
                // Inject 3-second delay to allow backend to fully initialize
                // This prevents "Connection refused" or race conditions on first probe
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                
                // Start periodic stats fetching
                startStatsTimer()
                
                // Start Latency probing now that backend is ready
                startLatencyTimer()
                
                await MainActor.run {
                    self.isRunning = true
                    self.startTime = Date()
                    self.addLog("Proxy server ready", level: .info)
                }
            } catch {
                await MainActor.run {
                    self.addLog("Failed to ensure proxies ready: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    func stopProxy() {
        guard isRunning else { return }
        
        // Stop WebSocket
        wsClient.disconnect()
        
        // Stop stats timer
        statsTimer?.invalidate()
        statsTimer = nil
        
        // Note: We DO NOT stop the backend process anymore.
        // The backend backendManager handles the persistent process.
        // We only stop the "Proxy Mode" logic (WebSocket, stats, system proxy setting).
        
        if systemProxyEnabled {
            disableSystemProxy()
        }
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.startTime = nil
            self.addLog("Proxy monitoring stopped (Backend kept running)", level: .info)
        }
    }
    
    private func setBackendMode(_ mode: PolicyMode) {
        Task {
            do {
                try await apiClient.setProxyMode(mode.apiValue)
                await MainActor.run {
                    self.addLog("Outbound mode set to: \(mode.apiValue)", level: .info)
                }
            } catch {
                await MainActor.run {
                    self.addLog("Failed to set proxy mode: \(error.localizedDescription)", level: .warning)
                }
            }
        }
    }
    
    // MARK: - Go Backend Management
    
    private func startGoBackend() throws {
        let goBinaryPath = findGoBinary()
        
        goProcess = Process()
        goProcess?.executableURL = URL(fileURLWithPath: goBinaryPath)
        goProcess?.currentDirectoryURL = URL(fileURLWithPath: getGoProjectDirectory())
        
        // Setup pipes for output
        outputPipe = Pipe()
        errorPipe = Pipe()
        goProcess?.standardOutput = outputPipe
        goProcess?.standardError = errorPipe
        
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
        
        try goProcess?.run()
        addLog("Go backend process started", level: .info)
    }
    
    private func findGoBinary() -> String {
        // First try bundle resources (for production)
        if let bundlePath = Bundle.main.resourcePath {
            let bundleBinary = bundlePath + "/surge"
            if FileManager.default.fileExists(atPath: bundleBinary) {
                addLog("Using bundled surge binary: \(bundleBinary)", level: .info)
                return bundleBinary
            }
        }
        
        // Fallback to development path
        let projectPath = "/Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/surge"
        if FileManager.default.fileExists(atPath: projectPath) {
            addLog("Using development surge binary: \(projectPath)", level: .info)
            return projectPath
        }
        
        addLog("Warning: surge binary not found, using project path", level: .warning)
        return projectPath
    }
    
    private func getGoProjectDirectory() -> String {
        // Use app support directory for production
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            let configDir = appSupport.appendingPathComponent("SurgeProxy")
            
            // Create directory if needed
            try? FileManager.default.createDirectory(
                at: configDir,
                withIntermediateDirectories: true
            )
            
            return configDir.path
        }
        
        // Fallback to development path
        return "/Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go"
    }
    
    private func waitForBackend() async throws {
        // Wait up to 5 seconds for backend to be ready
        for _ in 0..<50 {
            if await apiClient.checkHealth() {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        throw ProxyError.backendNotReady
    }
    
    // MARK: - Stats Management
    
    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchStats()
        }
    }
    
    private func fetchStats() {
        Task {
            do {
                let stats = try await apiClient.fetchStats()
                await MainActor.run {
                    self.updateWithStats(stats)
                }
            } catch {
                // Silently fail - WebSocket will provide updates
            }
        }
    }
    
    private func updateWithStats(_ stats: NetworkStats) {
        self.stats = stats
        
        // Update upload/download history
        if uploadHistory.count > 100 {
            uploadHistory.removeFirst()
        }
        uploadHistory.append(Double(stats.uploadSpeed))
        
        if downloadHistory.count > 100 {
            downloadHistory.removeFirst()
        }
        downloadHistory.append(Double(stats.downloadSpeed))
        
        // Update counts
        processCount = stats.processCount
        deviceCount = stats.deviceCount
        totalTrafficKB = stats.totalTraffic / 1024
        
        // Fetch detailed data periodically
        if Int(Date().timeIntervalSince1970) % 5 == 0 {
            fetchProcessesAndDevices()
        }
    }
    
    private func fetchProcessesAndDevices() {
        Task {
            do {
                async let processesTask = apiClient.fetchProcesses()
                async let devicesTask = apiClient.fetchDevices()
                
                let (processes, devices) = try await (processesTask, devicesTask)
                
                await MainActor.run {
                    self.processes = processes
                    self.devices = devices
                }
            } catch {
                // Silently fail
            }
        }
    }
    
    // MARK: - System Proxy Management
    
    func enableSystemProxy() {
        Task {
            do {
                try await apiClient.enableSystemProxy(port: config.port)
                await MainActor.run {
                    self.systemProxyEnabled = true
                    self.addLog("System proxy enabled via Backend", level: .info)
                }
                // Refresh status to confirm
                refreshSystemStatus()
            } catch {
                await MainActor.run {
                    self.addLog("Failed to enable system proxy: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    func disableSystemProxy() {
        Task {
            do {
                try await apiClient.disableSystemProxy()
                await MainActor.run {
                    self.systemProxyEnabled = false
                    self.addLog("System proxy disabled via Backend", level: .info)
                }
                // Refresh status to confirm
                refreshSystemStatus()
            } catch {
                await MainActor.run {
                    self.addLog("Failed to disable system proxy: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    func refreshSystemStatus() {
        Task {
            do {
                let status = try await apiClient.fetchSystemProxyStatus()
                await MainActor.run {
                    self.systemProxyEnabled = status.enabled
                    self.selectedProxy = status.selectedProxy
                }
            } catch {
                // Silently fail or log debug
                print("Failed to fetch system status: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getActiveNetworkService() -> String? {
        let result = shell("networksetup -listallnetworkservices")
        guard result.success else { return nil }
        
        let services = result.output.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
        
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
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
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
    
    // MARK: - Network & Latency Logic
    
    func updateNetworkInfo() {
        Task {
            // 1. Get all hardware ports to map Device <-> Name
            let portResult = shell("networksetup -listallhardwareports")
            var deviceMap: [String: String] = [:] // en0 -> Wi-Fi
            
            let portLines = portResult.output.components(separatedBy: "\n")
            var currentName = ""
            for line in portLines {
                if line.hasPrefix("Hardware Port:") {
                    currentName = line.replacingOccurrences(of: "Hardware Port:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("Device:") {
                    let device = line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces)
                    if !currentName.isEmpty && !device.isEmpty {
                        deviceMap[device] = currentName
                    }
                    currentName = ""
                }
            }
            
            // 2. Iterate map to find active interface with IP
            var activeType = "No Network"
            var activeName: String? = nil
            
            // Priority: Wi-Fi > Ethernet > Others
            // We check them all, but sort/prioritize found ones? 
            // Better: Check active status via ifconfig for each known device
            
            for (device, name) in deviceMap {
                let ifconfig = shell("ifconfig \(device)")
                if ifconfig.success && ifconfig.output.contains("status: active") { // && ifconfig.output.contains("inet ")
                     // "inet " check ensures it has IPv4. "status: active" means cable plugged/connected.
                     // VPNs usually don't show up in listallhardwareports, so this filters them out naturally.
                    
                    if name.contains("Wi-Fi") {
                        activeType = "Wi-Fi"
                        // Try get SSID
                        if let wifi = CWWiFiClient.shared().interface(), wifi.powerOn() {
                            activeName = wifi.ssid() ?? "Wi-Fi"
                        } else {
                            activeName = "Wi-Fi"
                        }
                        break // Found Wi-Fi, stop
                    } else if name.contains("Ethernet") || name.contains("Thunderbolt") {
                        activeType = "Ethernet"
                        activeName = nil // Ethernet usually doesn't have a name
                         // Don't break yet, prefer Wi-Fi if both active? Actually Ethernet usually priority.
                        // But user specifically asked about "Wi-Fi showing as Ethernet".
                        // If both active, macOS uses Service Order.
                        // Let's assume if Wi-Fi is associtaed, show Wi-Fi.
                    }
                }
            }
            // If we found Ethernet but loop didn't break for Wi-Fi, we might have active Ethernet.
            // Let's refine: Search specifically for known types
            
            // Re-scan with priority
            // Check Wi-Fi explicitly first
            if let wifiDevice = deviceMap.first(where: { $0.value.contains("Wi-Fi") })?.key {
                 let res = shell("ifconfig \(wifiDevice)")
                 // Ensure it has IP logic or just status active?
                 // status: active is key
                 if res.output.contains("status: active") {
                      activeType = "Wi-Fi"
                      if let wifi = CWWiFiClient.shared().interface(), wifi.powerOn() {
                          activeName = wifi.ssid() ?? "Wi-Fi"
                      }
                 }
            }
            
            // If not Wi-Fi, check Ethernets
            if activeType == "No Network" {
                 for (device, name) in deviceMap {
                     if name.contains("Ethernet") || name.contains("Thunderbolt") || name.contains("USB") {
                         let res = shell("ifconfig \(device)")
                         if res.output.contains("status: active") {
                             activeType = "Ethernet"
                             break
                         }
                     }
                 }
            }

            await MainActor.run {
                self.networkType = activeType
                self.networkName = activeName
            }
        }
    }
    
    private func startLatencyTimer() {
        // Measure immediately
        measureLatency()
        
        // Then every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.measureLatency()
        }
    }
    
    func measureLatency() {
        guard !isMeasuringLatency else { return }
        isMeasuringLatency = true
        
        Task {
            // 1. Router Latency (Shell Ping)
            // Using system ping avoids "Connection Refused" logs and is more accurate for ICMP
            do {
                let (gateway, _) = try await apiClient.fetchSystemGateway()
                
                // Ping timeout 1s, count 1
                let pingResult = shell("ping -c 1 -t 1 \(gateway)")
                
                var routerMs = 0
                if pingResult.success {
                    // Parse: time=3.456 ms
                    if let range = pingResult.output.range(of: "time="),
                       let msEnd = pingResult.output.range(of: " ms", range: range.upperBound..<pingResult.output.endIndex) {
                        let msStr = String(pingResult.output[range.upperBound..<msEnd.lowerBound])
                        if let msDouble = Double(msStr) {
                            routerMs = Int(msDouble)
                        }
                    } else if pingResult.output.contains("1 packets received") {
                        // Received but failed to parse time, assume < 1ms
                        routerMs = 1
                    }
                }
                
                await MainActor.run { self.routerLatency = routerMs }
            } catch {
                await MainActor.run { self.routerLatency = 0 }
            }
            
            // 2. DNS Latency (Use Backend API)
            do {
                let dnsResults = try await apiClient.fetchDNSDiagnostics()
                // Take the best (min) latency from valid results
                let validLatencies = dnsResults.values.filter { $0 >= 0 }
                if let minLat = validLatencies.min() {
                     await MainActor.run { self.dnsLatency = minLat }
                } else {
                     await MainActor.run { self.dnsLatency = 0 }
                }
            } catch {
                 await MainActor.run { self.dnsLatency = 0 }
            }
            
            // 3. Internet/Proxy Latency
            // Logic: "N/A" if not system proxy and not enhanced mode
            // BUT user might want to test connectivity even without system proxy set?
            // User requirement: "If unstarted system proxy or enhanced mode, should be N/A. After start read default proxy name."
            
            let shouldMeasure = self.isRunning && (self.systemProxyEnabled || self.enhancedMode)
            
            if !shouldMeasure {
                await MainActor.run {
                    self.proxyLatency = "N/A"
                    self.isMeasuringLatency = false
                }
            } else {
                do {
                    var targetProxy = "DIRECT"
                    
                    switch self.mode {
                    case .direct:
                        targetProxy = "DIRECT"
                    case .ruleBased:
                        // Empty string tells backend to use Rule Engine logic
                        targetProxy = ""
                    case .global:
                        if let currentProxy = self.selectedProxy, !currentProxy.isEmpty {
                            targetProxy = currentProxy
                        } else {
                            // If Global Mode but no proxy selected, auto-select the first available one
                            let proxies = try await apiClient.fetchProxies()
                            if let first = proxies.proxies.first {
                                targetProxy = first.name
                                await MainActor.run {
                                    self.selectedProxy = targetProxy
                                }
                            }
                        }
                    }
                    
                    let result = try await apiClient.testProxyLive(name: targetProxy)
                    
                    await MainActor.run {
                        if let lat = result.latency {
                            self.proxyLatency = "\(lat) ms"
                        } else {
                            self.proxyLatency = "Timeout"
                        }
                        self.isMeasuringLatency = false
                    }
                } catch {
                    await MainActor.run {
                        self.proxyLatency = "Error"
                        self.isMeasuringLatency = false
                    }
                }
            }
        }
    }
    
    
    func clearLogs() {
        logs.removeAll()
    }
    
    // MARK: - Configuration Upload
    
    func uploadSurgeConfig(_ configText: String) {
        Task {
            do {
                try await apiClient.uploadSurgeConfig(configText)
                
                await MainActor.run {
                    self.addLog("Surge configuration uploaded successfully", level: .info)
                }
                
                // Restart proxy to apply new config
                if isRunning {
                    restartProxy()
                }
            } catch {
                await MainActor.run {
                    self.addLog("Failed to upload config: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
    
    func fetchProxyList() {
        Task {
            do {
                let response = try await apiClient.fetchProxies()
                await MainActor.run {
                    self.addLog("Loaded \(response.proxies.count) proxies from backend", level: .info)
                }
            } catch {
                await MainActor.run {
                    self.addLog("Failed to fetch proxies: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }
}
