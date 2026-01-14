//
//  ProxyGroupsView.swift
//  SurgeProxy
//
//  Display and manage proxy groups
//
//

import SwiftUI

struct ProxyGroupsView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var groups: [ProxyGroupViewModel] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Proxy Groups")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button(action: refreshGroups) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            
            if let errorMsg = errorMsg {
                Text(errorMsg)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom, 4)
            }
            
            Divider()
            
            // Groups list
            if groups.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No proxy groups found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($groups) { $group in
                        ProxyGroupRowView(group: $group, onUpdate: refreshGroups)
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            refreshGroups()
        }
    }
    
    private func refreshGroups() {
        guard !isLoading else { return }
        isLoading = true
        errorMsg = nil
        
        Task {
            do {
                // Fetch config (static definition of groups and their proxies)
                let configGroups = try await APIClient.shared.fetchAllProxyGroups()
                
                // Fetch runtime status (current selection)
                // Note: /api/proxies returns runtime info for groups
                let runtimeInfo = try await APIClient.shared.fetchProxies()
                let runtimeMap = Dictionary(uniqueKeysWithValues: runtimeInfo.proxies.map { ($0.name, $0) })
                
                // Merge info
                var newGroups: [ProxyGroupViewModel] = []
                
                for cfg in configGroups {
                    let runtime = runtimeMap[cfg.name]
                    let proxies = cfg.proxies.map { ProxyItem(name: $0) }
                    
                    newGroups.append(ProxyGroupViewModel(
                        id: cfg.name,
                        name: cfg.name,
                        type: cfg.type,
                        proxies: proxies,
                        selectedProxy: runtime?.now
                    ))
                }
                
                await MainActor.run {
                    self.groups = newGroups
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMsg = "Failed to load: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct ProxyGroupRowView: View {
    @Binding var group: ProxyGroupViewModel
    var onUpdate: () -> Void
    
    @State private var isTestRunning = false
    @State private var showingSwitchConfirmation = false
    @State private var tempSelectedProxy: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Name, Type, Test Button
            HStack {
                Text(group.name)
                    .font(.headline)
                
                Text(group.type.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.2))
                    .foregroundColor(typeColor)
                    .cornerRadius(4)
                
                Spacer()
                
                // Test Button
                Button(action: testLatency) {
                    if isTestRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "speedometer")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTestRunning)
                .help("Test Latency")
            }
            
            // Proxies List logic
            if group.type == "select" || group.type == "relay" {
                // Selectable list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(group.proxies) { proxy in
                        HStack {
                            // Selection Indicator
                            Image(systemName: proxy.name == group.selectedProxy ? "record.circle.fill" : "circle")
                                .foregroundColor(proxy.name == group.selectedProxy ? .green : .gray)
                                .onTapGesture {
                                    if group.type == "select" {
                                        switchProxy(to: proxy.name)
                                    }
                                }
                            
                            Text(proxy.name)
                                .foregroundColor(proxy.name == group.selectedProxy ? .primary : .secondary)
                            
                            Spacer()
                            
                            // Latency
                            if let lat = proxy.latency {
                                Text("\(lat) ms")
                                    .font(.caption)
                                    .foregroundColor(latencyColor(lat))
                            } else if let err = proxy.error {
                                Text("Error")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .help(err)
                            }
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            } else {
                // URL-Test / Load-Balance / Fallback: Read-only list mostly, but showing "now"
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(group.proxies) { proxy in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(proxy.name)
                                        .font(.subheadline)
                                        .fontWeight(proxy.name == group.selectedProxy ? .bold : .regular)
                                    
                                    if proxy.name == group.selectedProxy {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                if let lat = proxy.latency {
                                    Text("\(lat) ms")
                                        .font(.caption2)
                                        .foregroundColor(latencyColor(lat))
                                }
                            }
                            .padding(8)
                            .background(proxy.name == group.selectedProxy ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(proxy.name == group.selectedProxy ? Color.green : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func switchProxy(to name: String) {
        // Only SelectGroup allows manual switch
        guard group.type == "select" else { return }
        guard name != group.selectedProxy else { return }
        
        Task {
            do {
                try await APIClient.shared.switchProxyInGroup(group: group.name, proxy: name)
                await MainActor.run {
                    group.selectedProxy = name
                }
            } catch {
                print("Failed to switch proxy: \(error)")
            }
        }
    }
    
    private func testLatency() {
        isTestRunning = true
        
        // Parallel testing for all proxies in the group
        Task {
            await withTaskGroup(of: (String, Int?, String?).self) { taskGroup in
                for proxy in group.proxies {
                    taskGroup.addTask {
                        do {
                            let response = try await APIClient.shared.testProxy(name: proxy.name, url: "http://cp.cloudflare.com/generate_204")
                            return (proxy.name, response.latency, nil)
                        } catch {
                            return (proxy.name, nil, error.localizedDescription)
                        }
                    }
                }
                
                for await result in taskGroup {
                    if let index = group.proxies.firstIndex(where: { $0.name == result.0 }) {
                        await MainActor.run {
                            group.proxies[index].latency = result.1
                            group.proxies[index].error = result.2
                        }
                    }
                }
            }
            
            await MainActor.run {
                isTestRunning = false
            }
        }
    }
    
    private var typeColor: Color {
        switch group.type {
        case "select": return .blue
        case "url-test": return .green
        case "relay": return .purple
        case "fallback": return .orange
        case "load-balance": return .teal
        default: return .gray
        }
    }
    
    private func latencyColor(_ ms: Int) -> Color {
        if ms < 200 { return .green }
        if ms < 500 { return .yellow }
        return .orange
    }
}

// ViewModel
struct ProxyGroupViewModel: Identifiable {
    let id: String
    let name: String
    let type: String
    var proxies: [ProxyItem]
    var selectedProxy: String?
}

struct ProxyItem: Identifiable {
    var id: String { name }
    let name: String
    var latency: Int?
    var error: String?
}
