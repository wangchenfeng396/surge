//
//  OverviewView.swift
//  SurgeProxy
//
//  Overview page with system information
//

import SwiftUI
import SystemConfiguration
import CoreWLAN
import Network



struct OverviewView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    
    @State private var profileName: String = "No Profile"
    @State private var externalIP: String = "Not available"
    @State private var showingDiagnostics = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                systemInfoSection
                Divider()
                actionButtonsSection
                Divider()
                latencySection
                trafficSection
                connectionsSection
                diagnosticsSection
            }
            .padding()
            .onAppear {
                proxyManager.refreshSystemStatus()
                proxyManager.updateNetworkInfo()
            }
        }
        .onAppear {
            loadSystemInfo()
            fetchExternalIP()
            proxyManager.refreshSystemStatus()
            proxyManager.measureLatency() // Force refresh
        }
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoRow(label: "NETWORK", value: networkDisplayText)
            InfoRow(label: "PROFILE", value: profileName)
            
            // Mode Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("OUTBOUND MODE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Picker("", selection: $proxyManager.mode) {
                    ForEach(PolicyMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            // External IP with refresh button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXTERNAL IP")
                    // ... existing code ...
                }
                
                Spacer()
                
                Button(action: {
                    fetchExternalIP()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                    }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // System Proxy Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Proxy")
                        .font(.headline)
                    if proxyManager.systemProxyEnabled {
                        if let selected = proxyManager.selectedProxy {
                            Text("Using: \(selected)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("HTTP/HTTPS proxy active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Inactive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $proxyManager.systemProxyEnabled)
                    // ... existing toggle logic ...
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Enhanced Mode Card
            HStack {
                // ... existing enhanced mode logic ...
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .opacity(0.6)
        }
    }
    
    private var latencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INTERNET LATENCY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                   proxyManager.measureLatency()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .rotationEffect(.degrees(proxyManager.isMeasuringLatency ? 360 : 0))
                        .animation(proxyManager.isMeasuringLatency ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: proxyManager.isMeasuringLatency)
                }
                .buttonStyle(.borderless)
                .disabled(proxyManager.isMeasuringLatency)
            }
            
            HStack(spacing: 40) {
                LatencyDisplay(label: "ROUTER", value: "\(proxyManager.routerLatency) ms")
                LatencyDisplay(label: "DNS", value: "\(proxyManager.dnsLatency) ms")
                LatencyDisplay(label: "Proxy", value: proxyManager.proxyLatency)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var trafficSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                TrafficDisplay(
                    title: "UPLOAD",
                    value: formatBytes(proxyManager.stats?.uploadSpeed ?? 0)
                )
                TrafficDisplay(
                    title: "DOWNLOAD",
                    value: formatBytes(proxyManager.stats?.downloadSpeed ?? 0)
                )
            }
            
            // Custom Simple Traffic Graph
            SimpleTrafficGraph(
                uploadHistory: proxyManager.uploadHistory,
                downloadHistory: proxyManager.downloadHistory
            )
            .frame(height: 100)
            .padding(.top, 8)
        }
    }
    
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACTIVE CONNECTION")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Spacer()
            }
            
            HStack(spacing: 40) {
                ConnectionDisplay(value: "\(proxyManager.processCount)", label: "Processes")
                ConnectionDisplay(value: "\(proxyManager.deviceCount)", label: "Devices")
                ConnectionDisplay(value: "0", label: "BYOD Devices")
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var diagnosticsSection: some View {
        HStack {
            Spacer()
            Button("Diagnostics") {
                // Diagnostics functionality placeholder
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var networkDisplayText: String {
        if let name = proxyManager.networkName {
            return name
        }
        return proxyManager.networkType
    }
    
    private func loadSystemInfo() {
        // Load profile name
        if let filename = UserDefaults.standard.string(forKey: "LastImportedConfigFile") {
            profileName = filename.replacingOccurrences(of: ".conf", with: "")
        }
    }
    
    private func fetchExternalIP() {
        Task {
            do {
                let url = URL(string: "https://api.ipify.org?format=json")!
                let (data, _) = try await URLSession.shared.data(from: url)
                struct IPResponse: Codable { let ip: String }
                let response = try JSONDecoder().decode(IPResponse.self, from: data)
                await MainActor.run { externalIP = response.ip }
            } catch {
                await MainActor.run { externalIP = "Failed to fetch" }
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1 { return "0 B" }
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct LatencyDisplay: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TrafficDisplay: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.medium)
                Text("/s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func formattedValue(_ value: String) -> String {
        return value.replacingOccurrences(of: " MB", with: "")
            .replacingOccurrences(of: " KB", with: "")
            .replacingOccurrences(of: " B", with: "")
    }
}

struct ConnectionDisplay: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.body)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SimpleTrafficGraph: View {
    let uploadHistory: [Double]
    let downloadHistory: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                
                // Grid lines
                VStack {
                    Divider()
                    Spacer()
                    Divider()
                    Spacer()
                    Divider()
                }
                .opacity(0.3)
                
                // Download Graph (Green)
                if !downloadHistory.isEmpty {
                    GraphArea(data: downloadHistory)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.4), .green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    GraphLine(data: downloadHistory)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                
                // Upload Graph (Blue)
                if !uploadHistory.isEmpty {
                    GraphArea(data: uploadHistory)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.4), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    GraphLine(data: uploadHistory)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 120)
        .cornerRadius(12)
    }
}

private struct GraphArea: Shape {
    let data: [Double]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let maxVal = (data.max() ?? 1) * 1.2
        let stepX = rect.width / CGFloat(max(data.count - 1, 1))
        let effectiveMax = maxVal == 0 ? 1 : maxVal
        
        // Start bottom-left
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = rect.height - (CGFloat(value) / CGFloat(effectiveMax) * rect.height)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // End bottom-right
        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct GraphLine: Shape {
    let data: [Double]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let maxVal = (data.max() ?? 1) * 1.2
        let stepX = rect.width / CGFloat(max(data.count - 1, 1))
        let effectiveMax = maxVal == 0 ? 1 : maxVal
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let y = rect.height - (CGFloat(value) / CGFloat(effectiveMax) * rect.height)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

#Preview {
    OverviewView()
        .environmentObject(GoProxyManager())
        .frame(width: 900, height: 600)
}
