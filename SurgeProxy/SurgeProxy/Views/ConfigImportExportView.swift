//
//  ConfigImportExportView.swift
//  SurgeProxy
//
//  Import and export Surge configuration files
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfigImportExportView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    
    @State private var showingImportPicker = false
    @State private var showingExportDialog = false
    @State private var importedConfig: String = ""
    @State private var exportedConfig: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Configuration Import/Export")
                .font(.title)
            
            VStack(spacing: 16) {
                Button(action: { showingImportPicker = true }) {
                    Label("Import Surge Config", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: exportConfig) {
                    Label("Export Surge Config", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            
            if !importedConfig.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Imported Configuration Preview")
                        .font(.headline)
                    
                    ScrollView {
                        Text(importedConfig)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(height: 200)
                    
                    Button("Apply Configuration") {
                        applyImportedConfig()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "conf")!],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: TextDocument(text: exportedConfig),
            contentType: .plainText,
            defaultFilename: "surge_config.conf"
        ) { result in
            handleExport(result)
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                importedConfig = content
                
                // Save filename to UserDefaults
                let filename = url.lastPathComponent
                UserDefaults.standard.set(filename, forKey: "LastImportedConfigFile")
                
                // Upload to sing-box backend
                proxyManager.uploadSurgeConfig(content)
                
                alertMessage = "Configuration imported and uploaded to backend successfully!"
                showingAlert = true
            } catch {
                alertMessage = "Failed to import: \(error.localizedDescription)"
                showingAlert = true
            }
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func applyImportedConfig() {
        let (general, proxies, groups, rules, rewrites, mitm) = SurgeConfigParser.parse(importedConfig)
        
        // Save to UserDefaults
        if let general = general, let encoded = try? JSONEncoder().encode(general) {
            UserDefaults.standard.set(encoded, forKey: "AdvancedGeneralConfig")
        }
        
        if let encoded = try? JSONEncoder().encode(proxies) {
            UserDefaults.standard.set(encoded, forKey: "EnhancedProxyServers")
        }
        
        if let encoded = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(encoded, forKey: "ProxyGroups")
        }
        
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: "ProxyRules")
        }
        
        if let encoded = try? JSONEncoder().encode(rewrites) {
            UserDefaults.standard.set(encoded, forKey: "URLRewriteRules")
        }
        
        if let mitm = mitm, let encoded = try? JSONEncoder().encode(mitm) {
            UserDefaults.standard.set(encoded, forKey: "MITMConfig")
        }
        
        alertMessage = "Configuration applied successfully! Please restart the app."
        showingAlert = true
        importedConfig = ""
    }
    
    private func exportConfig() {
        Task {
            do {
                let config = try await APIClient.shared.getCurrentConfig()
                await MainActor.run {
                    exportedConfig = config
                    showingExportDialog = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to fetch config: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func generateExportConfig() -> String {
        // Load from UserDefaults
        var general = GeneralConfig()
        if let data = UserDefaults.standard.data(forKey: "AdvancedGeneralConfig"),
           let decoded = try? JSONDecoder().decode(GeneralConfig.self, from: data) {
            general = decoded
        }
        
        var proxies: [EnhancedProxyServer] = []
        if let data = UserDefaults.standard.data(forKey: "EnhancedProxyServers"),
           let decoded = try? JSONDecoder().decode([EnhancedProxyServer].self, from: data) {
            proxies = decoded
        }
        
        var groups: [ProxyGroup] = []
        if let data = UserDefaults.standard.data(forKey: "ProxyGroups"),
           let decoded = try? JSONDecoder().decode([ProxyGroup].self, from: data) {
            groups = decoded
        }
        
        var rules: [ProxyRule] = []
        if let data = UserDefaults.standard.data(forKey: "ProxyRules"),
           let decoded = try? JSONDecoder().decode([ProxyRule].self, from: data) {
            rules = decoded
        }
        
        var rewrites: [URLRewriteRule] = []
        if let data = UserDefaults.standard.data(forKey: "URLRewriteRules"),
           let decoded = try? JSONDecoder().decode([URLRewriteRule].self, from: data) {
            rewrites = decoded
        }
        
        var mitm = MITMConfig()
        if let data = UserDefaults.standard.data(forKey: "MITMConfig"),
           let decoded = try? JSONDecoder().decode(MITMConfig.self, from: data) {
            mitm = decoded
        }
        
        return SurgeConfigExporter.export(
            general: general,
            proxies: proxies,
            groups: groups,
            rules: rules,
            urlRewrites: rewrites,
            mitm: mitm
        )
    }
    
    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            alertMessage = "Configuration exported successfully!"
            showingAlert = true
        case .failure(let error):
            alertMessage = "Export failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// Helper document type for file export
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ConfigImportExportView()
        .environmentObject(GoProxyManager())
}
