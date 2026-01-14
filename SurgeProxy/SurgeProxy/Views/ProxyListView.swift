//
//  ProxyListView.swift
//  SurgeProxy
//
//  Display and manage proxies from sing-box backend
//

import SwiftUI

struct ProxyListView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var proxies: [String] = []
    @State private var selectedProxy: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Proxies")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(proxyManager.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(proxyManager.isRunning ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: refreshProxies) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            
            Divider()
            
            // Proxy list
            if isLoading {
                ProgressView("Loading proxies...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        refreshProxies()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if proxies.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "network.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No proxies configured")
                        .foregroundColor(.secondary)
                    Text("Import a Surge configuration to add proxies")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(proxies, id: \.self, selection: $selectedProxy) { proxy in
                    ProxyStatusRow(
                        name: proxy,
                        isConnected: proxy == proxyManager.selectedProxy,
                        isSelected: proxy == proxyManager.selectedProxy
                    )
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            refreshProxies()
        }
    }
    
    private func refreshProxies() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await APIClient.shared.fetchProxies()
                await MainActor.run {
                    self.proxies = response.proxies.map { $0.name }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load proxies: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct ProxyStatusRow: View {
    let name: String
    let isConnected: Bool
    let isSelected: Bool
    @State private var isEnabled = true
    
    var body: some View {
        HStack {
            // Proxy icon
            Image(systemName: "network")
                .foregroundColor(isEnabled ? .blue : .gray)
                .frame(width: 24)
            
            // Proxy name
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                if !isEnabled {
                    Text("Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Connection/Selection Indicator
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
            
            // Enable/Disable toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isEnabled) { newValue in
                    toggleProxy(enabled: newValue)
                }
        }
        .padding(.vertical, 4)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private func toggleProxy(enabled: Bool) {
        Task {
            do {
                try await APIClient.shared.toggleProxy(name: name, enabled: enabled)
            } catch {
                // Revert toggle on error
                await MainActor.run {
                    isEnabled = !enabled
                }
            }
        }
    }
}

#Preview {
    ProxyListView()
        .environmentObject(GoProxyManager())
        .frame(width: 600, height: 400)
}
