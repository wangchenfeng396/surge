//
//  ConfigPathManagerView.swift
//  SurgeProxy
//
//  UI for managing configuration file path, backups, and validation
//

import SwiftUI

struct ConfigPathManagerView: View {
    @StateObject private var configManager = ConfigFileManager.shared
    @State private var showingFilePicker = false
    @State private var selectedBackup: URL?
    @State private var backups: [URL] = []
    @State private var validationStatus: (isValid: Bool, error: String?) = (true, nil)
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("配置文件管理")
                .font(.title2)
                .fontWeight(.bold)
            
            Divider()
            
            // Configuration Path Section
            VStack(alignment: .leading, spacing: 12) {
                Text("配置文件位置")
                    .font(.headline)
                
                HStack {
                    Text(configManager.getConfigPath())
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("选择文件...") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("重置默认") {
                        Task {
                            await configManager.resetToDefaultPath()
                            await refreshStatus()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                // Validation Status
                HStack {
                    Image(systemName: validationStatus.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(validationStatus.isValid ? .green : .orange)
                    
                    Text(validationStatus.isValid ? "配置文件有效" : validationStatus.error ?? "配置文件无效")
                        .font(.caption)
                        .foregroundColor(validationStatus.isValid ? .green : .orange)
                    
                    Spacer()
                    
                    Button("验证配置") {
                        Task {
                            await refreshStatus()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Backup Management Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("备份管理")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("创建备份") {
                        Task {
                            await createBackup()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("刷新") {
                        loadBackups()
                    }
                    .buttonStyle(.borderless)
                }
                
                if backups.isEmpty {
                    Text("暂无备份文件")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(backups, id: \.path) { backup in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(backup.lastPathComponent)
                                            .font(.system(.caption, design: .monospaced))
                                        
                                        if let attrs = try? FileManager.default.attributesOfItem(atPath: backup.path),
                                           let modDate = attrs[.modificationDate] as? Date {
                                            HStack(spacing: 4) {
                                                Text(modDate, style: .date)
                                                Text(modDate, style: .time)
                                            }
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button("恢复") {
                                        selectedBackup = backup
                                        Task {
                                            await restoreBackup(from: backup)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            Task {
                await refreshStatus()
                loadBackups()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await configManager.setCustomConfigPath(url)
                        await refreshStatus()
                    }
                }
            case .failure(let error):
                alertMessage = "文件选择失败: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshStatus() async {
        validationStatus = await configManager.validateConfigFile()
    }
    
    private func loadBackups() {
        backups = configManager.listBackups()
    }
    
    private func createBackup() async {
        do {
            let backupURL = try await configManager.createBackup()
            alertMessage = "备份已创建: \(backupURL.lastPathComponent)"
            showingAlert = true
            loadBackups()
        } catch {
            alertMessage = "创建备份失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func restoreBackup(from backup: URL) async {
        do {
            try await configManager.restoreFromBackup(backup)
            alertMessage = "配置已从备份恢复"
            showingAlert = true
            await refreshStatus()
        } catch {
            alertMessage = "恢复备份失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    ConfigPathManagerView()
}
