//
//  ConnectionStatusView.swift
//  SurgeProxy
//
//  Display connection status with uptime
//

import SwiftUI

struct ConnectionStatusView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if proxyManager.isRunning, let startTime = proxyManager.startTime {
                let uptime = Int64(Date().timeIntervalSince(startTime))
                Text("• \(formatUptime(uptime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        proxyManager.isRunning ? .green : .red
    }
    
    private var statusText: String {
        proxyManager.isRunning ? "Connected" : "Disconnected"
    }
    
    private func formatUptime(_ seconds: Int64) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    ConnectionStatusView()
        .environmentObject(GoProxyManager())
}
