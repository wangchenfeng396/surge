//
//  ReloadStatusView.swift
//  SurgeProxy
//
//  Global reload status indicator
//

import SwiftUI

struct ReloadStatusView: View {
    @ObservedObject var reloadManager = ConfigReloadManager.shared
    
    var body: some View {
        if let message = reloadManager.reloadMessage {
            HStack(spacing: 8) {
                if reloadManager.isReloading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else if case .success = reloadManager.lastReloadStatus {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if case .failed = reloadManager.lastReloadStatus {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    reloadManager.clearMessages()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct ManualReloadButton: View {
    @ObservedObject var reloadManager = ConfigReloadManager.shared
    
    var body: some View {
        Button(action: {
            Task {
                await reloadManager.triggerReload()
            }
        }) {
            HStack(spacing: 4) {
                if reloadManager.isReloading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text("重载配置")
                    .font(.caption)
            }
        }
        .disabled(reloadManager.isReloading)
        .buttonStyle(.bordered)
        .help("手动触发配置重载")
    }
}

#Preview {
    VStack {
        ReloadStatusView()
        ManualReloadButton()
    }
    .padding()
}
