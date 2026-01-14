//
//  ConfigFileManager.swift
//  SurgeProxy
//
//  Configuration file management service
//  Handles config file creation, validation, and path management
//

import Foundation

class ConfigFileManager: ObservableObject {
    // MARK: - Properties
    
    static let shared = ConfigFileManager()
    
    // Default configuration file path
    private let defaultConfigPath: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let surgeDir = appSupport.appendingPathComponent("SurgeProxy")
        return surgeDir.appendingPathComponent("surge.conf")
    }()
    
    // Custom configuration path (if set by user)
    @Published var customConfigPath: URL?
    
    // Current active configuration path
    var activeConfigPath: URL {
        return customConfigPath ?? defaultConfigPath
    }
    
    // MARK: - Initialization
    
    private init() {
        // Ensure configuration file exists on initialization
        Task {
            await ensureConfigFileExists()
        }
    }
    
    // MARK: - Configuration File Management
    
    /// Ensures the configuration file exists, creates default if missing
    func ensureConfigFileExists() async {
        let configPath = activeConfigPath
        let configDir = configPath.deletingLastPathComponent()
        
        do {
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: configDir.path) {
                try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
                print("✓ Created configuration directory: \(configDir.path)")
            }
            
            // Check if config file exists
            if !FileManager.default.fileExists(atPath: configPath.path) {
                try createDefaultConfig(at: configPath)
                print("✓ Created default configuration file: \(configPath.path)")
            } else {
                print("✓ Configuration file found: \(configPath.path)")
            }
            
            // Set appropriate file permissions (rw-r--r--)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: configPath.path)
            
        } catch {
            print("✗ Error ensuring config file exists: \(error.localizedDescription)")
        }
    }
    
    /// Creates a default configuration file
    private func createDefaultConfig(at path: URL) throws {
        let defaultConfig = """
[General]
loglevel = notify
dns-server = 223.5.5.5, 114.114.114.114, 8.8.8.8
test-timeout = 5
ipv6 = false
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, localhost, *.local

[Proxy]
DIRECT = direct
REJECT = reject

[Proxy Group]
Proxy = select, DIRECT

[Rule]
# Default rules - customize as needed
FINAL,Proxy
"""
        
        try defaultConfig.write(to: path, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Configuration Path Management
    
    /// Sets a custom configuration path
    func setCustomConfigPath(_ path: URL) async {
        customConfigPath = path
        await ensureConfigFileExists()
    }
    
    /// Resets to default configuration path
    func resetToDefaultPath() async {
        customConfigPath = nil
        await ensureConfigFileExists()
    }
    
    /// Gets the current configuration path
    func getConfigPath() -> String {
        return activeConfigPath.path
    }
    
    // MARK: - Configuration Validation
    
    /// Validates the configuration file
    func validateConfigFile() async -> (isValid: Bool, error: String?) {
        let configPath = activeConfigPath
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return (false, "Configuration file not found at: \(configPath.path)")
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: configPath.path) else {
            return (false, "Configuration file is not readable")
        }
        
        // Read and parse the configuration
        do {
            let content = try String(contentsOf: configPath, encoding: .utf8)
            
            // Basic validation - check for required sections
            let requiredSections = ["[General]", "[Proxy]", "[Rule]"]
            for section in requiredSections {
                if !content.contains(section) {
                    return (false, "Missing required section: \(section)")
                }
            }
            
            // Check if file is not empty
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "Configuration file is empty")
            }
            
            return (true, nil)
            
        } catch {
            return (false, "Failed to read configuration file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Configuration File Operations
    
    /// Loads configuration content
    func loadConfigContent() async -> String? {
        do {
            let content = try String(contentsOf: activeConfigPath, encoding: .utf8)
            return content
        } catch {
            print("✗ Error loading config: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves configuration content
    func saveConfigContent(_ content: String) async throws {
        try content.write(to: activeConfigPath, atomically: true, encoding: .utf8)
        print("✓ Configuration saved to: \(activeConfigPath.path)")
    }
    
    /// Creates a backup of the current configuration
    func createBackup() async throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupPath = activeConfigPath.deletingPathExtension()
            .appendingPathExtension("backup-\(timestamp).\(activeConfigPath.pathExtension)")
        
        try FileManager.default.copyItem(at: activeConfigPath, to: backupPath)
        print("✓ Configuration backed up to: \(backupPath.path)")
        return backupPath
    }
    
    /// Restores configuration from a backup
    func restoreFromBackup(_ backupPath: URL) async throws {
        // Create a backup of current config before restoring
        let _ = try await createBackup()
        
        // Copy backup to current config path
        try FileManager.default.removeItem(at: activeConfigPath)
        try FileManager.default.copyItem(at: backupPath, to: activeConfigPath)
        
        print("✓ Configuration restored from: \(backupPath.path)")
    }
    
    // MARK: - Migration Support
    
    /// Migrates configuration from an old path to the current path
    func migrateConfig(from oldPath: URL) async throws {
        guard FileManager.default.fileExists(atPath: oldPath.path) else {
            throw ConfigFileError.sourceNotFound
        }
        
        // Validate the old configuration
        let content = try String(contentsOf: oldPath, encoding: .utf8)
        
        // Create backup of current config if it exists
        if FileManager.default.fileExists(atPath: activeConfigPath.path) {
            let _ = try await createBackup()
        }
        
        // Copy old config to new location
        try content.write(to: activeConfigPath, atomically: true, encoding: .utf8)
        
        print("✓ Configuration migrated from: \(oldPath.path)")
    }
    
    // MARK: - Helper Methods
    
    /// Returns the directory containing the configuration file
    func getConfigDirectory() -> URL {
        return activeConfigPath.deletingLastPathComponent()
    }
    
    /// Lists all backup files in the configuration directory
    func listBackups() -> [URL] {
        let configDir = getConfigDirectory()
        let backupPattern = "surge.backup-*.*"
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: configDir, includingPropertiesForKeys: nil)
            return contents.filter { $0.lastPathComponent.hasPrefix("surge.backup-") }
                .sorted { $0.lastPathComponent > $1.lastPathComponent } // Most recent first
        } catch {
            print("✗ Error listing backups: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Error Types

enum ConfigFileError: Error, LocalizedError {
    case sourceNotFound
    case invalidConfiguration
    case permissionDenied
    case migrationFailed
    
    var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return "Source configuration file not found"
        case .invalidConfiguration:
            return "Configuration file is invalid"
        case .permissionDenied:
            return "Permission denied to access configuration file"
        case .migrationFailed:
            return "Failed to migrate configuration"
        }
    }
}
