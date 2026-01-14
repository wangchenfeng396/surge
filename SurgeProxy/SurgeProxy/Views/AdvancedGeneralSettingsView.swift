//
//  AdvancedGeneralSettingsView.swift
//  SurgeProxy
//
//  Comprehensive general settings matching Surge configuration
//

import SwiftUI

struct AdvancedGeneralSettingsView: View {
    @State private var config = GeneralConfig()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSaveSuccess = false
    
    var body: some View {
        Form {
            testingSection
            networkSection
            dnsSection
            proxyBehaviorSection
            wifiAccessSection
            advancedSection
        }
        .navigationTitle("Advanced General Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveConfig()
                }
            }
        }
        .task {
            await loadConfig()
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert("Success", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Configuration saved successfully")
        }
    }
    
    // MARK: - Testing Section
    
    private var testingSection: some View {
        Section("Testing") {
            HStack {
                Text("Test Timeout")
                Spacer()
                TextField("Seconds", value: $config.testTimeout, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                Text("seconds")
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Internet Test URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("URL", text: Binding(get: { config.internetTestURL ?? "" }, set: { config.internetTestURL = $0 }))
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Proxy Test URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("URL", text: Binding(get: { config.proxyTestURL ?? "" }, set: { config.proxyTestURL = $0 }))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    // MARK: - Network Section
    
    private var networkSection: some View {
        Section("Network") {
            Toggle("IPv6 Support", isOn: Binding(get: { config.ipv6 ?? false }, set: { config.ipv6 = $0 }))
            Toggle("UDP Priority", isOn: Binding(get: { config.udpPriority ?? false }, set: { config.udpPriority = $0 }))
            Toggle("All Hybrid Mode", isOn: Binding(get: { config.allHybrid ?? false }, set: { config.allHybrid = $0 }))
            
            Picker("UDP Policy (Not Supported)", selection: Binding(get: { config.udpPolicyNotSupportedBehaviour ?? "reject" }, set: { config.udpPolicyNotSupportedBehaviour = $0 })) {
                Text("Reject").tag("reject")
                Text("Direct").tag("direct")
            }
        }
    }
    
    // MARK: - DNS Section
    
    private var dnsSection: some View {
        Section("DNS Configuration") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DNS Servers")
                        .font(.headline)
                    Spacer()
                    Button(action: addDNSServer) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ForEach(Array((config.dnsServers ?? []).enumerated()), id: \.offset) { index, server in
                    HStack {
                        TextField("DNS Server", text: Binding(
                            get: { config.dnsServers?[index] ?? "" },
                            set: {
                                if config.dnsServers == nil { config.dnsServers = [] }
                                if index < config.dnsServers!.count {
                                    config.dnsServers![index] = $0
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: { removeDNSServer(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Encrypted DNS (DoH)")
                        .font(.headline)
                    Spacer()
                    Button(action: addEncryptedDNS) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ForEach(Array((config.encryptedDNSServers ?? []).enumerated()), id: \.offset) { index, server in
                    HStack {
                        TextField("DoH Server", text: Binding(
                            get: { config.encryptedDNSServers?[index] ?? "" },
                            set: {
                                if config.encryptedDNSServers == nil { config.encryptedDNSServers = [] }
                                if index < config.encryptedDNSServers!.count {
                                    config.encryptedDNSServers![index] = $0
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: { removeEncryptedDNS(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("GeoIP Database URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("URL", text: Binding(get: { config.geoipMaxmindURL ?? "" }, set: { config.geoipMaxmindURL = $0 }))
                    .textFieldStyle(.roundedBorder)
            }
            
            Toggle("Disable GeoIP Auto Update", isOn: Binding(get: { config.disableGeoIPDBAutoUpdate ?? false }, set: { config.disableGeoIPDBAutoUpdate = $0 }))
        }
    }
    
    // MARK: - Proxy Behavior Section
    
    private var proxyBehaviorSection: some View {
        Section("Proxy Behavior") {
            Toggle("Show Error Page for Reject", isOn: Binding(get: { config.showErrorPageForReject ?? true }, set: { config.showErrorPageForReject = $0 }))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Skip Proxy (Bypass)")
                        .font(.headline)
                    Spacer()
                    Button(action: addSkipProxy) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ForEach(Array((config.skipProxy ?? []).enumerated()), id: \.offset) { index, item in
                    HStack {
                        TextField("IP/Domain", text: Binding(
                            get: { config.skipProxy?[index] ?? "" },
                            set: {
                                if config.skipProxy == nil { config.skipProxy = [] }
                                if index < config.skipProxy!.count {
                                    config.skipProxy![index] = $0
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: { removeSkipProxy(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Wi-Fi Access Section
    
    private var wifiAccessSection: some View {
        Section("Wi-Fi Access") {
            Toggle("Allow Wi-Fi Access", isOn: Binding(get: { config.allowWifiAccess ?? false }, set: { config.allowWifiAccess = $0 }))
            
            HStack {
                Text("HTTP Port")
                Spacer()
                TextField("Port", value: $config.wifiAccessHTTPPort, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            .disabled(!(config.allowWifiAccess ?? false))
            
            HStack {
                Text("SOCKS5 Port")
                Spacer()
                TextField("Port", value: $config.wifiAccessSOCKS5Port, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            .disabled(!(config.allowWifiAccess ?? false))
            
            Toggle("Allow Hotspot Access", isOn: Binding(get: { config.allowHotspotAccess ?? false }, set: { config.allowHotspotAccess = $0 }))
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section("Advanced") {
            Toggle("Wi-Fi Assist", isOn: Binding(get: { config.wifiAssist ?? false }, set: { config.wifiAssist = $0 }))
            Toggle("Exclude Simple Hostnames", isOn: Binding(get: { config.excludeSimpleHostnames ?? true }, set: { config.excludeSimpleHostnames = $0 }))
            Toggle("Read /etc/hosts", isOn: Binding(get: { config.readEtcHosts ?? true }, set: { config.readEtcHosts = $0 }))
            
            Picker("Log Level", selection: Binding(get: { config.loglevel ?? "notify" }, set: { config.loglevel = $0 })) {
                Text("Verbose").tag("verbose")
                Text("Info").tag("info")
                Text("Notify").tag("notify")
                Text("Warning").tag("warning")
                Text("Error").tag("error")
            }
            
            Toggle("HTTP API TLS", isOn: Binding(get: { config.httpApiTls ?? false }, set: { config.httpApiTls = $0 }))
            Toggle("HTTP API Web Dashboard", isOn: Binding(get: { config.httpApiWebDashboard ?? true }, set: { config.httpApiWebDashboard = $0 }))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Always Real IP Hosts")
                        .font(.headline)
                    Spacer()
                    Button(action: addAlwaysRealIP) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ForEach(Array((config.alwaysRealIP ?? []).enumerated()), id: \.offset) { index, host in
                    HStack {
                        TextField("Hostname", text: Binding(
                            get: { config.alwaysRealIP?[index] ?? "" },
                            set: {
                                if config.alwaysRealIP == nil { config.alwaysRealIP = [] }
                                if index < config.alwaysRealIP!.count {
                                    config.alwaysRealIP![index] = $0
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: { removeAlwaysRealIP(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TUN Included Routes")
                        .font(.headline)
                    Spacer()
                    Button(action: addTUNIncluded) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ForEach(Array((config.tunIncludedRoutes ?? []).enumerated()), id: \.offset) { index, route in
                    HStack {
                        TextField("CIDR", text: Binding(
                            get: { config.tunIncludedRoutes?[index] ?? "" },
                            set: {
                                if config.tunIncludedRoutes == nil { config.tunIncludedRoutes = [] }
                                if index < config.tunIncludedRoutes!.count {
                                    config.tunIncludedRoutes![index] = $0
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: { removeTUNIncluded(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addDNSServer() {
        if config.dnsServers == nil { config.dnsServers = [] }
        config.dnsServers?.append("")
    }
    
    private func removeDNSServer(at index: Int) {
        config.dnsServers?.remove(at: index)
    }
    
    private func addEncryptedDNS() {
        if config.encryptedDNSServers == nil { config.encryptedDNSServers = [] }
        config.encryptedDNSServers?.append("")
    }
    
    private func removeEncryptedDNS(at index: Int) {
        config.encryptedDNSServers?.remove(at: index)
    }
    
    private func addSkipProxy() {
        if config.skipProxy == nil { config.skipProxy = [] }
        config.skipProxy?.append("")
    }
    
    private func removeSkipProxy(at index: Int) {
        config.skipProxy?.remove(at: index)
    }
    
    private func addAlwaysRealIP() {
        if config.alwaysRealIP == nil { config.alwaysRealIP = [] }
        config.alwaysRealIP?.append("")
    }
    
    private func removeAlwaysRealIP(at index: Int) {
        config.alwaysRealIP?.remove(at: index)
    }
    
    private func addTUNIncluded() {
        if config.tunIncludedRoutes == nil { config.tunIncludedRoutes = [] }
        config.tunIncludedRoutes?.append("")
    }
    
    private func removeTUNIncluded(at index: Int) {
        config.tunIncludedRoutes?.remove(at: index)
    }

    
    // MARK: - API Integration
    
    private func loadConfig() async {
        isLoading = true
        do {
            config = try await APIClient.shared.fetchGeneralConfig()
        } catch {
            errorMessage = "Failed to load config: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func saveConfig() {
        Task {
            isLoading = true
            do {
                try await APIClient.shared.updateGeneralConfig(config)
                showSaveSuccess = true
            } catch {
                errorMessage = "Failed to save config: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}


#Preview {
    NavigationView {
        AdvancedGeneralSettingsView()
    }
}
