//
//  NewProcessView.swift
//  SurgeProxy
//
//  Process monitoring view
//

import SwiftUI

struct NewProcessView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var sortBy = "Traffic"
    @State private var meteredMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Process")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Sort by", selection: $sortBy) {
                    Text("Traffic").tag("Traffic")
                    Text("Name").tag("Name")
                    Text("Connections").tag("Connections")
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
            .padding()
            
            Divider()
            
            // Process list or empty state
            if proxyManager.processes.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "app.dashed")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Process")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(proxyManager.processes) { process in
                    ProcessRow(process: process)
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Bottom bar
            HStack {
                Toggle(isOn: $meteredMode) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Metered Network Mode")
                            .font(.callout)
                    }
                }
                .toggleStyle(.switch)
                
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

struct ProcessRow: View {
    let process: NetworkProcessInfo
    
    var body: some View {
        HStack {
            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(process.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("PID: \(process.pid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBytes(process.uploadBytes + process.downloadBytes))
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text("\(process.connections) connections")
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
    NewProcessView()
        .environmentObject(GoProxyManager())
        .frame(width: 800, height: 600)
}
