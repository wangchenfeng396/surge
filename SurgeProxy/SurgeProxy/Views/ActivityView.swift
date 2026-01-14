//
//  ActivityView.swift
//  SurgeProxy
//
//  Activity dashboard with network stats, latency, and traffic graphs
//

import SwiftUI
import Charts
import SystemConfiguration
import CoreWLAN

struct ActivityView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var selectedTimeRange = "6H"
    @State private var profileName: String = "No Profile"
    @State private var externalIP: String = "Calculate..."
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Top bar: Warning + Toggles
                TopBarView(proxyManager: proxyManager)
                
                // Page Title
                Text("Activity")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Horizontal Info Bar
                InfoBarView(
                    networkType: networkDisplayText,
                    profileName: profileName,
                    outboundMode: proxyManager.mode.rawValue,
                    externalIP: externalIP
                )
                
                // First Row: Latency, Upload, Download
                HStack(spacing: 12) {
                    LatencyCardView()
                        .environmentObject(proxyManager)
                    
                    TrafficCardView(
                        title: "UPLOAD",
                        speed: formatSpeed(proxyManager.stats?.uploadSpeed ?? 0),
                        data: proxyManager.uploadHistory,
                        color: .cyan
                    )
                    
                    TrafficCardView(
                        title: "DOWNLOAD",
                        speed: formatSpeed(proxyManager.stats?.downloadSpeed ?? 0),
                        data: proxyManager.downloadHistory,
                        color: .blue
                    )
                }
                
                // Second Row: Active Connection, Traffic Visualization
                HStack(spacing: 12) {
                    ActiveConnectionCardView(
                        activeConns: proxyManager.stats?.activeConns ?? 0,
                        processCount: proxyManager.processCount,
                        deviceCount: proxyManager.deviceCount
                    )
                    
                    TrafficVisualizationCardView()
                        .environmentObject(proxyManager)
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSystemInfo()
        }
    }
    
    private var networkDisplayText: String {
        if let name = proxyManager.networkName {
            return name
        }
        return proxyManager.networkType
    }
    
    private func loadSystemInfo() {
        if let filename = UserDefaults.standard.string(forKey: "LastImportedConfigFile") {
            profileName = filename.replacingOccurrences(of: ".conf", with: "")
        }
        
        fetchExternalIP()
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
                await MainActor.run { externalIP = "获取失败" }
            }
        }
    }
    
    private func formatSpeed(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B/s" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0f KB/s", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB/s", mb)
    }
}

// MARK: - Top Bar View

struct TopBarView: View {
    @ObservedObject var proxyManager: GoProxyManager
    
    var body: some View {
        HStack {
            // Warning Banner
            if !proxyManager.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("WARN")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("请在后台允许 Surge 运行以确保功能正常...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("运行中")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Toggle Buttons
            HStack(spacing: 12) {
                TogglePillButton(
                    title: "System Proxy",
                    isOn: proxyManager.systemProxyEnabled,
                    action: {
                        if proxyManager.systemProxyEnabled {
                            proxyManager.disableSystemProxy()
                        } else {
                            proxyManager.enableSystemProxy()
                        }
                    }
                )
                
                TogglePillButton(
                    title: "Enhanced Mode",
                    isOn: proxyManager.enhancedMode,
                    disabled: true,
                    action: {}
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
    }
}

struct TogglePillButton: View {
    let title: String
    let isOn: Bool
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isOn ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

// MARK: - Info Bar View

struct InfoBarView: View {
    let networkType: String
    let profileName: String
    let outboundMode: String
    let externalIP: String
    
    var body: some View {
        HStack(spacing: 40) {
            InfoItem(label: "NETWORK", value: networkType)
            InfoItem(label: "PROFILE", value: profileName)
            InfoItem(label: "OUTBOUND MODE", value: outboundMode)
            InfoItem(label: "EXTERNAL IP", value: externalIP)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Latency Card (带功能)

struct LatencyCardView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var showDiagnostics = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Text("INTERNET LATENCY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        proxyManager.measureLatency()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(proxyManager.isMeasuringLatency ? 360 : 0))
                            .animation(proxyManager.isMeasuringLatency ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: proxyManager.isMeasuringLatency)
                    }
                    .buttonStyle(.plain)
                    .disabled(proxyManager.isMeasuringLatency)
                }
                Spacer()
                Button("Diagnostics") {
                    showDiagnostics = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(max(proxyManager.routerLatency, proxyManager.dnsLatency))")
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                Text("ms")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 24) {
                LatencyStatItem(label: "ROUTER", value: "\(proxyManager.routerLatency) ms")
                LatencyStatItem(label: "DNS", value: "\(proxyManager.dnsLatency) ms")
                LatencyStatItem(label: "Proxy", value: proxyManager.proxyLatency)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
    }
}

struct LatencyStatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Traffic Card

struct TrafficCardView: View {
    let title: String
    let speed: String
    let data: [Double]
    let color: Color
    
    private var maxSpeed: String {
        guard let maxVal = data.max(), maxVal > 0 else { return "0 KB/s" }
        let kb = maxVal / 1024
        if kb < 1024 { return String(format: "%.0f KB/s", kb) }
        return String(format: "%.1f MB/s", kb / 1024)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(maxSpeed)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(speed.replacingOccurrences(of: " KB/s", with: "").replacingOccurrences(of: " MB/s", with: "").replacingOccurrences(of: " B/s", with: ""))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(speed.contains("MB") ? "MB/s" : (speed.contains("KB") ? "KB/s" : "B/s"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Gradient Line Graph
            ZStack(alignment: .bottom) {
                // Gradient fill
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .mask(
                    TrafficGraphShape(data: data)
                )
                
                // Line
                TrafficGraphShape(data: data)
                    .stroke(color, lineWidth: 2)
                    .frame(height: 50)
            }
            
            HStack {
                Spacer()
                Text("0 KB/s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }
}

struct TrafficGraphShape: Shape {
    let data: [Double]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else {
            // Draw flat line if no data
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            return path
        }
        
        let maxValue = max(data.max() ?? 1, 1)
        let stepX = rect.width / CGFloat(data.count - 1)
        
        path.move(to: CGPoint(x: 0, y: rect.height - CGFloat(data[0] / maxValue) * rect.height))
        
        for (index, value) in data.enumerated() {
            let x = stepX * CGFloat(index)
            let y = rect.height - CGFloat(value / maxValue) * rect.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close path for fill
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Active Connection Card (带导航)

struct ActiveConnectionCardView: View {
    let activeConns: Int
    let processCount: Int
    let deviceCount: Int
    
    var body: some View {
        NavigationLink(destination: ConnectionsView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ACTIVE CONNECTION")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Circle()
                        .fill(activeConns > 0 ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                }
                
                Text("\(activeConns)")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 32) {
                    ConnectionStatItem(value: processCount, label: "Processes")
                    ConnectionStatItem(value: deviceCount, label: "Devices")
                    ConnectionStatItem(value: 0, label: "DHCP Devices")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct ConnectionStatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Traffic Visualization Card (带数据)

struct TrafficVisualizationCardView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var selectedTab = "CLIENT"
    @State private var selectedFilter = "ALL"
    @State private var trafficData: [TrafficItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRAFFIC")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("", selection: $selectedFilter) {
                    Text("ALL").tag("ALL")
                    Text("PROXY").tag("PROXY")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .onChange(of: selectedFilter) { _ in
                    loadTrafficData()
                }
            }
            
            // Traffic visualization bars
            if isLoading {
                ProgressView()
                    .frame(height: 30)
            } else if trafficData.isEmpty {
                HStack(spacing: 3) {
                    ForEach(0..<40, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 4, height: 20)
                    }
                }
                .frame(height: 30)
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<min(40, trafficData.count), id: \.self) { index in
                        let item = trafficData[index]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.color.opacity(item.intensity))
                            .frame(width: 4, height: CGFloat(10 + item.intensity * 20))
                    }
                }
                .frame(height: 30)
            }
            
            Spacer()
            
            // Tabs
            HStack(spacing: 0) {
                TrafficTabButton(title: "CLIENT", isSelected: selectedTab == "CLIENT") {
                    selectedTab = "CLIENT"
                    loadTrafficData()
                }
                TrafficTabButton(title: "DOMAIN", isSelected: selectedTab == "DOMAIN") {
                    selectedTab = "DOMAIN"
                    loadTrafficData()
                }
                TrafficTabButton(title: "POLICY", isSelected: selectedTab == "POLICY") {
                    selectedTab = "POLICY"
                    loadTrafficData()
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .onAppear {
            loadTrafficData()
        }
    }
    
    private func loadTrafficData() {
        isLoading = true
        
        Task {
            do {
                let captures = try await APIClient.shared.fetchCapture()
                
                await MainActor.run {
                    // 根据选中的标签处理数据
                    switch selectedTab {
                    case "CLIENT":
                        // 按客户端 IP 分组
                        let grouped = Dictionary(grouping: captures, by: { $0.sourceIP })
                        trafficData = grouped.map { key, value in
                            TrafficItem(
                                name: key,
                                count: value.count,
                                intensity: min(Double(value.count) / 10.0, 1.0),
                                color: .cyan
                            )
                        }.sorted { $0.count > $1.count }
                        
                    case "DOMAIN":
                        // 按域名分组
                        let grouped = Dictionary(grouping: captures, by: { extractDomain(from: $0.url) })
                        trafficData = grouped.map { key, value in
                            TrafficItem(
                                name: key,
                                count: value.count,
                                intensity: min(Double(value.count) / 10.0, 1.0),
                                color: .blue
                            )
                        }.sorted { $0.count > $1.count }
                        
                    case "POLICY":
                        // 按策略分组
                        let grouped = Dictionary(grouping: captures, by: { $0.policy })
                        trafficData = grouped.map { key, value in
                            TrafficItem(
                                name: key,
                                count: value.count,
                                intensity: min(Double(value.count) / 10.0, 1.0),
                                color: .purple
                            )
                        }.sorted { $0.count > $1.count }
                        
                    default:
                        break
                    }
                    
                    // 应用过滤器
                    if selectedFilter == "PROXY" {
                        trafficData = trafficData.filter { $0.name != "DIRECT" }
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    trafficData = []
                    isLoading = false
                }
            }
        }
    }
    
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host
    }
}

struct TrafficItem: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let intensity: Double
    let color: Color
}

struct TrafficTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.gray.opacity(0.6) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ActivityView()
        .environmentObject(GoProxyManager())
        .frame(width: 900, height: 700)
}

