//
//  DiagnosticsView.swift
//  SurgeProxy
//
//  Network diagnostics and testing view
//

import SwiftUI

struct DiagnosticsView: View {
    @Environment(\.dismiss) var dismiss
    
    enum Tab {
        case network, rule, dns
    }
    @State private var selection: Tab = .network
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Picker
            HStack {
                Text("Diagnostics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("", selection: $selection) {
                    Text("Network").tag(Tab.network)
                    Text("Rule Match").tag(Tab.rule)
                    Text("DNS Lookup").tag(Tab.dns)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            switch selection {
            case .network:
                NetworkDiagnosticsInnerView()
            case .rule:
                RuleMatchView()
            case .dns:
                DNSLookupView()
            }
        }
        .frame(width: 800, height: 600)
    }
}

// Extracted original diagnostics view logic
struct NetworkDiagnosticsInnerView: View {
    @State private var logs: [DiagnosticLog] = []
    @State private var isTesting = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
                Button("Run Again") {
                   runDiagnostics()
                }
                .disabled(isTesting)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Text(log.timestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                            
                            Text(log.message)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(log.color)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            if logs.isEmpty {
                runDiagnostics()
            }
        }
    }
    
    private func appendLog(_ message: String, color: Color = .primary) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let log = DiagnosticLog(timestamp: timestamp, message: message, color: color)
        
        Task { @MainActor in
            logs.append(log)
        }
    }
    
    private func runDiagnostics() {
        logs = []
        isTesting = true
        
        Task {
            // 1. General Network Info
            appendLog("Checking Network Interfaces...", color: .blue)
            do {
                let (gateway, iface) = try await APIClient.shared.fetchSystemGateway()
                appendLog("Primary Interface: \(iface)", color: .secondary)
                
                // Test Latency to Gateway
                let start = Date()
                let url = URL(string: "http://\(gateway)")!
                var req = URLRequest(url: url)
                req.timeoutInterval = 2
                req.httpMethod = "HEAD"
                _ = try? await URLSession.shared.data(for: req)
                let dur = Int(Date().timeIntervalSince(start) * 1000)
                appendLog("Router: \(gateway) (Latency: \(dur) ms)", color: .secondary)
            } catch {
                appendLog("Failed to detect network info: \(error.localizedDescription)", color: .red)
            }
            
            // 2. DNS
            appendLog("\nTesting DNS Resolvers...", color: .blue)
            do {
                let dnsResults = try await APIClient.shared.fetchDNSDiagnostics()
                for (server, latency) in dnsResults {
                    if latency < 0 {
                        appendLog("DNS Server \(server): Timeout/Error", color: .red)
                    } else {
                        appendLog("Answer from \(server): \(latency) ms", color: .green)
                    }
                }
                if dnsResults.isEmpty {
                    appendLog("No upstream DNS servers configured or system DNS only.", color: .orange)
                }
            } catch {
                appendLog("Failed to test DNS: \(error.localizedDescription)", color: .red)

            }
            
            // 3. Direct Policy
            appendLog("\nTesting Direct Policy...", color: .blue)
            do {
                let directRes = try await APIClient.shared.testDirect()
                if let lat = directRes.latency {
                    appendLog("Direct connection to http://www.bing.com: \(lat) ms", color: .green)
                } else {
                     appendLog("Direct connection failed: \(directRes.error ?? "Unknown")", color: .red)
                }
            } catch {
                appendLog("Direct test failed: \(error.localizedDescription)", color: .red)
            }
            
            // 4. Proxy Policies
            appendLog("\nTesting Proxies...", color: .blue)
            do {
                let proxies = try await APIClient.shared.fetchAllProxies()
                
                for proxy in proxies {
                    // Skip DIRECT/REJECT
                    let type = proxy.type.lowercased()
                    if type == "direct" || type == "reject" { continue }
                    
                    do {
                        let res = try await APIClient.shared.testProxy(name: proxy.name, url: "http://cp.cloudflare.com/generate_204")
                        if let lat = res.latency {
                            appendLog("Proxy '\(proxy.name)': \(lat) ms", color: .green)
                        } else {
                            appendLog("Proxy '\(proxy.name)': Timeout \(res.error != nil ? "(\(res.error!))" : "")", color: .red)
                        }
                    } catch {
                        appendLog("Proxy '\(proxy.name)': Error", color: .red)
                    }
                }
            } catch {
                appendLog("Failed to fetch proxy list: \(error.localizedDescription)", color: .red)
            }
            
            await MainActor.run {
                isTesting = false
                appendLog("\nDiagnostics Completed.", color: .blue)
            }
        }
    }
}

struct DiagnosticLog: Identifiable {
    let id = UUID()
    let timestamp: String
    let message: String
    let color: Color
}
