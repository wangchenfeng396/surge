//
//  ConnectionsView.swift
//  SurgeProxy
//
//  Live connections monitor
//

import SwiftUI

struct ConnectionsView: View {
    @State private var connections: [ConnectionInfo] = []
    @State private var timer: Timer?
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\ConnectionInfo.startTime, order: .reverse)]
    @State private var selectedID: ConnectionInfo.ID?
    
    var filteredConnections: [ConnectionInfo] {
        var result = connections
        if !searchText.isEmpty {
            result = result.filter {
                $0.targetAddress.localizedCaseInsensitiveContains(searchText) ||
                $0.sourceIP.localizedCaseInsensitiveContains(searchText) ||
                $0.processName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted(using: sortOrder)
    }
    
    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                // Toolbar-like header
                HStack {
                    Text("\(connections.count) Connections")
                        .font(.headline)
                    Spacer()
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Table(filteredConnections, selection: $selectedID, sortOrder: $sortOrder) {
                    TableColumn("ID", value: \.id) { conn in
                        Text(conn.id.prefix(8))
                            .font(.monospacedDigit(.body)())
                    }
                    TableColumn("Source", value: \.sourceIP) { conn in
                        Text(conn.sourceIP)
                    }
                    TableColumn("Process", value: \.processName) { conn in
                        Text(conn.processName.isEmpty ? "-" : conn.processName)
                    }
                    TableColumn("Target", value: \.targetAddress) { conn in
                        Text(conn.targetAddress)
                    }
                    TableColumn("Policy", value: \.policy) { conn in
                        Text(conn.policy)
                            .foregroundColor(policyColor(conn.policy))
                    }
                    TableColumn("Rule", value: \.rule) { conn in
                        Text(conn.rule)
                            .foregroundColor(.secondary)
                    }
                    TableColumn("Up", value: \.uploadBytes) { conn in
                        Text(formatBytes(conn.uploadBytes))
                            .frame(alignment: .trailing)
                    }
                    TableColumn("Down", value: \.downloadBytes) { conn in
                        Text(formatBytes(conn.downloadBytes))
                            .frame(alignment: .trailing)
                    }
                    TableColumn("Duration", value: \.startTime) { conn in
                        Text(formatTime(conn.duration))
                            .frame(alignment: .trailing)
                    }
                }
                .searchable(text: $searchText)
            }
            .frame(minWidth: 500, maxWidth: .infinity)
            
            // Detail Pane
            if let selectedID = selectedID, let conn = connections.first(where: { $0.id == selectedID }) {
                ConnectionDetailView(connection: conn) {
                    self.selectedID = nil
                }
                .frame(width: 350)
                .transition(AnyTransition.move(edge: .trailing))
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refresh()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refresh() {
        Task {
            do {
                let conns = try await APIClient.shared.fetchConnections()
                await MainActor.run {
                    self.connections = conns
                }
            } catch {
                print("Failed to fetch connections: \(error)")
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    
    private func policyColor(_ policy: String) -> Color {
        switch policy {
        case "DIRECT": return .green
        case "REJECT": return .red
        case "Proxy", "Global": return .blue
        default: return .primary
        }
    }
}
