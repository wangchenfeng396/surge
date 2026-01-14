//
//  EnhancedProxyServerEditorView.swift
//  SurgeProxy
//
//  Enhanced proxy server editor with VMess and advanced protocol support
//

import SwiftUI

struct EnhancedProxyServerEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var server: EnhancedProxyServer
    let onSave: (EnhancedProxyServer) -> Void
    
    init(server: EnhancedProxyServer?, onSave: @escaping (EnhancedProxyServer) -> Void) {
        self._server = State(initialValue: server ?? EnhancedProxyServer(
            name: "",
            proxyProtocol: .http,
            server: "",
            port: 8080
        ))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                basicSection
                authenticationSection
                
                if server.proxyProtocol == .vmess || server.proxyProtocol == .shadowsocks {
                    encryptionSection
                }
                
                if server.proxyProtocol == .vmess {
                    vmessSection
                }
                
                webSocketSection
                tlsSection
                advancedSection
            }
            .navigationTitle(server.name.isEmpty ? "New Proxy Server" : "Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(server)
                        dismiss()
                    }
                    .disabled(server.name.isEmpty || server.server.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var basicSection: some View {
        Section("Basic") {
            TextField("Name", text: $server.name)
            
            Picker("Protocol", selection: $server.proxyProtocol) {
                ForEach(ProxyProtocol.allCases, id: \.self) { proto in
                    Text(proto.displayName).tag(proto)
                }
            }
            
            TextField("Server Address", text: $server.server)
            
            HStack {
                Text("Port")
                Spacer()
                TextField("Port", value: $server.port, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var authenticationSection: some View {
        Section("Authentication") {
            TextField("Username", text: Binding(
                get: { server.username ?? "" },
                set: { server.username = $0.isEmpty ? nil : $0 }
            ))
            
            SecureField("Password", text: Binding(
                get: { server.password ?? "" },
                set: { server.password = $0.isEmpty ? nil : $0 }
            ))
        }
    }
    
    private var encryptionSection: some View {
        Section("Encryption") {
            TextField("Encryption Method", text: Binding(
                get: { server.encryption ?? "" },
                set: { server.encryption = $0.isEmpty ? nil : $0 }
            ))
            .help("e.g., aes-256-gcm, chacha20-poly1305")
            
            if server.proxyProtocol == .vmess {
                TextField("UUID", text: Binding(
                    get: { server.uuid ?? "" },
                    set: { server.uuid = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    private var vmessSection: some View {
        Section("VMess Settings") {
            Toggle("VMess AEAD", isOn: $server.vmessAEAD)
            
            HStack {
                Text("Alter ID")
                Spacer()
                TextField("Alter ID", value: $server.alterId, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var webSocketSection: some View {
        Section("WebSocket") {
            Toggle("Enable WebSocket", isOn: $server.ws)
            
            if server.ws {
                TextField("WebSocket Path", text: Binding(
                    get: { server.wsPath ?? "/" },
                    set: { server.wsPath = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(.body, design: .monospaced))
            }
        }
    }
    
    private var tlsSection: some View {
        Section("TLS") {
            Toggle("Enable TLS", isOn: $server.tls)
            
            if server.tls {
                TextField("SNI (Server Name)", text: Binding(
                    get: { server.sni ?? "" },
                    set: { server.sni = $0.isEmpty ? nil : $0 }
                ))
                
                Toggle("Skip Certificate Verification", isOn: $server.skipCertVerify)
                    .help("⚠️ Only use for testing")
            }
        }
    }
    
    private var advancedSection: some View {
        Section("Advanced") {
            Toggle("TCP Fast Open (TFO)", isOn: $server.tfo)
            Toggle("Multipath TCP", isOn: $server.mptcp)
            Toggle("UDP Relay", isOn: $server.udpRelay)
            
            TextField("Obfuscation", text: Binding(
                get: { server.obfs ?? "" },
                set: { server.obfs = $0.isEmpty ? nil : $0 }
            ))
            
            if server.obfs != nil && !server.obfs!.isEmpty {
                TextField("Obfs Host", text: Binding(
                    get: { server.obfsHost ?? "" },
                    set: { server.obfsHost = $0.isEmpty ? nil : $0 }
                ))
            }
        }
    }
}

#Preview {
    EnhancedProxyServerEditorView(server: nil) { _ in }
}
