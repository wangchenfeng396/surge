//
//  ControlPanelView.swift
//  SurgeProxy
//
//  Main control panel with system proxy and TUN mode controls
//

import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @StateObject private var viewModel = ControlPanelViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // 状态卡片
            StatusCardView(
                isRunning: proxyManager.isRunning,
                systemProxyEnabled: viewModel.systemProxyEnabled,
                tunEnabled: viewModel.tunEnabled
            )
            
            // 控制按钮
            VStack(spacing: 15) {
                // 代理服务控制
                ProxyControlButton(
                    isRunning: proxyManager.isRunning,
                    isStarting: proxyManager.isStarting,
                    startAction: { proxyManager.startProxy() },
                    stopAction: { proxyManager.stopProxy() }
                )
                
                // 系统代理控制
                SystemProxyToggle(
                    isEnabled: $viewModel.systemProxyEnabled,
                    isProxyRunning: proxyManager.isRunning,
                    action: { enabled in
                        await viewModel.toggleSystemProxy(enabled: enabled)
                    }
                )
                
                // 增强模式 (TUN)
                TUNModeToggle(
                    isEnabled: $viewModel.tunEnabled,
                    isProxyRunning: proxyManager.isRunning,
                    action: { enabled in
                        await viewModel.toggleTUN(enabled: enabled)
                    }
                )
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            Spacer()
        }
        .padding()
        .task {
            await viewModel.loadStatus()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Status Card

struct StatusCardView: View {
    let isRunning: Bool
    let systemProxyEnabled: Bool
    let tunEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: isRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isRunning ? .green : .red)
                    .font(.title2)
                
                Text(isRunning ? "代理服务运行中" : "代理服务已停止")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                StatusItem(icon: "network", title: "系统代理", isActive: systemProxyEnabled)
                Spacer()
                StatusItem(icon: "shield.fill", title: "增强模式", isActive: tunEnabled)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct StatusItem: View {
    let icon: String
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isActive ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(isActive ? "已启用" : "未启用")
                    .font(.caption2)
                    .foregroundColor(isActive ? .green : .gray)
            }
        }
    }
}

// MARK: - Control Buttons

struct ProxyControlButton: View {
    let isRunning: Bool
    let isStarting: Bool
    let startAction: () -> Void
    let stopAction: () -> Void
    
    var body: some View {
        Button(action: {
            if isRunning {
                stopAction()
            } else {
                startAction()
            }
        }) {
            HStack {
                if isStarting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title3)
                }
                
                Text(isStarting ? "启动中..." : (isRunning ? "停止代理" : "启动代理"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isRunning ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isStarting)
    }
}

struct SystemProxyToggle: View {
    @Binding var isEnabled: Bool
    let isProxyRunning: Bool
    let action: (Bool) async -> Void
    
    @State private var isToggling = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("系统代理")
                    .font(.headline)
                Text("将系统流量通过代理")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isToggling {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .disabled(!isProxyRunning)
                    .onChange(of: isEnabled) { newValue in
                        Task {
                            isToggling = true
                            await action(newValue)
                            isToggling = false
                        }
                    }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct TUNModeToggle: View {
    @Binding var isEnabled: Bool
    let isProxyRunning: Bool
    let action: (Bool) async -> Void
    
    @State private var isToggling = false
    @State private var showPermissionAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("增强模式 (TUN)")
                        .font(.headline)
                    
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            showPermissionAlert = true
                        }
                }
                
                Text("代理所有应用流量(需要权限)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isToggling {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .disabled(!isProxyRunning)
                    .onChange(of: isEnabled) { newValue in
                        Task {
                            isToggling = true
                            await action(newValue)
                            isToggling = false
                        }
                    }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .alert("增强模式说明", isPresented: $showPermissionAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("TUN 模式需要 root 权限才能创建虚拟网卡。启用后可以代理所有应用的网络流量，包括不支持代理设置的应用。")
        }
    }
}

// MARK: - View Model

@MainActor
class ControlPanelViewModel: ObservableObject {
    @Published var systemProxyEnabled = false
    @Published var tunEnabled = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadStatus() async {
        // 加载系统代理状态
        do {
            let status = try await apiClient.fetchSystemProxyStatus()
            systemProxyEnabled = status.enabled
        } catch {
            print("Failed to fetch system proxy status: \(error)")
        }
        
        // 加载 TUN 模式状态
        do {
            let status = try await apiClient.fetchTUNStatus()
            tunEnabled = status.enabled
        } catch {
            print("Failed to fetch TUN status: \(error)")
        }
    }
    
    func toggleSystemProxy(enabled: Bool) async {
        do {
            if enabled {
                try await apiClient.enableSystemProxy(port: 8888)
            } else {
                try await apiClient.disableSystemProxy()
            }
            systemProxyEnabled = enabled
        } catch {
            errorMessage = "系统代理操作失败: \(error.localizedDescription)"
            showError = true
            // 恢复原状态
            systemProxyEnabled = !enabled
        }
    }
    
    func toggleTUN(enabled: Bool) async {
        do {
            if enabled {
                try await apiClient.enableTUN()
            } else {
                try await apiClient.disableTUN()
            }
            tunEnabled = enabled
        } catch {
            errorMessage = "TUN 模式操作失败: \(error.localizedDescription)\n可能需要管理员权限。"
            showError = true
            // 恢复原状态
            tunEnabled = !enabled
        }
    }
}

#Preview {
    ControlPanelView()
        .environmentObject(GoProxyManager())
}
