//
//  ProxyDiagnosticsView.swift
//  SurgeProxy
//
//  Proxy diagnostics dialog for testing TCP/UDP relay and speed
//

import SwiftUI

struct ProxyDiagnosticsView: View {
    let proxies: [String]
    let selectedProxy: String?
    
    @Environment(\.dismiss) var dismiss
    @State private var currentProxy: String
    @State private var testResults: [DiagnosticResult] = []
    @State private var isRunning = false
    
    init(proxies: [String], selectedProxy: String?) {
        self.proxies = proxies
        self.selectedProxy = selectedProxy
        _currentProxy = State(initialValue: selectedProxy ?? proxies.first ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Proxy Diagnostics")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Policy Selector
            HStack {
                Text("Policy:")
                    .foregroundColor(.secondary)
                Picker("", selection: $currentProxy) {
                    ForEach(proxies, id: \.self) { proxy in
                        Text(proxy).tag(proxy)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Test Buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    TestButton(title: "Test TCP Relay", isRunning: isRunning) {
                        runTest(.tcpRelay)
                    }
                    TestButton(title: "Test UDP Relay", isRunning: isRunning) {
                        runTest(.udpRelay)
                    }
                    TestButton(title: "Test UDP NAT Type", isRunning: isRunning) {
                        runTest(.udpNatType)
                    }
                }
                
                HStack(spacing: 12) {
                    TestButton(title: "Test Download Speed", isRunning: isRunning) {
                        runTest(.downloadSpeed)
                    }
                    TestButton(title: "Test Upload Speed", isRunning: isRunning) {
                        runTest(.uploadSpeed)
                    }
                }
            }
            
            Divider()
            
            // Results
            if testResults.isEmpty {
                Spacer()
                Text("选择上方测试按钮开始诊断")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(testResults) { result in
                            DiagnosticResultRow(result: result)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func runTest(_ type: DiagnosticType) {
        isRunning = true
        
        Task {
            let result = await performTest(type)
            await MainActor.run {
                testResults.insert(result, at: 0)
                isRunning = false
            }
        }
    }
    
    private func performTest(_ type: DiagnosticType) async -> DiagnosticResult {
        let startTime = Date()
        
        // Simulate test - in real implementation, call actual API
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        switch type {
        case .tcpRelay:
            return DiagnosticResult(
                type: type,
                status: .success,
                message: "TCP 连接成功",
                detail: "延迟: \(Int(elapsed * 1000)) ms"
            )
        case .udpRelay:
            return DiagnosticResult(
                type: type,
                status: .success,
                message: "UDP 连接成功",
                detail: "延迟: \(Int(elapsed * 1000)) ms"
            )
        case .udpNatType:
            let natTypes = ["Full Cone", "Restricted Cone", "Port Restricted Cone", "Symmetric"]
            return DiagnosticResult(
                type: type,
                status: .success,
                message: "NAT 类型检测完成",
                detail: natTypes.randomElement() ?? "Unknown"
            )
        case .downloadSpeed:
            let speed = Double.random(in: 10...100)
            return DiagnosticResult(
                type: type,
                status: .success,
                message: "下载速度测试完成",
                detail: String(format: "%.1f MB/s", speed)
            )
        case .uploadSpeed:
            let speed = Double.random(in: 5...50)
            return DiagnosticResult(
                type: type,
                status: .success,
                message: "上传速度测试完成",
                detail: String(format: "%.1f MB/s", speed)
            )
        }
    }
}

// MARK: - Test Button

struct TestButton: View {
    let title: String
    let isRunning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isRunning)
    }
}

// MARK: - Diagnostic Types

enum DiagnosticType: String {
    case tcpRelay = "TCP Relay"
    case udpRelay = "UDP Relay"
    case udpNatType = "UDP NAT Type"
    case downloadSpeed = "Download Speed"
    case uploadSpeed = "Upload Speed"
}

// MARK: - Diagnostic Result

struct DiagnosticResult: Identifiable {
    let id = UUID()
    let type: DiagnosticType
    let status: DiagnosticStatus
    let message: String
    let detail: String
    let timestamp = Date()
}

enum DiagnosticStatus {
    case success, failed, warning
    
    var color: Color {
        switch self {
        case .success: return .green
        case .failed: return .red
        case .warning: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Result Row

struct DiagnosticResultRow: View {
    let result: DiagnosticResult
    
    var body: some View {
        HStack {
            Image(systemName: result.status.icon)
                .foregroundColor(result.status.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(result.detail)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(result.status.color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ProxyDiagnosticsView(
        proxies: ["JP-Oracle-AI", "US-FLY-AI", "HK"],
        selectedProxy: "JP-Oracle-AI"
    )
}
