//
//  ProxyServerDetailView.swift
//  SurgeProxy
//
//  Proxy server detail and configuration view
//

import SwiftUI

struct ProxyServerDetailView: View {
    @Binding var proxy: ProxyServer
    @State private var customTestURL: String
    @State private var useCustomURL: Bool
    
    @Environment(\.dismiss) var dismiss
    
    init(proxy: Binding<ProxyServer>) {
        self._proxy = proxy
        self._customTestURL = State(initialValue: proxy.wrappedValue.testURL ?? "")
        self._useCustomURL = State(initialValue: proxy.wrappedValue.testURL != nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Proxy Server Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    HStack {
                        Text("Name:")
                            .frame(width: 120, alignment: .trailing)
                        Text(proxy.name)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Location:")
                            .frame(width: 120, alignment: .trailing)
                        Text(proxy.location)
                    }
                    
                    HStack {
                        Text("Status:")
                            .frame(width: 120, alignment: .trailing)
                        Text(proxy.status)
                            .foregroundColor(statusColor)
                    }
                    
                    if let latency = proxy.latency {
                        HStack {
                            Text("Latency:")
                                .frame(width: 120, alignment: .trailing)
                            Text("\(latency) ms")
                                .foregroundColor(latencyColor(latency))
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $useCustomURL) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Custom Test URL")
                                .font(.headline)
                            Text("Override the default proxy testing URL for this server")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if useCustomURL {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Test URL:")
                                    .frame(width: 120, alignment: .trailing)
                                TextField("http://connect.rom.miui.com/generate_204", text: $customTestURL)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Text("Leave empty to use the default proxy testing URL from Settings > Advanced")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 120)
                        }
                        .padding(.leading, 20)
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        Button("Test Now") {
                            testProxy()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 400)
    }
    
    private var statusColor: Color {
        if proxy.status.contains("OK") || proxy.status.contains("ms") {
            return .green
        } else if proxy.status == "Tap to Test" {
            return .blue
        } else {
            return .red
        }
    }
    
    private func latencyColor(_ latency: Int) -> Color {
        if latency < 100 { return .green }
        if latency < 300 { return .orange }
        return .red
    }
    
    private func saveChanges() {
        if useCustomURL && !customTestURL.isEmpty {
            proxy.testURL = customTestURL
        } else {
            proxy.testURL = nil
        }
    }
    
    private func testProxy() {
        // Implement proxy testing
        proxy.status = "Testing..."
        
        let testManager = ProxyTestManager()
        let testURL = proxy.testURL ?? "http://connect.rom.miui.com/generate_204"
        
        // For demo, test as HTTP proxy
        testManager.testHTTPProxy(
            proxyURL: "http://localhost:8888",
            testURL: testURL
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let testResult):
                    if testResult.success {
                        proxy.latency = testResult.latency
                        proxy.status = "\(testResult.latency) ms"
                    } else {
                        proxy.status = "Failed: \(testResult.error ?? "Unknown error")"
                    }
                case .failure(let error):
                    proxy.status = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ProxyServerDetailView(proxy: .constant(ProxyServer(
        name: "YN-AI",
        location: "YN-AI",
        status: "Tap to Test",
        testURL: nil,
        latency: nil
    )))
}
