//
//  DNSSettingsView.swift
//  SurgeProxy
//
//  DNS configuration view
//

import SwiftUI

struct DNSSettingsView: View {
    @State private var dnsMode = "system_additional"
    @State private var customDNS = "223.5.5.5, 114.114.114.114, 119.29.29.29, 162.159.195.1"
    @State private var encryptedDNS = "https://doh.pub/dns-query, https://dns.alidns.com/dns-query"
    @State private var readLocalDNS = true
    @State private var useLocalMapping = false
    
    @State private var dnsMapping: [DNSMapping] = [
        DNSMapping(enabled: false, domain: "*tencent.com", data: "119.29.29.29", comment: "微信"),
        DNSMapping(enabled: false, domain: "*qq.com", data: "119.29.29.29", comment: ""),
        DNSMapping(enabled: true, domain: "*weixin.com", data: "119.29.29.29", comment: "Firebase Cloud Messaging"),
        DNSMapping(enabled: true, domain: "mtalk.google.com", data: "108.177.125.188", comment: "Apple TestFlight"),
    ]
    
    @State private var newDomain = ""
    @State private var newData = ""
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("DNS")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                
                Text("DNS related settings and local DNS mapping.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
                
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // DNS Server
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DNS Server")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                RadioButton(
                                    title: "Use system DNS servers",
                                    isSelected: dnsMode == "system",
                                    action: { dnsMode = "system" }
                                )
                                
                                RadioButton(
                                    title: "Use system DNS servers and additional servers",
                                    isSelected: dnsMode == "system_additional",
                                    action: { dnsMode = "system_additional" }
                                )
                                
                                RadioButton(
                                    title: "Use custom DNS servers",
                                    isSelected: dnsMode == "custom",
                                    action: { dnsMode = "custom" }
                                )
                                
                                if dnsMode != "system" {
                                    TextField("", text: $customDNS)
                                        .textFieldStyle(.roundedBorder)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Encrypted DNS
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Encrypted DNS")
                                .font(.headline)
                            
                            TextField("", text: $encryptedDNS)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("If encrypted DNS is configured, the traditional DNS will only be used to test the connectivity and resolve the domain in the encrypted DNS URL. Supported Protocol:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• DNS over HTTPS: https://example.com")
                                Text("• DNS over HTTP/3: h3://example.com")
                                Text("• DNS over QUIC: quic://example.com")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // DNS Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DNS Options")
                                .font(.headline)
                            
                            Toggle("Read local DNS records from /etc/hosts", isOn: $readLocalDNS)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Use local DNS mapping result for requests via proxy", isOn: $useLocalMapping)
                                
                                Text("By default, the DNS resolve always happens on the remote proxy server since Surge always sends proxy requests with domains. After enabling this option, for the requests that matched a local DNS mapping record, Surge sends proxy requests with IP addresses instead of the original domains.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                                
                                Text("It only works for local DNS mapping records with an IP address.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }
                        }
                        
                        Divider()
                        
                        // DDNS
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DDNS")
                                .font(.headline)
                            
                            Button("Configure Surge Private DDNS...") {
                                // Configure DDNS
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Local DNS Mapping sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Local DNS Mapping")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Table header
                HStack(spacing: 12) {
                    Text("")
                        .frame(width: 30)
                    Text("Domain")
                        .frame(minWidth: 120, alignment: .leading)
                    Text("Data")
                        .frame(minWidth: 100, alignment: .leading)
                    Text("DNS Server")
                        .frame(minWidth: 80, alignment: .leading)
                    Text("Comment")
                        .frame(minWidth: 80, alignment: .leading)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                // Mappings list
                List {
                    ForEach(dnsMapping) { mapping in
                        DNSMappingRow(mapping: mapping)
                    }
                }
                .listStyle(.plain)
                
                Divider()
                
                // Add mapping
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {}) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding()
            }
            .frame(width: 500)
        }
        .frame(width: 900, height: 600)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { dismiss() }
            }
        }
    }
}

struct DNSMapping: Identifiable {
    let id = UUID()
    var enabled: Bool
    var domain: String
    var data: String
    var dnsServer: String = ""
    var comment: String
}

struct DNSMappingRow: View {
    let mapping: DNSMapping
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: .constant(mapping.enabled))
                .labelsHidden()
                .frame(width: 30)
            
            Text(mapping.domain)
                .frame(minWidth: 120, alignment: .leading)
                .font(.system(.body, design: .monospaced))
            
            Text(mapping.data)
                .frame(minWidth: 100, alignment: .leading)
                .font(.system(.caption, design: .monospaced))
            
            Text(mapping.dnsServer)
                .frame(minWidth: 80, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(mapping.comment)
                .frame(minWidth: 80, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                Text(title)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DNSSettingsView()
}
