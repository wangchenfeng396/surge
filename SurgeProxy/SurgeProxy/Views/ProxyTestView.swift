//
//  ProxyTestView.swift
//  SurgeProxy
//
//  Proxy testing and latency measurement
//

import SwiftUI

struct ProxyTestView: View {
    @StateObject private var viewModel = ProxyTestViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("批量测试")) {
                    HStack {
                        TextField("测试 URL", text: $viewModel.testURL)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("测试全部") {
                            Task {
                                await viewModel.testAllProxies()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isTesting)
                    }
                }
                
                Section(header: Text("代理列表")) {
                    ForEach(viewModel.proxyResults) { result in
                        ProxyTestResultRow(result: result, onTest: {
                            Task {
                                await viewModel.testSingleProxy(name: result.name)
                            }
                        })
                    }
                }
            }
            .navigationTitle("代理测速")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await viewModel.loadProxies()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
        .task {
            await viewModel.loadProxies()
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

// MARK: - Proxy Test Result Row

struct ProxyTestResultRow: View {
    let result: ProxyTestResult
    let onTest: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline)
                
                if let server = result.server {
                    Text("\(server):\(result.port ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if result.isTesting {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let latency = result.latency {
                HStack(spacing: 4) {
                    Circle()
                        .fill(latencyColor(latency))
                        .frame(width: 8, height: 8)
                    
                    Text("\(latency) ms")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(latencyColor(latency))
                }
            } else if result.failed {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("失败")
                        .font(.caption)
                        .foregroundColor(.red)
                    if let error = result.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Button(action: onTest) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func latencyColor(_ latency: Int) -> Color {
        if latency < 100 {
            return .green
        } else if latency < 300 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Models

struct ProxyTestResult: Identifiable {
    let id = UUID()
    let name: String
    var server: String?
    var port: Int?
    var latency: Int?
    var isTesting: Bool = false
    var failed: Bool = false
    var errorMessage: String?  // 新增：存储具体错误信息
}

// MARK: - View Model

@MainActor
class ProxyTestViewModel: ObservableObject {
    @Published var proxyResults: [ProxyTestResult] = []
    @Published var testURL = "http://cp.cloudflare.com/generate_204"
    @Published var isLoading = false
    @Published var isTesting = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadProxies() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let proxies = try await apiClient.fetchAllProxies()
            proxyResults = proxies.map { proxy in
                ProxyTestResult(
                    name: proxy.name,
                    server: proxy.server,
                    port: proxy.port
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func testAllProxies() async {
        guard !isTesting else { return }
        isTesting = true
        defer { isTesting = false }
        
        // Test each proxy
        for index in proxyResults.indices {
            proxyResults[index].isTesting = true
            proxyResults[index].latency = nil
            proxyResults[index].failed = false
            proxyResults[index].errorMessage = nil
            
            let (latency, error) = await measureLatency(proxyName: proxyResults[index].name)
            
            proxyResults[index].isTesting = false
            if let latency = latency {
                proxyResults[index].latency = latency
            } else {
                proxyResults[index].failed = true
                proxyResults[index].errorMessage = error
            }
        }
    }
    
    func testSingleProxy(name: String) async {
        guard let index = proxyResults.firstIndex(where: { $0.name == name }) else {
            return
        }
        
        proxyResults[index].isTesting = true
        proxyResults[index].latency = nil
        proxyResults[index].failed = false
        proxyResults[index].errorMessage = nil
        
        let (latency, error) = await measureLatency(proxyName: name)
        
        proxyResults[index].isTesting = false
        if let latency = latency {
            proxyResults[index].latency = latency
        } else {
            proxyResults[index].failed = true
            proxyResults[index].errorMessage = error
        }
    }
    
    private func measureLatency(proxyName: String) async -> (latency: Int?, error: String?) {
        do {
            // Call test API
            let result = try await apiClient.testProxy(name: proxyName, url: testURL)
            return (result.latency, result.error)
        } catch let error as NSError {
            // 提取更具体的错误信息
            if error.code == -1001 {
                return (nil, "请求超时")
            } else if error.code == -1009 {
                return (nil, "无网络连接")
            } else {
                return (nil, "连接失败")
            }
        }
    }
}

#Preview {
    ProxyTestView()
}
