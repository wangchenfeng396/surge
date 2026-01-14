//
//  ConfigFileManagerView.swift
//  SurgeProxy
//
//  Configuration file import/export management
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfigFileManagerView: View {
    @StateObject private var viewModel = ConfigFileManagerViewModel()
    @State private var showingFilePicker = false
    @State private var showingURLImport = false
    @State private var importURL = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("导入配置")) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Label("从文件导入", systemImage: "doc.fill")
                    }
                    
                    Button(action: {
                        showingURLImport = true
                    }) {
                        Label("从 URL 导入", systemImage: "link")
                    }
                }
                
                Section(header: Text("导出配置")) {
                    Button(action: {
                        Task {
                            await viewModel.exportCurrentConfig()
                        }
                    }) {
                        Label("导出当前配置", systemImage: "square.and.arrow.up")
                    }
                    
                    if let exportPath = viewModel.exportedFilePath {
                        HStack {
                            Text("已保存至:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(exportPath)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }
                }
                
                Section(header: Text("配置预览")) {
                    if let config = viewModel.currentConfig {
                        ScrollView {
                            Text(config)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                    } else {
                        Button("加载配置预览") {
                            Task {
                                await viewModel.loadCurrentConfig()
                            }
                        }
                    }
                }
            }
            .navigationTitle("配置文件管理")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.plainText, UTType(filenameExtension: "conf")!],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await viewModel.importFromFile(result: result)
                }
            }
            .sheet(isPresented: $showingURLImport) {
                URLImportSheet(url: $importURL) {
                    Task {
                        await viewModel.importFromURL(importURL)
                        showingURLImport = false
                    }
                }
            }
            .alert("操作结果", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView(viewModel.loadingMessage)
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
}

// MARK: - URL Import Sheet

struct URLImportSheet: View {
    @Binding var url: String
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("配置 URL")) {
                    TextField("https://example.com/surge.conf", text: $url)
                }
                
                Section {
                    Text("支持从远程 URL 下载 surge.conf 配置文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("从 URL 导入")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        onImport()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class ConfigFileManagerViewModel: ObservableObject {
    @Published var currentConfig: String?
    @Published var exportedFilePath: String?
    @Published var isLoading = false
    @Published var loadingMessage = "处理中..."
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let apiClient = APIClient.shared
    
    func loadCurrentConfig() async {
        isLoading = true
        loadingMessage = "加载配置..."
        defer { isLoading = false }
        
        do {
            let response = try await apiClient.fetchConfig()
            currentConfig = response.config
        } catch {
            alertMessage = "加载失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func importFromFile(result: Result<[URL], Error>) async {
        isLoading = true
        loadingMessage = "导入配置..."
        defer { isLoading = false }
        
        do {
            guard let fileURL = try result.get().first else { return }
            
            // Read file content
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Upload to backend
            try await apiClient.updateConfig(content)
            
            alertMessage = "配置导入成功！\n文件: \(fileURL.lastPathComponent)"
            showAlert = true
            
            // Reload preview
            currentConfig = content
        } catch {
            alertMessage = "导入失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func importFromURL(_ urlString: String) async {
        isLoading = true
        loadingMessage = "从 URL 下载配置..."
        defer { isLoading = false }
        
        guard let url = URL(string: urlString) else {
            alertMessage = "无效的 URL"
            showAlert = true
            return
        }
        
        do {
            // Download config
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let content = String(data: data, encoding: .utf8) else {
                alertMessage = "无法解析配置内容"
                showAlert = true
                return
            }
            
            // Upload to backend
            try await apiClient.updateConfig(content)
            
            alertMessage = "配置导入成功！\nURL: \(urlString)"
            showAlert = true
            
            // Reload preview
            currentConfig = content
        } catch {
            alertMessage = "导入失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func exportCurrentConfig() async {
        isLoading = true
        loadingMessage = "导出配置..."
        defer { isLoading = false }
        
        do {
            // Fetch current config
            let response = try await apiClient.fetchConfig()
            let content = response.config
            
            // Save to file
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "surge_\(Date().timeIntervalSince1970).conf"
            let fileURL = documentsURL.appendingPathComponent(fileName)
            
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            exportedFilePath = fileURL.path
            alertMessage = "配置导出成功！\n位置: \(fileURL.path)"
            showAlert = true
            
            // Update preview
            currentConfig = content
        } catch {
            alertMessage = "导出失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

#Preview {
    ConfigFileManagerView()
}
