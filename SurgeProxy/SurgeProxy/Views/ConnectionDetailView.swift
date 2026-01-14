//
//  ConnectionDetailView.swift
//  SurgeProxy
//
//  Created for Connection Inspection
//

import SwiftUI

struct ConnectionDetailView: View {
    let connection: ConnectionInfo
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.processName.isEmpty ? "Unknown Process" : connection.processName)
                        .font(.headline)
                    Text(connection.targetAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Details List
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Basic Info
                    SectionView(title: "Basic Info") {
                        DetailRow(label: "ID", value: connection.id)
                        DetailRow(label: "Start Time", value: formatTime(connection.startTime))
                        DetailRow(label: "Duration", value: formatDuration(connection.duration))
                    }
                    
                    // Network
                    SectionView(title: "Network") {
                        DetailRow(label: "Protocol", value: connection.metadata.network.uppercased())
                        DetailRow(label: "Source", value: "\(connection.sourceIP):\(connection.sourcePort)")
                        DetailRow(label: "Destination", value: connection.targetAddress)
                        if !connection.metadata.host.isEmpty {
                            DetailRow(label: "Host", value: connection.metadata.host)
                        }
                    }
                    
                    // Policy
                    SectionView(title: "Policy & Rule") {
                        DetailRow(label: "Policy", value: connection.policy)
                        DetailRow(label: "Rule", value: connection.rule)
                        if !connection.chain.isEmpty {
                            DetailRow(label: "Chain", value: connection.chain.joined(separator: " → "))
                        }
                    }
                    
                    // Statistics
                    SectionView(title: "Statistics") {
                        DetailRow(label: "Upload", value: formatBytes(connection.uploadBytes))
                        DetailRow(label: "Download", value: formatBytes(connection.downloadBytes))
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // Formatters
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return "\(minutes)m \(seconds % 60)s"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.callout)
                .multilineTextAlignment(.leading)
        }
    }
}
