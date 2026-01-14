//
//  ProxyManagementView.swift
//  SurgeProxy
//
//  Proxy list management and editor
//

import SwiftUI

struct ProxyManagementView: View {
    @StateObject private var viewModel = ProxyManagementViewModel()
    @State private var showingAddSheet = false
    @State private var selectedProxy: ProxyConfigModel?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.proxies) { proxy in
                    ProxyRow(proxy: proxy)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProxy = proxy
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteProxy(name: proxy.name)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("代理服务器")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadProxies()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ProxyEditorSheet(mode: .add) { proxy in
                    await viewModel.addProxy(proxy)
                }
            }
            .sheet(item: $selectedProxy) { proxy in
                ProxyEditorSheet(mode: .edit(proxy)) { updatedProxy in
                    await viewModel.updateProxy(name: proxy.name, proxy: updatedProxy)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("加载中...")
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

// MARK: - Proxy Row

struct ProxyRow: View {
    let proxy: ProxyConfigModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: proxyIcon)
                    .foregroundColor(proxyColor)
                    .font(.title3)
                
                Text(proxy.name)
                    .font(.headline)
                
                Spacer()
                
                Text(proxy.type.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(proxyColor.opacity(0.2))
                    .foregroundColor(proxyColor)
                    .cornerRadius(4)
            }
            
            HStack {
                Image(systemName: "server.rack")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(proxy.server):\(proxy.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if proxy.tls == true {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var proxyIcon: String {
        switch proxy.type {
        case "vmess": return "v.circle.fill"
        case "vless": return "v.square.fill"
        case "ss", "shadowsocks": return "s.circle.fill"
        case "trojan": return "t.circle.fill"
        case "hysteria2": return "h.circle.fill"
        default: return "network"
        }
    }
    
    private var proxyColor: Color {
        switch proxy.type {
        case "vmess": return .blue
        case "vless": return .purple
        case "ss", "shadowsocks": return .orange
        case "trojan": return .red
        case "hysteria2": return .pink
        default: return .gray
        }
    }
}

// MARK: - Proxy Editor Sheet

struct ProxyEditorSheet: View {
    enum Mode {
        case add
        case edit(ProxyConfigModel)
    }
    
    let mode: Mode
    let onSave: (ProxyConfigModel) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProxyEditorViewModel
    
    init(mode: Mode, onSave: @escaping (ProxyConfigModel) async -> Void) {
        self.mode = mode
        self.onSave = onSave
        
        switch mode {
        case .add:
            _viewModel = StateObject(wrappedValue: ProxyEditorViewModel())
        case .edit(let proxy):
            _viewModel = StateObject(wrappedValue: ProxyEditorViewModel(proxy: proxy))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $viewModel.name)
                    
                    Picker("类型", selection: $viewModel.type) {
                        ForEach(ProxyType.allCases.filter { ![.direct, .reject].contains($0) }, id: \.self) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                }
                
                Section(header: Text("服务器")) {
                    TextField("服务器地址", text: $viewModel.server)
                    
                    TextField("端口", value: $viewModel.port, format: .number)
                }
                
                Section(header: Text("认证")) {
                    if viewModel.type == "vmess" || viewModel.type == "vless" {
                        TextField("UUID", text: $viewModel.username)
                    } else {
                        TextField(viewModel.type == "ss" ? "加密方式" : "密码", text: $viewModel.password)
                    }
                }
                
                Section(header: Text("传输")) {
                    Toggle("TLS", isOn: $viewModel.tls)
                    
                    if viewModel.tls {
                        TextField("SNI", text: $viewModel.sni)
                        Toggle("跳过证书验证", isOn: $viewModel.skipCertVerify)
                    }
                    
                    Toggle("WebSocket", isOn: $viewModel.useWebSocket)
                    
                    if viewModel.useWebSocket {
                        TextField("WS 路径", text: $viewModel.wsPath)
                    }
                }
            }
            .navigationTitle(mode.isEdit ? "编辑代理" : "添加代理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let proxy = viewModel.buildProxy()
                            await onSave(proxy)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}

extension ProxyEditorSheet.Mode {
    var isEdit: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}

// MARK: - View Models

@MainActor
class ProxyManagementViewModel: ObservableObject {
    @Published var proxies: [ProxyConfigModel] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadProxies() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            proxies = try await apiClient.fetchAllProxies()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func addProxy(_ proxy: ProxyConfigModel) async {
        do {
            try await apiClient.addProxy(proxy)
            await loadProxies()
        } catch {
            errorMessage = "添加失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func updateProxy(name: String, proxy: ProxyConfigModel) async {
        do {
            try await apiClient.updateProxy(name: name, proxy: proxy)
            await loadProxies()
        } catch {
            errorMessage = "更新失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func deleteProxy(name: String) async {
        do {
            try await apiClient.deleteProxy(name: name)
            await loadProxies()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

@MainActor
class ProxyEditorViewModel: ObservableObject {
    @Published var name = ""
    @Published var type = "vmess"
    @Published var server = ""
    @Published var port = 443
    @Published var username = ""
    @Published var password = ""
    @Published var tls = true
    @Published var sni = ""
    @Published var skipCertVerify = false
    @Published var useWebSocket = false
    @Published var wsPath = "/"
    
    init(proxy: ProxyConfigModel? = nil) {
        if let proxy = proxy {
            self.name = proxy.name
            self.type = proxy.type
            self.server = proxy.server
            self.port = proxy.port
            self.username = proxy.username ?? ""
            self.password = proxy.password ?? ""
            self.tls = proxy.tls ?? false
            self.sni = proxy.sni ?? ""
            self.skipCertVerify = proxy.skipCertVerify ?? false
            
            if let params = proxy.parameters {
                self.useWebSocket = params["ws"] == "true"
                self.wsPath = params["ws-path"] ?? "/"
            }
        }
    }
    
    var isValid: Bool {
        !name.isEmpty && !server.isEmpty && port > 0 && port <= 65535
    }
    
    func buildProxy() -> ProxyConfigModel {
        var parameters: [String: String] = [:]
        
        if useWebSocket {
            parameters["ws"] = "true"
            parameters["ws-path"] = wsPath
        }
        
        return ProxyConfigModel(
            name: name,
            type: type,
            server: server,
            port: port,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            auth: nil,
            tls: tls,
            sni: sni.isEmpty ? nil : sni,
            skipCertVerify: skipCertVerify,
            tfo: nil,
            udp: nil,
            parameters: parameters.isEmpty ? nil : parameters
        )
    }
}

#Preview {
    ProxyManagementView()
}
