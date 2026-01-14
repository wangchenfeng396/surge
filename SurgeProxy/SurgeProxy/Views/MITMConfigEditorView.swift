//
//  MITMConfigEditorView.swift
//  SurgeProxy
//
//  MITM (Man-in-the-Middle) configuration editor
//

import SwiftUI

struct MITMConfigEditorView: View {
    @StateObject private var viewModel = MITMConfigViewModel()
    @State private var showingAddHostname = false
    @State private var showingAddDisabledHostname = false
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.isLoading {
                    Section {
                        ProgressView("加载中...")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    // MITM 开关
                    Section(header: Text("MITM 功能")) {
                        Toggle("启用 MITM", isOn: $viewModel.enabled)
                        
                        if viewModel.enabled {
                            Toggle("跳过服务器证书验证", isOn: $viewModel.skipServerCertVerify)
                            Toggle("TCP 连接", isOn: $viewModel.tcpConnection)
                            Toggle("HTTP/2 支持", isOn: $viewModel.h2)
                            Toggle("自动阻止 QUIC", isOn: $viewModel.autoQuicBlock)
                        }
                    }
                    
                    // 证书设置
                    if viewModel.enabled {
                        Section(header: Text("证书设置")) {
                            HStack {
                                Text("CA 证书")
                                Spacer()
                                if !viewModel.caP12.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("已配置")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("未配置")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            SecureField("CA 密码", text: $viewModel.caPassphrase)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Hostname 配置
                        Section(header: Text("拦截的主机名")) {
                            ForEach(viewModel.hostnameList.indices, id: \.self) { index in
                                HStack {
                                    TextField("例如：*.example.com", text: $viewModel.hostnameList[index])
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Button(action: {
                                        viewModel.hostnameList.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            Button(action: {
                                viewModel.hostnameList.append("")
                            }) {
                                Label("添加主机名", systemImage: "plus.circle.fill")
                            }
                            
                            Text("支持通配符，例如 *.apple.com")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Disabled Hostname 配置
                        Section(header: Text("排除的主机名")) {
                            ForEach(viewModel.hostnameDisabledList.indices, id: \.self) { index in
                                HStack {
                                    TextField("例如：sub.example.com", text: $viewModel.hostnameDisabledList[index])
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Button(action: {
                                        viewModel.hostnameDisabledList.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            Button(action: {
                                viewModel.hostnameDisabledList.append("")
                            }) {
                                Label("添加排除", systemImage: "plus.circle.fill")
                            }
                            
                            Text("这些主机名将不会被拦截")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 说明
                    Section(header: Text("关于 MITM")) {
                        Text("MITM (Man-in-the-Middle) 功能允许 Surge 解密 HTTPS 流量，进行 Header 重写和脚本处理。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("⚠️ 使用 MITM 需要在设备上安装并信任 Surge 的 CA 证书。")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("MITM 配置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await viewModel.saveConfiguration()
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isLoading)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadConfiguration()
                        }
                    }
                }
            }
            .alert("保存结果", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                if viewModel.saveSuccess {
                    Text("MITM 配置已成功保存")
                } else if let error = viewModel.errorMessage {
                    Text("保存失败: \(error)")
                }
            }
            .task {
                await viewModel.loadConfiguration()
            }
        }
    }
}

// MARK: - View Model

@MainActor
class MITMConfigViewModel: ObservableObject {
    @Published var enabled = false
    @Published var skipServerCertVerify = false
    @Published var tcpConnection = false
    @Published var h2 = false
    @Published var hostnameList: [String] = []
    @Published var hostnameDisabledList: [String] = []
    @Published var autoQuicBlock = false
    @Published var caPassphrase = ""
    @Published var caP12 = ""
    
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saveSuccess = false
    @Published var showAlert = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadConfiguration() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let config = try await apiClient.fetchMITMConfig()
            
            enabled = config.enabled ?? false
            skipServerCertVerify = config.skipServerCertVerify ?? false
            tcpConnection = config.tcpConnection ?? false
            h2 = config.h2 ?? false
            hostnameList = config.hostname ?? []
            hostnameDisabledList = config.hostnameDisabled ?? []
            autoQuicBlock = config.autoQuicBlock ?? false
            caPassphrase = config.caPassphrase ?? ""
            caP12 = config.caP12 ?? ""
            
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func saveConfiguration() async {
        isSaving = true
        saveSuccess = false
        defer { isSaving = false }
        
        let config = MITMConfig(
            enabled: enabled,
            skipServerCertVerify: skipServerCertVerify,
            tcpConnection: tcpConnection,
            h2: h2,
            hostname: hostnameList.filter { !$0.isEmpty },
            hostnameDisabled: hostnameDisabledList.filter { !$0.isEmpty },
            autoQuicBlock: autoQuicBlock,
            caPassphrase: caPassphrase.isEmpty ? nil : caPassphrase,
            caP12: caP12.isEmpty ? nil : caP12
        )
        
        do {
            try await apiClient.updateMITMConfig(config)
            saveSuccess = true
            errorMessage = nil
            showAlert = true
        } catch {
            saveSuccess = false
            errorMessage = error.localizedDescription
            showAlert = true
        }
    }
}

#Preview {
    MITMConfigEditorView()
}
