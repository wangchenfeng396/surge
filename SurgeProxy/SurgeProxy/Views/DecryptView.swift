//
//  DecryptView.swift
//  SurgeProxy
//
//  HTTPS Decryption view with CA certificate management
//

import SwiftUI

struct DecryptView: View {
    @StateObject private var certManager = CertificateManager()
    @State private var decryptionEnabled = true
    @State private var skipServerVerification = true
    @State private var autoBlockQUIC = false
    @State private var mitmOverHTTP2 = true
    
    @State private var mitmHostnames: [String] = [
        "%APPEND% pan.baidu.com",
        "*account.wps.cn",
        "*account.wps.com",
        "api22-normal-c-alisg.tiktokv.com:443",
        "webcast-normal.tiktokv.com:443",
        "%APPEND% www.google.cn",
        "www.g.cn"
    ]
    
    @State private var newHostname = ""
    @State private var selectedHostnames = Set<String>()
    @State private var showingCertificateInfo = false
    @State private var isGenerating = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // Header with toggle
                HStack {
                    Text("HTTPS Decryption")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Toggle("", isOn: $decryptionEnabled)
                        .toggleStyle(.switch)
                    
                    Spacer()
                }
                .padding()
                
                Text("Decrypt HTTPS traffic with man-in-the-middle (MITM) attack.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // CA Certificate section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CA CERTIFICATE")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.gearshape.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(certManager.certificateName)
                                        .font(.headline)
                                    Text(certManager.isTrusted ? "Trusted by System" : "Not Trusted")
                                        .font(.caption)
                                        .foregroundColor(certManager.isTrusted ? .green : .orange)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Actions:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Button("Generate New Certificate") {
                                        generateNewCertificate()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Install to System") {
                                        installToSystem()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Import from PKCS #12 File") {
                                        importCertificate()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Export for iOS Simulator") {
                                        exportForSimulator()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Options section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPTIONS")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                Toggle(isOn: $skipServerVerification) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Skip Server Certificate Verification")
                                            .font(.body)
                                        Text("Allow connections even if the remote server uses an invalid certificate.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Toggle(isOn: $autoBlockQUIC) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Automatically Block QUIC")
                                            .font(.body)
                                        Text("When a QUIC connection (i.e., HTTP/3) hits the MITM hostname list, it automatically blocks that QUIC connection, causing the connection to fall back to HTTP/2 or HTTP/1.1 so that it can be intercepted by MITM.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Toggle(isOn: $mitmOverHTTP2) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("MitM over HTTP/2")
                                            .font(.body)
                                        Text("Decrypt HTTPS traffic with MITM via HTTP/2 protocol, which can improve the performance of concurrent requests.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // MITM Hostnames sidebar
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MITM HOSTNAMES")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { showingCertificateInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                
                Divider()
                
                // Hostnames list
                List(selection: $selectedHostnames) {
                    ForEach(mitmHostnames, id: \.self) { hostname in
                        HStack {
                            Toggle("", isOn: .constant(true))
                                .labelsHidden()
                            
                            Text(hostname)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        }
                        .contextMenu {
                            Button("Edit") { }
                            Button("Delete", role: .destructive) {
                                mitmHostnames.removeAll { $0 == hostname }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // Add hostname
                HStack(spacing: 8) {
                    TextField("Add hostname...", text: $newHostname)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addHostname()
                        }
                    
                    Button(action: addHostname) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(newHostname.isEmpty)
                }
                .padding()
            }
            .frame(width: 350)
        }
        .alert("Certificate Information", isPresented: $showingCertificateInfo) {
            Button("OK") { }
        } message: {
            Text("Surge will only decrypt traffic to the hosts which are declared here. Wildcard characters are allowed.\n\n%APPEND% means the hostname should be appended to the list, not replace the entire list.")
        }
    }
    
    private func addHostname() {
        guard !newHostname.isEmpty else { return }
        mitmHostnames.append(newHostname)
        newHostname = ""
    }
    
    private func generateNewCertificate() {
        isGenerating = true
        certManager.generateCertificate { result in
            isGenerating = false
            switch result {
            case .success(let serial):
                print("Generated certificate: \(serial)")
            case .failure(let error):
                print("Failed to generate certificate: \(error)")
            }
        }
    }
    
    private func installToSystem() {
        certManager.installToSystem { result in
            switch result {
            case .success:
                print("Certificate installed successfully")
            case .failure(let error):
                print("Failed to install certificate: \(error)")
            }
        }
    }
    
    private func importCertificate() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pkcs12]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                certManager.importFromPKCS12(from: url, password: "") { result in
                    switch result {
                    case .success:
                        print("Certificate imported successfully")
                    case .failure(let error):
                        print("Failed to import certificate: \(error)")
                    }
                }
            }
        }
    }
    
    private func exportForSimulator() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "surge_ca.pem"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                certManager.exportForSimulator(to: url) { result in
                    switch result {
                    case .success:
                        print("Certificate exported successfully")
                    case .failure(let error):
                        print("Failed to export certificate: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    DecryptView()
        .frame(width: 900, height: 700)
}
