//
//  GeneralConfigView.swift
//  SurgeProxy
//
//  General configuration settings view
//

import SwiftUI

struct GeneralConfigView: View {
    @StateObject private var viewModel = GeneralConfigViewModel()
    @State private var showingSaveAlert = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationView {
            Form {
                // 日志设置
                Section(header: Text("日志设置")) {
                    Picker("日志级别", selection: $viewModel.loglevel) {
                        Text("Verbose").tag("verbose")
                        Text("Info").tag("info")
                        Text("Notify").tag("notify")
                        Text("Warning").tag("warning")
                    }
                    .pickerStyle(.segmented)
                }
                
                // DNS 设置
                Section(header: Text("DNS 设置")) {
                    ForEach(viewModel.dnsServers.indices, id: \.self) { index in
                        HStack {
                            TextField("DNS 服务器", text: $viewModel.dnsServers[index])
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: {
                                viewModel.dnsServers.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.dnsServers.append("")
                    }) {
                        Label("添加 DNS 服务器", systemImage: "plus.circle.fill")
                    }
                    
                    ForEach(viewModel.encryptedDNSServers.indices, id: \.self) { index in
                        HStack {
                            TextField("加密 DNS (DoH)", text: $viewModel.encryptedDNSServers[index])
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: {
                                viewModel.encryptedDNSServers.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.encryptedDNSServers.append("")
                    }) {
                        Label("添加加密 DNS", systemImage: "plus.circle.fill")
                    }
                }
                
                // 网络设置
                Section(header: Text("网络设置")) {
                    Toggle("启用 IPv6", isOn: $viewModel.ipv6)
                    
                    HStack {
                        Text("测试超时")
                        Spacer()
                        TextField("秒", value: $viewModel.testTimeout, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text("秒")
                    }
                    
                    TextField("网络测试 URL", text: $viewModel.internetTestURL)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("代理测试 URL", text: $viewModel.proxyTestURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Wi-Fi 访问
                Section(header: Text("Wi-Fi 访问")) {
                    Toggle("允许 Wi-Fi 访问", isOn: $viewModel.allowWifiAccess)
                    
                    if viewModel.allowWifiAccess {
                        HStack {
                            Text("HTTP 端口")
                            Spacer()
                            TextField("端口", value: $viewModel.wifiAccessHTTPPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("SOCKS5 端口")
                            Spacer()
                            TextField("端口", value: $viewModel.wifiAccessSOCKS5Port, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // Skip Proxy 设置
                Section(header: Text("跳过代理")) {
                    ForEach(viewModel.skipProxyList.indices, id: \.self) { index in
                        HStack {
                            TextField("例如：127.0.0.1 或 *.local", text: $viewModel.skipProxyList[index])
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: {
                                viewModel.skipProxyList.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.skipProxyList.append("")
                    }) {
                        Label("添加跳过规则", systemImage: "plus.circle.fill")
                    }
                    
                    Text("不经过代理的地址或域名，支持通配符")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Always Real IP 设置
                Section(header: Text("强制真实 IP")) {
                    ForEach(viewModel.alwaysRealIPList.indices, id: \.self) { index in
                        HStack {
                            TextField("例如：*.apple.com", text: $viewModel.alwaysRealIPList[index])
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: {
                                viewModel.alwaysRealIPList.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.alwaysRealIPList.append("")
                    }) {
                        Label("添加域名", systemImage: "plus.circle.fill")
                    }
                    
                    Text("这些域名将始终返回真实 IP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // HTTP API 设置
                Section(header: Text("HTTP API")) {
                    Toggle("Web Dashboard", isOn: $viewModel.httpApiWebDashboard)
                    Toggle("启用 TLS", isOn: $viewModel.httpApiTLS)
                }
                
                // 高级设置
                Section(header: Text("高级设置")) {
                    Toggle("允许热点访问", isOn: $viewModel.allowHotspotAccess)
                    Toggle("Wi-Fi 辅助", isOn: $viewModel.wifiAssist)
                    Toggle("All Hybrid", isOn: $viewModel.allHybrid)
                    Toggle("禁用 GeoIP 自动更新", isOn: $viewModel.disableGeoIPDBAutoUpdate)
                }
                
                // 其他设置
                Section(header: Text("其他设置")) {
                    Toggle("显示错误页面", isOn: $viewModel.showErrorPageForReject)
                    Toggle("排除简单主机名", isOn: $viewModel.excludeSimpleHostnames)
                    Toggle("读取 /etc/hosts", isOn: $viewModel.readEtcHosts)
                }
                
                // 验证错误显示
                if !viewModel.validationErrors.isEmpty {
                    Section(header: Text("验证错误").foregroundColor(.red)) {
                        ForEach(Array(viewModel.validationErrors.keys), id: \.self) { key in
                            if let error = viewModel.validationErrors[key] {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("General 配置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await viewModel.saveConfiguration()
                            if viewModel.saveSuccess {
                                showingSaveAlert = true
                            } else if let error = viewModel.errorMessage {
                                saveError = error
                                showingSaveAlert = true
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadConfiguration()
                        }
                    }
                }
            }
            .alert("保存结果", isPresented: $showingSaveAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                if viewModel.saveSuccess {
                    Text("配置已成功保存")
                } else if let error = saveError {
                    Text("保存失败: \(error)")
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
            await viewModel.loadConfiguration()
        }
    }
}

// MARK: - View Model

@MainActor
class GeneralConfigViewModel: ObservableObject {
    @Published var loglevel = "notify"
    @Published var dnsServers: [String] = ["223.5.5.5", "114.114.114.114"]
    @Published var encryptedDNSServers: [String] = []
    @Published var ipv6 = false
    @Published var testTimeout = 5
    @Published var internetTestURL = ""
    @Published var proxyTestURL = ""
    @Published var allowWifiAccess = false
    @Published var wifiAccessHTTPPort = 6152
    @Published var wifiAccessSOCKS5Port = 6153
    @Published var showErrorPageForReject = false
    @Published var excludeSimpleHostnames = true
    @Published var readEtcHosts = true
    @Published var httpApiWebDashboard = true
    @Published var skipProxyList: [String] = []
    @Published var alwaysRealIPList: [String] = []
    @Published var httpApiTLS = false
    @Published var allowHotspotAccess = false
    @Published var wifiAssist = false
    @Published var allHybrid = false
    @Published var disableGeoIPDBAutoUpdate = false
    
    // Validation errors
    @Published var validationErrors: [String: String] = [:]
    
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var saveSuccess = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadConfiguration() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let config = try await apiClient.fetchGeneralConfig()
            
            loglevel = config.loglevel ?? "notify"
            dnsServers = config.dnsServer ?? ["223.5.5.5", "114.114.114.114"]
            encryptedDNSServers = config.encryptedDNSServer ?? []
            ipv6 = config.ipv6 ?? false
            testTimeout = config.testTimeout ?? 5
            internetTestURL = config.internetTestURL ?? ""
            proxyTestURL = config.proxyTestURL ?? ""
            allowWifiAccess = config.allowWifiAccess ?? false
            wifiAccessHTTPPort = config.wifiAccessHTTPPort ?? 6152
            wifiAccessSOCKS5Port = config.wifiAccessSOCKS5Port ?? 6153
            showErrorPageForReject = config.showErrorPageForReject ?? false
            excludeSimpleHostnames = config.excludeSimpleHostnames ?? true
            readEtcHosts = config.readEtcHosts ?? true
            httpApiWebDashboard = config.httpApiWebDashboard ?? true
            skipProxyList = config.skipProxy ?? []
            alwaysRealIPList = config.alwaysRealIP ?? []
            httpApiTLS = config.httpApiTls ?? false
            allowHotspotAccess = config.allowHotspotAccess ?? false
            wifiAssist = config.wifiAssist ?? false
            allHybrid = config.allHybrid ?? false
            disableGeoIPDBAutoUpdate = config.disableGeoIPDBAutoUpdate ?? false
            
            errorMessage = nil
            validationErrors = [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func saveConfiguration() async {
        isSaving = true
        saveSuccess = false
        defer { isSaving = false }
        
        // Validate inputs before saving
        if !validateInputs() {
            saveSuccess = false
            errorMessage = "请修正输入错误后再保存"
            return
        }
        
        let config = GeneralConfig(
            testTimeout: testTimeout,
            udpPriority: nil,
            internetTestURL: internetTestURL.isEmpty ? nil : internetTestURL,
            proxyTestURL: proxyTestURL.isEmpty ? nil : proxyTestURL,
            geoipMaxmindURL: nil,
            ipv6: ipv6,
            dnsServer: dnsServers.filter { !$0.isEmpty },
            encryptedDNSServer: encryptedDNSServers.filter { !$0.isEmpty },
            showErrorPageForReject: showErrorPageForReject,
            skipProxy: skipProxyList.filter { !$0.isEmpty },
            allowWifiAccess: allowWifiAccess,
            wifiAccessHTTPPort: wifiAccessHTTPPort,
            wifiAccessSOCKS5Port: wifiAccessSOCKS5Port,
            allowHotspotAccess: allowHotspotAccess,
            wifiAssist: wifiAssist,
            httpApiTls: httpApiTLS,
            httpApiWebDashboard: httpApiWebDashboard,
            allHybrid: allHybrid,
            excludeSimpleHostnames: excludeSimpleHostnames,
            readEtcHosts: readEtcHosts,
            loglevel: loglevel,
            alwaysRealIP: alwaysRealIPList.filter { !$0.isEmpty },
            disableGeoIPDBAutoUpdate: disableGeoIPDBAutoUpdate,
            udpPolicyNotSupportedBehaviour: nil,
            tunIncludedRoutes: nil,
            tunExcludedRoutes: nil
        )
        
        do {
            try await apiClient.updateGeneralConfig(config)
            saveSuccess = true
            errorMessage = nil
        } catch {
            saveSuccess = false
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Validation
    
    func validateInputs() -> Bool {
        validationErrors.removeAll()
        var isValid = true
        
        // Validate DNS servers
        for (index, dns) in dnsServers.enumerated() where !dns.isEmpty {
            if !isValidDNSServer(dns) {
                validationErrors["dns_\(index)"] = "无效的 DNS 服务器格式"
                isValid = false
            }
        }
        
        // Validate port numbers
        if wifiAccessHTTPPort < 1024 || wifiAccessHTTPPort > 65535 {
            validationErrors["http_port"] = "端口必须在 1024-65535 之间"
            isValid = false
        }
        if wifiAccessSOCKS5Port < 1024 || wifiAccessSOCKS5Port > 65535 {
            validationErrors["socks5_port"] = "端口必须在 1024-65535 之间"
            isValid = false
        }
        
        // Validate test timeout
        if testTimeout < 1 || testTimeout > 60 {
            validationErrors["test_timeout"] = "超时应在 1-60 秒之间"
            isValid = false
        }
        
        // Validate URLs
        if !internetTestURL.isEmpty && !isValidURL(internetTestURL) {
            validationErrors["internet_test_url"] = "无效的 URL 格式"
            isValid = false
        }
        if !proxyTestURL.isEmpty && !isValidURL(proxyTestURL) {
            validationErrors["proxy_test_url"] = "无效的 URL 格式"
            isValid = false
        }
        
        return isValid
    }
    
    private func isValidDNSServer(_ dns: String) -> Bool {
        // Allow special values
        if dns == "system" { return true }
        
        // Check for IPv4
        let ipv4Pattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
        if dns.range(of: ipv4Pattern, options: .regularExpression) != nil {
            // Validate octets are 0-255
            let octets = dns.split(separator: ".").compactMap { Int($0) }
            return octets.count == 4 && octets.allSatisfy { $0 >= 0 && $0 <= 255 }
        }
        
        // Check for domain name
        let domainPattern = "^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)*$"
        return dns.range(of: domainPattern, options: .regularExpression) != nil
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
}

#Preview {
    GeneralConfigView()
}
