//
//  BackendStatusView.swift
//  SurgeProxy
//
//  Status indicator and restart controls for backend service
//

import SwiftUI

struct BackendStatusView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(proxyManager.isRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: proxyManager.isRunning ? Color.green.opacity(0.5) : Color.red.opacity(0.5), radius: 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(proxyManager.isRunning ? "System Normal" : "Service Stopped")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if !proxyManager.isRunning && proxyManager.isStarting {
                    Text("Starting...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                proxyManager.restartProxy()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless) // Minimal button style
            .disabled(proxyManager.isStarting)
            .help("Restart Backend Service")
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}
