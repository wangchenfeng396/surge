//
//  URLRewriteManagerView.swift
//  SurgeProxy
//
//  URL rewrite rule management
//

import SwiftUI

struct URLRewriteManagerView: View {
    @State private var rules: [URLRewriteRule] = []
    @State private var showingAddRule = false
    @State private var editingRule: URLRewriteRule?
    
    var body: some View {
        VStack {
            if rules.isEmpty {
                emptyState
            } else {
                ruleList
            }
        }
        .navigationTitle("URL Rewrite")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddRule = true }) {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            URLRewriteEditorView(rule: nil) { newRule in
                rules.append(newRule)
                Task {
                    await saveRule(newRule)
                    await loadRules()
                }
            }
        }
        .sheet(item: $editingRule) { rule in
            URLRewriteEditorView(rule: rule) { updatedRule in
                if let index = rules.firstIndex(where: { $0.id == updatedRule.id }) {
                    rules[index] = updatedRule
                    Task {
                        // Delete old and add new (backend doesn't have update endpoint)
                        try? await APIClient.shared.deleteURLRewrite(pattern: rule.pattern)
                        await saveRule(updatedRule)
                        await loadRules()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadRules()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Rewrite Rules")
                .font(.title2)
            Text("Create URL rewrite rules to redirect or modify requests")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add First Rule") {
                showingAddRule = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var ruleList: some View {
        List {
            ForEach(rules) { rule in
                URLRewriteRuleRow(rule: rule)
                    .onTapGesture {
                        editingRule = rule
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingRule = rule
                        }
                        Button(rule.enabled ? "Disable" : "Enable") {
                            toggleRule(rule)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteRule(rule)
                        }
                    }
            }
            .onMove(perform: moveRules)
            // .onDelete(perform: deleteRules) // Removed as per instruction, handled by context menu and specific deleteRule
        }
        .onAppear {
            Task {
                await loadRules()
            }
        }
    }
    
    private func loadRules() async {
        do {
            rules = try await APIClient.shared.fetchURLRewrites()
        } catch {
            print("Error loading URL rewrites: \(error)")
        }
    }
    
    private func saveRule(_ rule: URLRewriteRule) async {
        do {
            try await APIClient.shared.addURLRewrite(rule)
        } catch {
            print("Error saving URL rewrite: \(error)")
        }
    }
    
    private func toggleRule(_ rule: URLRewriteRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].enabled.toggle()
            // Note: Backend doesn't support enabling/disabling, so we keep local state
        }
    }
    
    private func deleteRule(_ rule: URLRewriteRule) {
        Task {
            do {
                try await APIClient.shared.deleteURLRewrite(pattern: rule.pattern)
                await loadRules()
            } catch {
                print("Error deleting URL rewrite: \(error)")
            }
        }
    }
    
    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            let rule = rules[index]
            Task {
                try? await APIClient.shared.deleteURLRewrite(pattern: rule.pattern)
            }
        }
        Task {
            await loadRules()
        }
    }
    
    private func moveRules(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        // Note: Backend doesn't support custom ordering
    }
}

struct URLRewriteRuleRow: View {
    let rule: URLRewriteRule
    
    var body: some View {
        HStack {
            Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.enabled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.pattern)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(rule.replacement)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(rule.type.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .opacity(rule.enabled ? 1.0 : 0.5)
    }
}

struct URLRewriteEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var rule: URLRewriteRule
    let onSave: (URLRewriteRule) -> Void
    
    init(rule: URLRewriteRule?, onSave: @escaping (URLRewriteRule) -> Void) {
        self._rule = State(initialValue: rule ?? URLRewriteRule(pattern: "", replacement: ""))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Pattern") {
                    TextField("Regex Pattern", text: $rule.pattern)
                        .font(.system(.body, design: .monospaced))
                    Text("Example: ^https?:\\/\\/(www\\.)?google\\.cn")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Replacement") {
                    TextField("Replacement URL", text: $rule.replacement)
                        .font(.system(.body, design: .monospaced))
                    Text("Example: https://www.google.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Type") {
                    Picker("Rewrite Type", selection: $rule.type) {
                        ForEach(URLRewriteRule.RewriteType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section {
                    Toggle("Enabled", isOn: $rule.enabled)
                }
            }
            .navigationTitle(rule.pattern.isEmpty ? "New Rewrite Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(rule.pattern.isEmpty || rule.replacement.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        URLRewriteManagerView()
    }
}
