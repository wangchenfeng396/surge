//
//  RewriteMappingView.swift
//  SurgeProxy
//
//  Rewrite & Mapping feature cards view
//

import SwiftUI

struct RewriteMappingView: View {
    @State private var rewriteEnabled = true // Placeholder for now
    @State private var urlRewrites: [URLRewriteRule] = []
    @State private var headerRewrites: [HeaderRewriteRule] = []
    
    @State private var showingURLRewrites = false
    @State private var showingHeaderRewrites = false
    @State private var showingMock = false
    @State private var showingBodyRewrites = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rewrite & Mapping")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Toggle("", isOn: $rewriteEnabled)
                    .toggleStyle(.switch)
                    .disabled(true) // Disabled until backend support confirmed
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // URL Redirect
                    FeatureModuleCard(
                        title: "URL Redirect",
                        description: "Redirect HTTP requests. This feature is also called Map Remote. Surge can rewrite the request's URL with 3 different methods.",
                        rulesCount: urlRewrites.count,
                        onEdit: { showingURLRewrites = true }
                    )
                    
                    // Header Rewrite
                    FeatureModuleCard(
                        title: "Header Rewrite",
                        description: "Surge can modify the HTTP request headers sent to the server, as well as modify the headers of the returned response.",
                        rulesCount: headerRewrites.count,
                        onEdit: { showingHeaderRewrites = true }
                    )
                    
                    // Mock
                    FeatureModuleCard(
                        title: "Mock",
                        description: "You may mock the API server and return a static response. This feature may also be called Map Local or API Mocking.",
                        rulesCount: 0,
                        onEdit: { showingMock = true }
                    )
                    .opacity(0.6) // Placeholder
                    
                    // Body Rewrite
                    FeatureModuleCard(
                        title: "Body Rewrite",
                        description: "Surge can rewrite the body of HTTP request or response, replacing the original content with regular expressions.",
                        rulesCount: 0,
                        onEdit: { showingBodyRewrites = true }
                    )
                    .opacity(0.6) // Placeholder
                }
                .padding()
                
                Text("The above count includes the rules in the module.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .sheet(isPresented: $showingURLRewrites) {
            NavigationView {
                URLRewriteManagerView()
            }
            .onDisappear {
                loadCounts()
            }
        }
        .sheet(isPresented: $showingHeaderRewrites) {
            // HeaderRewriteEditorView already includes NavigationView
            HeaderRewriteEditorView()
                .onDisappear {
                    loadCounts()
                }
        }
        .onAppear {
            loadCounts()
        }
    }
    
    private func loadCounts() {
        Task {
            do {
                urlRewrites = try await APIClient.shared.fetchURLRewrites()
                headerRewrites = try await APIClient.shared.fetchHeaderRewrites()
            } catch {
                print("Failed to load rewrite counts: \(error)")
            }
        }
    }
}

struct FeatureModuleCard: View {
    let title: String
    let description: String
    let rulesCount: Int
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
                .frame(height: 70, alignment: .topLeading)
            
            Spacer()
            
            HStack {
                Text("\(rulesCount) rules are in effect")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Edit \(title) Rules...") {
                    onEdit()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    RewriteMappingView()
        .frame(width: 900, height: 600)
}
