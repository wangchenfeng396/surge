//
//  BackendProcessManager.swift
//  SurgeProxy
//
//  Manages Go backend process lifecycle
//

import Foundation

class BackendProcessManager: ObservableObject {
    @Published var isRunning = false
    @Published var lastError: String?
    @Published var backendLogs: [String] = []
    
    private var process: Process?
    private let binaryPath: String
    private let apiBaseURL = "http://localhost:19090"
    
    init() {
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = resourcePath + "/surge-go"
            if FileManager.default.fileExists(atPath: bundlePath) {
                binaryPath = bundlePath
                print("🚀 BackendProcessManager: Configured binary path from bundle: \(binaryPath)")
            } else {
                // Fallback for development
                binaryPath = "/Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/bin/surge-go"
                print("⚠️ BackendProcessManager: Bundle binary not found, using dev path: \(binaryPath)")
            }
        } else {
            binaryPath = "/Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/bin/surge-go"
            print("⚠️ BackendProcessManager: Bundle resource path not found, using dev path: \(binaryPath)")
        }
    }
    
    // MARK: - Public Methods
    
    func startBackend() async throws {
        guard !isRunning else {
            throw BackendError.alreadyRunning
        }
        
        // Check binary exists
        let fileExists = FileManager.default.fileExists(atPath: binaryPath)
        print("🚀 BackendProcessManager: Checking binary at \(binaryPath). Exists: \(fileExists)")
        
        guard fileExists else {
            print("❌ BackendProcessManager: Binary NOT found at \(binaryPath)")
            await MainActor.run {
                lastError = "Backend binary not found at: \(binaryPath)"
            }
            throw BackendError.binaryNotFound
        }
        
        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        
        // Environment variables to ensure clean execution
        var env = ProcessInfo.processInfo.environment
        env["GIN_MODE"] = "release" // Run Gin in release mode
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" // Basic PATH
        process.environment = env
        
        // standard input - pipe to prevent it from reading from Xcode console
        process.standardInput = Pipe()

        // Set working directory to Application Support/SurgeProxy
        // This allows us to persist surge.conf and have backend read it automatically
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let configDir = appSupport.appendingPathComponent("SurgeProxy")
            
            // Create directory if not exists
            if !FileManager.default.fileExists(atPath: configDir.path) {
                do {
                    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
                    print("🚀 BackendProcessManager: Created config directory at: \(configDir.path)")
                } catch {
                    print("❌ BackendProcessManager: Failed to create config directory: \(error)")
                }
            }
            
            process.currentDirectoryURL = configDir
            print("🚀 BackendProcessManager: Working Directory set to: \(configDir.path)")
        } else {
            // Fallback to home
            process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        }
        
        // Ensure surge.conf exists in working directory
        if let workDir = process.currentDirectoryURL {
            let configPath = workDir.appendingPathComponent("surge.conf").path
            if !FileManager.default.fileExists(atPath: configPath) {
                print("⚠️ BackendProcessManager: surge.conf not found in \(workDir.path), attempting to copy default...")
                
                // Determine source path based on binary location
                // If binary is at .../bin/surge-go, config might be at .../bin/surge.conf or .../surge.conf
                let binaryURL = URL(fileURLWithPath: binaryPath)
                let binDir = binaryURL.deletingLastPathComponent()
                let possibleSources = [
                    binDir.appendingPathComponent("surge.conf"),
                    binDir.deletingLastPathComponent().appendingPathComponent("surge.conf"),
                    Bundle.main.resourceURL?.appendingPathComponent("surge.conf")
                ]
                
                var copied = false
                for source in possibleSources {
                    if let source = source, FileManager.default.fileExists(atPath: source.path) {
                        do {
                            try FileManager.default.copyItem(at: source, to: workDir.appendingPathComponent("surge.conf"))
                            print("✅ BackendProcessManager: Copied default config from \(source.path)")
                            copied = true
                            break
                        } catch {
                            print("❌ BackendProcessManager: Failed to copy config from \(source.path): \(error)")
                        }
                    }
                }
                
                if !copied {
                    print("❌ BackendProcessManager: Could not find default surge.conf to copy")
                    await MainActor.run {
                        lastError = "Missing surge.conf and failed to find default copy"
                    }
                    // Might want to throw or continue and hope defaults work? 
                    // Let's continue, maybe it has internal defaults.
                }
            } else {
                print("✅ BackendProcessManager: surge.conf exists at \(configPath)")
            }
        }
        
        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Read output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                Task { @MainActor in
                    self?.backendLogs.append(output.trimmingCharacters(in: .whitespacesAndNewlines))
                    // Keep only last 100 lines
                    if let logs = self?.backendLogs, logs.count > 100 {
                        self?.backendLogs = Array(logs.suffix(100))
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                Task { @MainActor in
                    self?.backendLogs.append("ERROR: " + output.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        // Start process
        process.terminationHandler = { [weak self] proc in
            let status = proc.terminationStatus
            let reason = proc.terminationReason
            let msg = "Process terminated with status: \(status), reason: \(reason.rawValue)"
            print("⚠️ BackendProcessManager: \(msg)")
            
            Task { @MainActor [weak self] in
                self?.backendLogs.append(msg)
                self?.isRunning = false
            }
        }

        do {
            print("🚀 BackendProcessManager: Attempting to run binary at: \(process.executableURL?.path ?? "nil")")
            try process.run()
            self.process = process
            
            await MainActor.run {
                backendLogs.append("Backend process started (PID: \(process.processIdentifier))")
            }
            
            // Wait for backend to be ready
            try await waitForBackendReady(timeout: 15)
            
            await MainActor.run {
                isRunning = true
                lastError = nil
                backendLogs.append("✓ Backend is ready")
            }
        } catch {
            print("❌ BackendProcessManager: Failed to start backend: \(error)")
            await MainActor.run {
                lastError = "Failed to start backend: \(error.localizedDescription)"
                backendLogs.append("❌ Failed to start: \(error)")
            }
            throw error
        }
    }
    
    func stopBackend() async {
        guard let process = process, process.isRunning else {
            await MainActor.run {
                isRunning = false
            }
            return
        }
        
        await MainActor.run {
            backendLogs.append("Stopping backend...")
        }
        
        // Send SIGTERM for graceful shutdown
        process.terminate()
        
        // Wait for graceful shutdown (max 5 seconds)
        for i in 0..<50 {
            if !process.isRunning {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            if i == 49 {
                // Force kill if still running
                process.interrupt()
                await MainActor.run {
                    backendLogs.append("⚠️ Backend force killed")
                }
            }
        }
        
        self.process = nil
        
        await MainActor.run {
            isRunning = false
            backendLogs.append("✓ Backend stopped")
        }
    }
    
    func checkHealth() async -> Bool {
        do {
            let url = URL(string: "\(apiBaseURL)/api/health")!
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        return false
    }
    
    /// Synchronously terminate the backend process.
    /// Used for app termination cleanup.
    func terminate() {
        if let process = process, process.isRunning {
            print("🛑 BackendProcessManager: Force terminating backend process (PID: \(process.processIdentifier))")
            process.terminate()
        }
    }
    
    // MARK: - Private Methods
    
    private func waitForBackendReady(timeout: TimeInterval) async throws {
        let startTime = Date()
        var attempts = 0
        
        while Date().timeIntervalSince(startTime) < timeout {
            attempts += 1
            
            if await checkHealth() {
                return
            }
            
            // Exponential backoff: 100ms, 200ms, 400ms, 800ms, then 1s
            let delay = min(100_000_000 * (1 << min(attempts - 1, 3)), 1_000_000_000)
            try await Task.sleep(nanoseconds: UInt64(delay))
        }
        
        await MainActor.run {
            lastError = "Backend startup timeout after \(Int(timeout)) seconds"
        }
        throw BackendError.startupTimeout
    }
}

// MARK: - Error Types

enum BackendError: LocalizedError {
    case binaryNotFound
    case startupTimeout
    case alreadyRunning
    case processError(String)
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Backend binary not found. Please rebuild the project."
        case .startupTimeout:
            return "Backend failed to start within timeout period."
        case .alreadyRunning:
            return "Backend is already running."
        case .processError(let message):
            return "Process error: \(message)"
        }
    }
}
