//
//  NewDeviceView.swift
//  SurgeProxy
//
//  Connected devices view
//

import SwiftUI

struct NewDeviceView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var sortBy = "IP"
    @State private var gatewayMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Device")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Sort by", selection: $sortBy) {
                    Text("IP").tag("IP")
                    Text("Traffic").tag("Traffic")
                    Text("Hostname").tag("Hostname")
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
            .padding()
            
            Divider()
            
            // Device list or empty state
            if proxyManager.devices.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "laptopcomputer.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Device")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(proxyManager.devices) { device in
                    DeviceRow(device: device)
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Bottom bar
            HStack {
                Toggle(isOn: $gatewayMode) {
                    HStack {
                        Image(systemName: "network")
                        Text("Gateway Mode")
                            .font(.callout)
                    }
                }
                .toggleStyle(.switch)
                
                Spacer()
                
                Text("You can use Surge as a DHCP server for your LAN and take over the network of other devices with Surge gateway mode with a simple click.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 400)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct DeviceRow: View {
    let device: DeviceInfo
    
    var body: some View {
        HStack {
            Image(systemName: "laptopcomputer")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.hostname.isEmpty ? "Unknown Device" : device.hostname)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(device.ip)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBytes(device.uploadBytes + device.downloadBytes))
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text("\(device.connections) connections")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }
}

#Preview {
    NewDeviceView()
        .environmentObject(GoProxyManager())
        .frame(width: 800, height: 600)
}
