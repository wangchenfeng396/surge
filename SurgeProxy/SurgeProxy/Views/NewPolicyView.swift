//
//  NewPolicyView.swift
//  SurgeProxy
//
//  Policy and proxy management view - Reading from surge.conf
//

import SwiftUI

struct NewPolicyView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @StateObject private var configManager = SurgeConfigManager.shared
    
    @State private var selectedMode: PolicyMode = .ruleBased
    @State private var isTesting = false
    @State private var showAddProxySheet = false
    @State private var showEditProxySheet = false
    @State private var showDiagnosticsSheet = false
    @State private var selectedProxy: SurgeProxy?
    @State private var selectedGroup: SurgeProxyGroup?
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    proxySection
                    proxyGroupSection
                }
                .padding()
            }
        }
        .onAppear {
            loadSavedMode()
            // Delay config loading to avoid layout recursion
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                configManager.loadConfig()
            }
        }
        .sheet(isPresented: $showAddProxySheet) {
            SurgeProxyEditorView(mode: .add) { newProxy in
                configManager.addProxy(newProxy)
            }
        }
        .sheet(isPresented: $showEditProxySheet) {
            if let proxy = selectedProxy {
                SurgeProxyEditorView(mode: .edit(proxy)) { updatedProxy in
                    configManager.updateProxy(updatedProxy)
                }
            }
        }
        .sheet(isPresented: $showDiagnosticsSheet) {
            ProxyDiagnosticsView(
                proxies: configManager.proxies.map { $0.name },
                selectedProxy: selectedProxy?.name
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Policy")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Mode picker
                HStack(spacing: 0) {
                    ModeButton(
                        title: "Direct Outbound",
                        icon: "arrow.left.arrow.right",
                        isSelected: selectedMode == .direct
                    ) { selectedMode = .direct; switchProxyMode(.direct) }
                    
                    ModeButton(
                        title: "Global Proxy",
                        icon: "arrow.triangle.branch",
                        isSelected: selectedMode == .global
                    ) { selectedMode = .global; switchProxyMode(.global) }
                    
                    ModeButton(
                        title: "Rule-based Proxy",
                        icon: "line.3.horizontal.decrease.circle",
                        isSelected: selectedMode == .ruleBased,
                        isPrimary: true
                    ) { selectedMode = .ruleBased; switchProxyMode(.ruleBased) }
                }
            }
            
            Text(modeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    private var modeDescription: String {
        switch selectedMode {
        case .direct: return "所有请求直接连接，不使用代理。"
        case .global: return "所有请求通过代理服务器连接。"
        case .ruleBased: return "Using rule system to determine how to process requests."
        }
    }
    
    // MARK: - Proxy Section
    
    private var proxySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROXY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: testAllProxies) {
                    Text("Test All")
                }
                .buttonStyle(.bordered)
                .disabled(isTesting || configManager.proxies.isEmpty)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(configManager.proxies) { proxy in
                    SurgeProxyCardView(
                        proxy: proxy,
                        isSelected: selectedMode == .global && proxyManager.selectedProxy == proxy.name,
                        onTap: {
                            if selectedMode == .global {
                                setGlobalProxy(proxy.name)
                            } else {
                                testProxy(proxy)
                            }
                        },
                        onTest: { testProxy(proxy) },
                        onEdit: { selectedProxy = proxy; showEditProxySheet = true },
                        onDuplicate: { duplicateProxy(proxy) },
                        onDelete: { configManager.deleteProxy(name: proxy.name) },
                        onDiagnostics: { selectedProxy = proxy; showDiagnosticsSheet = true }
                    )
                }
                
                // Add Proxy Button
                AddCardButton(title: "Add Proxy") { showAddProxySheet = true }
            }
        }
    }
    
    // MARK: - Proxy Group Section
    
    private var proxyGroupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POLICY GROUP")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(configManager.proxyGroups) { group in
                    SurgeGroupCardView(
                        group: group,
                        onSwitch: { proxy in
                            switchProxyInGroup(group: group.name, proxy: proxy)
                        }
                    )
                }
                
                // Add Group Button
                AddCardButton(title: "Add Group") { }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadSavedMode() {
        if let savedMode = UserDefaults.standard.string(forKey: "ProxyMode"),
           let mode = PolicyMode(rawValue: savedMode) {
            selectedMode = mode
        }
    }
    
    private func switchProxyMode(_ mode: PolicyMode) {
        Task {
            do {
                UserDefaults.standard.set(mode.rawValue, forKey: "ProxyMode")
                try await APIClient.shared.setProxyMode(mode.apiValue)
                await proxyManager.refreshSystemStatus()
            } catch { }
        }
    }
    
    private func setGlobalProxy(_ name: String) {
        Task {
            do {
                try await APIClient.shared.setGlobalProxy(proxy: name)
                await proxyManager.refreshSystemStatus()
            } catch {
                print("Set global proxy failed: \(error)")
            }
        }
    }
    
    private func testAllProxies() {
        isTesting = true
        
        Task {
            for i in 0..<configManager.proxies.count {
                await MainActor.run {
                    configManager.proxies[i].testStatus = .testing
                }
            }
            
            await withTaskGroup(of: (String, Int?, String?).self) { group in
                for proxy in configManager.proxies {
                    group.addTask {
                        do {
                            let result = try await APIClient.shared.testProxy(
                                name: proxy.name,
                                url: "http://cp.cloudflare.com/generate_204"
                            )
                            return (proxy.name, result.latency, nil)
                        } catch {
                            return (proxy.name, nil, error.localizedDescription)
                        }
                    }
                }
                
                for await result in group {
                    if let index = configManager.proxies.firstIndex(where: { $0.name == result.0 }) {
                        await MainActor.run {
                            if let latency = result.1 {
                                configManager.proxies[index].latency = latency
                                configManager.proxies[index].testStatus = .success
                            } else {
                                configManager.proxies[index].testStatus = .failed
                            }
                        }
                    }
                }
            }
            
            await MainActor.run { isTesting = false }
        }
    }
    
    private func testProxy(_ proxy: SurgeProxy) {
        guard let index = configManager.proxies.firstIndex(where: { $0.name == proxy.name }) else { return }
        configManager.proxies[index].testStatus = .testing
        
        Task {
            do {
                let result = try await APIClient.shared.testProxy(
                    name: proxy.name,
                    url: "http://cp.cloudflare.com/generate_204"
                )
                await MainActor.run {
                    configManager.proxies[index].latency = result.latency
                    configManager.proxies[index].testStatus = .success
                }
            } catch {
                await MainActor.run {
                    configManager.proxies[index].testStatus = .failed
                }
            }
        }
    }
    
    private func duplicateProxy(_ proxy: SurgeProxy) {
        var newProxy = proxy
        newProxy.name = proxy.name + "-Copy"
        configManager.addProxy(newProxy)
    }
    
    private func switchProxyInGroup(group: String, proxy: String) {
        Task {
            do {
                try await APIClient.shared.switchProxyInGroup(group: group, proxy: proxy)
            } catch {
                print("切换代理失败: \(error)")
            }
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isPrimary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? (isPrimary ? Color.blue : Color.gray.opacity(0.3)) : Color.clear)
            .foregroundColor(isSelected ? (isPrimary ? .white : .primary) : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Surge Proxy Card View

struct SurgeProxyCardView: View {
    let proxy: SurgeProxy
    var isSelected: Bool = false
    let onTap: () -> Void
    let onTest: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDiagnostics: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Protocol Type
            HStack {
                Text(proxy.type.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if let latency = proxy.latency {
                    Spacer()
                    Text("\(latency) ms")
                        .font(.caption2)
                        .foregroundColor(latencyColor)
                }
            }
            
            // Name
            Text(proxy.name)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            // Status
            statusView
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 85, alignment: .leading)
        .background(cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : (isHovered ? Color.blue.opacity(0.5) : Color.clear), lineWidth: isSelected ? 3 : 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in isHovered = hovering }
        .contextMenu {
            Button("Edit Proxy...") { onEdit() }
            Button("Duplicate") { onDuplicate() }
            Button("Delete Proxy...", role: .destructive) { onDelete() }
            Divider()
            Button("Test Proxy Latency") { onTest() }
            Button("Diagnostics") { onDiagnostics() }
        }
        .onTapGesture { onTap() }
    }
    
    private var cardBackground: some View {
        Group {
            if proxy.testStatus == .failed {
                Color.red.opacity(0.1)
            } else if isHovered {
                Color.blue.opacity(0.1)
            } else {
                Color(NSColor.controlBackgroundColor)
            }
        }
    }
    
    private var latencyColor: Color {
        guard let ms = proxy.latency else { return .secondary }
        if ms < 200 { return .green }
        if ms < 500 { return .orange }
        return .red
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch proxy.testStatus {
        case .idle:
            Text("Tap to Test")
                .font(.caption)
                .foregroundColor(.blue)
        case .testing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Testing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .success:
            if let ms = proxy.latency {
                HStack(spacing: 4) {
                    Circle()
                        .fill(latencyColor)
                        .frame(width: 6, height: 6)
                    Text("\(ms) ms")
                        .font(.caption)
                        .foregroundColor(latencyColor)
                }
            }
        case .failed:
            Text("Failed")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Surge Group Card View

struct SurgeGroupCardView: View {
    let group: SurgeProxyGroup
    let onSwitch: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Group Type
            Text(group.displayType)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Name with emoji
            HStack(spacing: 6) {
                Text(group.emoji)
                    .font(.title3)
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Current selection or proxy chain
            if group.isChain {
                Text(group.proxies.joined(separator: " → "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else if let current = group.currentSelection ?? group.proxies.first {
                Text(current)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 85, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contextMenu {
            if group.isManual {
                ForEach(group.proxies, id: \.self) { proxy in
                    Button {
                        onSwitch(proxy)
                    } label: {
                        HStack {
                            Text(proxy)
                            if proxy == group.currentSelection {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } else {
                Text("Members: \(group.proxies.joined(separator: ", "))")
            }
        }
    }
}

// MARK: - Add Card Button

struct AddCardButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 85)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(.secondary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Surge Proxy Editor View

struct SurgeProxyEditorView: View {
    enum Mode {
        case add
        case edit(SurgeProxy)
    }
    
    let mode: Mode
    let onSave: (SurgeProxy) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var type: String = "vmess"
    @State private var server: String = ""
    @State private var port: String = "443"
    @State private var uuid: String = ""
    @State private var password: String = ""
    @State private var ws: Bool = false
    @State private var wsPath: String = ""
    @State private var tls: Bool = true
    @State private var sni: String = ""
    @State private var skipCertVerify: Bool = false
    
    init(mode: Mode, onSave: @escaping (SurgeProxy) -> Void) {
        self.mode = mode
        self.onSave = onSave
        
        if case .edit(let proxy) = mode {
            _name = State(initialValue: proxy.name)
            _type = State(initialValue: proxy.type)
            _server = State(initialValue: proxy.server)
            _port = State(initialValue: String(proxy.port))
            _uuid = State(initialValue: proxy.uuid ?? "")
            _password = State(initialValue: proxy.password ?? "")
            _ws = State(initialValue: proxy.ws)
            _wsPath = State(initialValue: proxy.wsPath ?? "")
            _tls = State(initialValue: proxy.tls)
            _sni = State(initialValue: proxy.sni ?? "")
            _skipCertVerify = State(initialValue: proxy.skipCertVerify)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode.isAdd ? "Add Proxy" : "Edit Proxy")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Basic") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        Text("VMess").tag("vmess")
                        Text("VLESS").tag("vless")
                        Text("Trojan").tag("trojan")
                        Text("Shadowsocks").tag("ss")
                        Text("Hysteria2").tag("hysteria2")
                        Text("HTTP").tag("http")
                        Text("SOCKS5").tag("socks5")
                    }
                }
                
                Section("Server") {
                    TextField("Server Address", text: $server)
                    TextField("Port", text: $port)
                }
                
                Section("Authentication") {
                    if type == "vmess" || type == "vless" {
                        SecureField("UUID", text: $uuid)
                    }
                    if type == "trojan" || type == "ss" {
                        SecureField("Password", text: $password)
                    }
                }
                
                Section("Transport") {
                    Toggle("WebSocket", isOn: $ws)
                    if ws {
                        TextField("WebSocket Path", text: $wsPath)
                    }
                }
                
                Section("TLS") {
                    Toggle("Enable TLS", isOn: $tls)
                    if tls {
                        TextField("SNI", text: $sni)
                        Toggle("Skip Certificate Verify", isOn: $skipCertVerify)
                    }
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    saveProxy()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || server.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
    }
    
    private func saveProxy() {
        var proxy = SurgeProxy(
            name: name,
            type: type,
            server: server,
            port: Int(port) ?? 443
        )
        
        proxy.uuid = uuid.isEmpty ? nil : uuid
        proxy.password = password.isEmpty ? nil : password
        proxy.ws = ws
        proxy.wsPath = wsPath.isEmpty ? nil : wsPath
        proxy.tls = tls
        proxy.sni = sni.isEmpty ? nil : sni
        proxy.skipCertVerify = skipCertVerify
        
        onSave(proxy)
    }
}

extension SurgeProxyEditorView.Mode {
    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
}

// Keep legacy types for compatibility
struct ProxyServer: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    var status: String
    var testURL: String?
    var latency: Int?
}

#Preview {
    NewPolicyView()
        .environmentObject(GoProxyManager())
        .frame(width: 1000, height: 800)
}
