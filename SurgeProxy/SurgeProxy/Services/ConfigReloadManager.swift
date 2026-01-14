//
//  ConfigReloadManager.swift
//  SurgeProxy
//
//  Manages configuration reload operations and status
//

import Foundation
import Combine

class ConfigReloadManager: ObservableObject {
    static let shared = ConfigReloadManager()
    
    @Published var isReloading = false
    @Published var lastReloadStatus: ReloadStatus = .idle
    @Published var lastReloadTime: Date?
    @Published var reloadMessage: String?
    
    private let apiClient = APIClient.shared
    private var statusCheckTimer: Timer?
    
    enum ReloadStatus {
        case idle
        case inProgress
        case success
        case failed(String)
        
        var displayMessage: String {
            switch self {
            case .idle: return "就绪"
            case .inProgress: return "正在重载配置..."
            case .success: return "配置重载成功"
            case .failed(let error): return "重载失败: \(error)"
            }
        }
        
        var isError: Bool {
            if case .failed = self { return true }
            return false
        }
    }
    
    private init() {}
    
    // MARK: - Reload Operations
    
    /// Trigger manual configuration reload
    @MainActor
    func triggerReload() async {
        guard !isReloading else {
            print("Reload already in progress")
            return
        }
        
        isReloading = true
        lastReloadStatus = .inProgress
        reloadMessage = "正在重载配置..."
        
        do {
            try await apiClient.triggerReload()
            
            // Wait a bit for reload to complete
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Check reload status
            await checkReloadStatus()
            
            lastReloadTime = Date()
            lastReloadStatus = .success
            reloadMessage = "配置已成功重载"
            
            // Auto-dismiss success message after 3 seconds
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    if case .success = self.lastReloadStatus {
                        self.reloadMessage = nil
                    }
                }
            }
            
        } catch {
            lastReloadStatus = .failed(error.localizedDescription)
            reloadMessage = "重载失败: \(error.localizedDescription)"
        }
        
        isReloading = false
    }
    
    /// Check current reload status from backend
    @MainActor
    func checkReloadStatus() async {
        do {
            let status = try await apiClient.fetchReloadStatus()
            print("Reload status: \(status)")
            // Process status if needed
        } catch {
            print("Error checking reload status: \(error)")
        }
    }
    
    /// Auto-trigger reload after configuration save
    @MainActor
    func reloadAfterSave(delay: TimeInterval = 0.5) async {
        // Small delay to ensure file is written
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Note: Backend ConfigWatcher will auto-reload on file change
        // This is just for immediate UI feedback
        reloadMessage = "配置已保存，等待自动重载..."
        
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            await MainActor.run {
                self.reloadMessage = nil
            }
        }
    }
    
    /// Clear reload messages
    @MainActor
    func clearMessages() {
        reloadMessage = nil
        if case .success = lastReloadStatus {
            lastReloadStatus = .idle
        }
    }
}
