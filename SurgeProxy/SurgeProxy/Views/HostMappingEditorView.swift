//
//  HostMappingEditorView.swift
//  SurgeProxy
//
//  Host mapping (DNS override) management
//

import SwiftUI

struct HostMappingEditorView: View {
    @StateObject private var viewModel = HostMappingViewModel()
    @State private var showingAddHost = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hosts.isEmpty {
                    emptyState
                } else {
                    hostList
                }
            }
            .navigationTitle("Host 映射")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddHost = true }) {
                        Label("添加映射", systemImage: "plus")
                    }
                    .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadHosts()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddHost) {
                HostMappingEditorSheet(host: nil) { domain, value in
                    Task {
                        await viewModel.addHost(domain: domain, value: value)
                        if viewModel.errorMessage != nil {
                            errorMessage = viewModel.errorMessage ?? "添加失败"
                            showingError = true
                        }
                    }
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .task {
                await viewModel.loadHosts()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("无 Host 映射")
                .font(.title2)
            Text("创建 DNS 覆盖规则来自定义域名解析")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("添加第一条映射") {
                showingAddHost = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var hostList: some View {
        List {
            ForEach(viewModel.hosts, id: \.domain) { host in
                HostMappingRow(host: host)
                    .contextMenu {
                        Button("删除", role: .destructive) {
                            Task {
                                await viewModel.deleteHost(domain: host.domain)
                                if viewModel.errorMessage != nil {
                                    errorMessage = viewModel.errorMessage ?? "删除失败"
                                    showingError = true
                                }
                            }
                        }
                    }
            }
        }
    }
}

struct HostMappingRow: View {
    let host: HostMapping
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(host.domain)
                    .font(.system(.body, design: .monospaced))
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(host.value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

struct HostMappingEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var domain: String
    @State private var value: String
    
    let onSave: (String, String) -> Void
    
    init(host: HostMapping?, onSave: @escaping (String, String) -> Void) {
        self._domain = State(initialValue: host?.domain ?? "")
        self._value = State(initialValue: host?.value ?? "")
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("域名") {
                    TextField("例如：example.com", text: $domain)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                    Text("要映射的域名或主机名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("目标") {
                    TextField("IP 地址", text: $value)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                    Text("IP 地址（IPv4 或 IPv6）或别名域名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Text("示例：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("test.local → 127.0.0.1")
                        .font(.system(.caption, design: .monospaced))
                    Text("api.example.com → 192.168.1.10")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle(domain.isEmpty ? "新增 Host 映射" : "编辑映射")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(domain, value)
                        dismiss()
                    }
                    .disabled(domain.isEmpty || value.isEmpty)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class HostMappingViewModel: ObservableObject {
    @Published var hosts: [HostMapping] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadHosts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            hosts = try await apiClient.fetchHosts()
            errorMessage = nil
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    func addHost(domain: String, value: String) async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await apiClient.addHost(domain: domain, value: value)
            await loadHosts()
            errorMessage = nil
        } catch {
            errorMessage = "添加失败: \(error.localizedDescription)"
        }
    }
    
    func deleteHost(domain: String) async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await apiClient.deleteHost(domain: domain)
            await loadHosts()
            errorMessage = nil
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
}

#Preview {
    HostMappingEditorView()
}
