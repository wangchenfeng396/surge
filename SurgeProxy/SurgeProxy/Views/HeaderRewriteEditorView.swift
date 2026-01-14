//
//  HeaderRewriteEditorView.swift
//  SurgeProxy
//
//  Header rewrite rule management
//

import SwiftUI

struct HeaderRewriteEditorView: View {
    @StateObject private var viewModel = HeaderRewriteViewModel()
    @State private var showingAddRule = false
    @State private var editingRule: HeaderRewriteRule?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.rules.isEmpty {
                    emptyState
                } else {
                    ruleList
                }
            }
            .navigationTitle("Header Rewrite")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddRule = true }) {
                        Label("添加规则", systemImage: "plus")
                    }
                    .disabled(viewModel.isSaving)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadRules()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddRule) {
                HeaderRewriteRuleEditorSheet(rule: nil) { newRule in
                    Task {
                        await viewModel.addRule(newRule)
                    }
                }
            }
            .sheet(item: $editingRule) { rule in
                HeaderRewriteRuleEditorSheet(rule: rule) { updatedRule in
                    Task {
                        await viewModel.updateRule(updatedRule)
                    }
                }
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.loadRules()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("无 Header 重写规则")
                .font(.title2)
            Text("创建规则来修改 HTTP 请求或响应头")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("添加第一条规则") {
                showingAddRule = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var ruleList: some View {
        List {
            ForEach(viewModel.rules) { rule in
                HeaderRewriteRuleRow(rule: rule)
                    .onTapGesture {
                        editingRule = rule
                    }
                    .contextMenu {
                        Button("编辑") {
                            editingRule = rule
                        }
                        Button(rule.enabled ? "禁用" : "启用") {
                            Task {
                                await viewModel.toggleRule(rule)
                            }
                        }
                        Divider()
                        Button("删除", role: .destructive) {
                            Task {
                                await viewModel.deleteRule(rule)
                            }
                        }
                    }
            }
        }
    }
}

struct HeaderRewriteRuleRow: View {
    let rule: HeaderRewriteRule
    
    var body: some View {
        HStack {
            Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.enabled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rule.type == .request ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(3)
                    
                    Text(rule.pattern)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Text(rule.header)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(rule.value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .opacity(rule.enabled ? 1.0 : 0.5)
    }
}

struct HeaderRewriteRuleEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var rule: HeaderRewriteRule
    
    let onSave: (HeaderRewriteRule) -> Void
    
    init(rule: HeaderRewriteRule?, onSave: @escaping (HeaderRewriteRule) -> Void) {
        self._rule = State(initialValue: rule ?? HeaderRewriteRule(pattern: "", header: "", value: "", type: .request))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("URL 模式") {
                    TextField("例如：^https://api\\.example\\.com", text: $rule.pattern)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                    Text("匹配 URL 的正则表达式")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Header 名称") {
                    TextField("例如：User-Agent", text: $rule.header)
                        .autocorrectionDisabled()
                    Text("要修改的 HTTP 头名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Header 值") {
                    TextField("新的 Header 值", text: $rule.value)
                        .autocorrectionDisabled()
                    Text("设置的新值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("类型") {
                    Picker("重写类型", selection: $rule.type) {
                        ForEach(HeaderRewriteRule.RewriteType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Toggle("启用", isOn: $rule.enabled)
                }
                
                Section {
                    Text("示例：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("User-Agent → Custom-Agent/1.0")
                        .font(.system(.caption, design: .monospaced))
                    Text("X-Custom-Header → CustomValue")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle(rule.pattern.isEmpty ? "新增 Header 规则" : "编辑规则")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(rule.pattern.isEmpty || rule.header.isEmpty)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class HeaderRewriteViewModel: ObservableObject {
    @Published var rules: [HeaderRewriteRule] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadRules() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            rules = try await apiClient.fetchHeaderRewrites()
            errorMessage = nil
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    func addRule(_ rule: HeaderRewriteRule) async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await apiClient.addHeaderRewrite(rule)
            await loadRules()
            errorMessage = nil
        } catch {
            errorMessage = "添加失败: \(error.localizedDescription)"
        }
    }
    
    func updateRule(_ rule: HeaderRewriteRule) async {
        // For now, delete and re-add (backend doesn't have update endpoint)
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            let oldRule = rules[index]
            await deleteRule(oldRule)
            await addRule(rule)
        }
    }
    
    func deleteRule(_ rule: HeaderRewriteRule) async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await apiClient.deleteHeaderRewrite(pattern: rule.pattern, header: rule.header)
            await loadRules()
            errorMessage = nil
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
        }
    }
    
    func toggleRule(_ rule: HeaderRewriteRule) async {
        var updatedRule = rule
        updatedRule.enabled.toggle()
        await updateRule(updatedRule)
    }
}

#Preview {
    HeaderRewriteEditorView()
}
