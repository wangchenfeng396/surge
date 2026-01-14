//
//  RuleImportExportView.swift
//  SurgeProxy
//
//  Rule import/export utility
//

import SwiftUI
import UniformTypeIdentifiers

struct RuleImportExportView: View {
    @StateObject private var viewModel = RuleImportExportViewModel()
    @State private var showingFilePicker = false
    @State private var showingExportAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Import Section
                GroupBox(label: Label("导入规则", systemImage: "square.and.arrow.down")) {
                    VStack(spacing: 12) {
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("从文件导入")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        TextEditor(text: $viewModel.importText)
                            .frame(height: 150)
                            .font(.system(.body, design: .monospaced))
                            .border(Color.gray.opacity(0.3))
                        
                        Button("导入规则") {
                            Task {
                                await viewModel.importRulesFromText()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.importText.isEmpty)
                    }
                    .padding()
                }
                
                // Export Section
                GroupBox(label: Label("导出规则", systemImage: "square.and.arrow.up")) {
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await viewModel.exportRules()
                                showingExportAlert = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("导出所有规则")
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        if !viewModel.exportedRules.isEmpty {
                            ScrollView {
                                Text(viewModel.exportedRules)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(height: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("规则导入/导出")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await viewModel.importFromFile(result: result)
                }
            }
            .alert("导出成功", isPresented: $showingExportAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("规则已导出到文本框，可以复制使用")
            }
            .alert("操作结果", isPresented: $viewModel.showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("处理中...")
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class RuleImportExportViewModel: ObservableObject {
    @Published var importText = ""
    @Published var exportedRules = ""
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let apiClient = APIClient.shared
    
    func importRulesFromText() async {
        isLoading = true
        defer { isLoading = false }
        
        let lines = importText.components(separatedBy: .newlines)
        var successCount = 0
        var failCount = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }
            
            // Parse rule line
            let parts = trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else {
                failCount += 1
                continue
            }
            
            let rule = RuleConfigModel(
                type: parts[0],
                value: parts.count > 2 ? parts[1] : "",
                policy: parts.count > 2 ? parts[2] : parts[1],
                params: nil,
                noResolve: nil,
                updateInterval: nil,
                comment: nil
            )
            
            do {
                try await apiClient.addRule(rule)
                successCount += 1
            } catch {
                failCount += 1
            }
        }
        
        alertMessage = "导入完成\n成功: \(successCount)\n失败: \(failCount)"
        showAlert = true
        importText = ""
    }
    
    func importFromFile(result: Result<[URL], Error>) async {
        do {
            guard let fileURL = try result.get().first else { return }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            importText = content
        } catch {
            alertMessage = "读取文件失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func exportRules() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rules = try await apiClient.fetchAllRules()
            
            var lines: [String] = []
            for rule in rules {
                var line = rule.type
                if !rule.value.isEmpty {
                    line += ",\(rule.value)"
                }
                line += ",\(rule.policy)"
                
                if let comment = rule.comment, !comment.isEmpty {
                    line += " // \(comment)"
                }
                lines.append(line)
            }
            
            exportedRules = lines.joined(separator: "\n")
            
            // Also save to file
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "surge_rules_\(Date().timeIntervalSince1970).txt"
            let fileURL = documentsURL.appendingPathComponent(fileName)
            
            try exportedRules.write(to: fileURL, atomically: true, encoding: .utf8)
            
        } catch {
            alertMessage = "导出失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

#Preview {
    RuleImportExportView()
}
