//
//  SettingsView.swift
//  SurgeProxy
//
//  Settings view with General, Remote Access, and Advanced tabs
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"
    @State private var launchAtLogin = false
    @State private var autoRelaunch = true
    @State private var ipv6DNS = false
    @State private var geoIPURL = "https://github.com/Hackl0us/GeoIP2-CN/raw/release/Country.mmdb"
    @State private var autoUpdateGeoIP = true
    @State private var logLevel = "warning"
    
    // Advanced tab
    @State private var internetTestURL = "http://www.bing.com"
    @State private var proxyTestURL = "http://connect.rom.miui.com/generate_204"
    @State private var proxyUDPTestParam = "apple.com@1.0.0.1"
    @State private var proxyTestTimeout = 10
    @State private var displayHTTPError = true
    @State private var showErrorForReject = true
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Text("Adjust all the Surge engine settings here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom)
            
            Divider()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("General").tag("General")
                Text("Remote Access").tag("Remote Access")
                Text("Advanced").tag("Advanced")
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            ScrollView {
                if selectedTab == "General" {
                    generalTab
                } else if selectedTab == "Advanced" {
                    advancedTab
                } else {
                    remoteAccessTab
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Apply") {
                    // Save settings
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 700, height: 600)
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Startup
            HStack {
                Text("Startup:")
                    .frame(width: 150, alignment: .trailing)
                Toggle("Launch Surge at Login", isOn: $launchAtLogin)
            }
            
            // Crash Recovery
            HStack {
                Text("Crash Recovery:")
                    .frame(width: 150, alignment: .trailing)
                Toggle("Automatically relaunch Surge after crash", isOn: $autoRelaunch)
            }
            
            Divider()
            
            // System Permissions
            HStack {
                Text("System Permissions:")
                    .frame(width: 150, alignment: .trailing)
                Button("System Permissions Overview...") {
                    // Show permissions
                }
            }
            
            Divider()
            
            // IPv6 DNS Lookup
            HStack {
                Text("IPv6 DNS Lookup:")
                    .frame(width: 150, alignment: .trailing)
                Toggle("Enabled", isOn: $ipv6DNS)
            }
            
            // Surge VIF IPv6
            HStack {
                Text("Surge VIF IPv6:")
                    .frame(width: 150, alignment: .trailing)
                Picker("", selection: .constant("Disabled")) {
                    Text("Disabled").tag("Disabled")
                    Text("Enabled").tag("Enabled")
                }
                .frame(width: 200)
            }
            
            Divider()
            
            // Subnet Settings
            HStack {
                Text("Subnet Settings:")
                    .frame(width: 150, alignment: .trailing)
                Button("Configure Subnet Settings...") {
                    // Configure subnet
                }
            }
            
            Divider()
            
            // GeoIP Database
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("GeoIP Database:")
                        .frame(width: 150, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Updated: 2026/1/11, 12:34")
                            .font(.body)
                        Text("Surge uses GeoLite2 data created by MaxMind.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Update Now") {
                        // Update GeoIP
                    }
                }
                
                HStack {
                    Spacer()
                        .frame(width: 150)
                    TextField("", text: $geoIPURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Spacer()
                        .frame(width: 150)
                    Toggle("Automatic updates GeoIP database weekly", isOn: $autoUpdateGeoIP)
                }
            }
            
            Divider()
            
            // Log Level
            HStack {
                Text("Log Level:")
                    .frame(width: 150, alignment: .trailing)
                Picker("", selection: $logLevel) {
                    Text("verbose").tag("verbose")
                    Text("info").tag("info")
                    Text("warning").tag("warning")
                    Text("error").tag("error")
                }
                .frame(width: 150)
                
                Button("Show Log") { }
                Button("Reveal Logs in Finder") { }
            }
        }
        .padding()
    }
    
    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Connectivity Test
            VStack(alignment: .leading, spacing: 12) {
                Text("Connectivity Test")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Internet Testing URL")
                        .font(.subheadline)
                    Text("The URL for the Internet connectivity testing. Also, the testing URL for DIRECT policy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $internetTestURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proxy Testing URL")
                        .font(.subheadline)
                    Text("The default testing URL for proxy policies.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $proxyTestURL)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proxy UDP Testing Parameter")
                        .font(.subheadline)
                    Text("The default UDP test parameter for proxies. E.g.: apple.com@1.0.0.1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $proxyUDPTestParam)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Proxy Testing Timeout")
                        .font(.subheadline)
                    TextField("", value: $proxyTestTimeout, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                Text("The default timeout for proxy connectivity tests.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Error Page
            VStack(alignment: .leading, spacing: 12) {
                Text("Error Page")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Display HTTP Error Page", isOn: $displayHTTPError)
                    Text("Show HTTP error page when request encounters an error.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show Error Page for REJECT", isOn: $showErrorForReject)
                    Text("Show an error webpage for REJECT policy if the request is a plain HTTP request.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // DNS
            Text("DNS")
                .font(.headline)
        }
        .padding()
    }
    
    private var remoteAccessTab: some View {
        VStack {
            Text("Remote Access settings")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
