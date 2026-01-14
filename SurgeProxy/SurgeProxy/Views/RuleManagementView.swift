//
//  RuleManagementView.swift
//  SurgeProxy
//
//  Rule management view with comprehensive CRUD operations
//

import SwiftUI

struct RuleManagementView: View {
    @StateObject private var viewModel = RuleManagementViewModel()
    @State private var showingAddSheet = false
    @State private var selectedRule: (index: Int, rule: RuleConfigModel)?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.filteredRules(searchText: searchText), id: \.id) { wrapper in
                    SimpleRuleRow(rule: wrapper.rule, index: wrapper.index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRule = (wrapper.index, wrapper.rule)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteRule(index: wrapper.index)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: moveRule)
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: "搜索规则")
            .navigationTitle("路由规则")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadRules()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                SimpleRuleEditorSheet(
                    mode: .add,
                    availablePolicies: viewModel.availablePolicies
                ) { rule in
                    await viewModel.addRule(rule)
                }
            }
            .sheet(item: Binding(
                get: { selectedRule.map { RuleWrapper(index: $0.index, rule: $0.rule) } },
                set: { selectedRule = $0.map { ($0.index, $0.rule) } }
            )) { wrapper in
                SimpleRuleEditorSheet(
                    mode: .edit(wrapper.rule),
                    availablePolicies: viewModel.availablePolicies
                ) { updatedRule in
                    await viewModel.updateRule(index: wrapper.index, rule: updatedRule)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private func moveRule(from source: IndexSet, to destination: Int) {
        // Disable move when searching
        guard searchText.isEmpty else { return }
        
        Task {
            await viewModel.moveRules(from: source, to: destination)
        }
    }
}

// Helper wrapper for identifiable rule with index
struct RuleWrapper: Identifiable {
    let id: UUID = UUID()
    let index: Int
    let rule: RuleConfigModel
}

// MARK: - Rule Row

struct SimpleRuleRow: View {
    let rule: RuleConfigModel
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40)
                
                Text(rule.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ruleTypeColor.opacity(0.2))
                    .foregroundColor(ruleTypeColor)
                    .cornerRadius(4)
                
                if !rule.value.isEmpty {
                    Text(rule.value)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(rule.policy)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            if let comment = rule.comment, !comment.isEmpty {
                HStack {
                    Image(systemName: "text.bubble")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    
                    Text(comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var ruleTypeColor: Color {
        switch rule.type {
        case "DOMAIN": return .blue
        case "DOMAIN-SUFFIX": return .purple
        case "DOMAIN-KEYWORD": return .indigo
        case "IP-CIDR", "IP-CIDR6": return .orange
        case "GEOIP": return .green
        case "FINAL": return .red
        default: return .gray
        }
    }
}

// MARK: - Rule Editor Sheet

struct SimpleRuleEditorSheet: View {
    enum Mode {
        case add
        case edit(RuleConfigModel)
    }
    
    let mode: Mode
    let availablePolicies: [String]
    let onSave: (RuleConfigModel) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RuleEditorViewModel
    
    init(mode: Mode, availablePolicies: [String], onSave: @escaping (RuleConfigModel) async -> Void) {
        self.mode = mode
        self.availablePolicies = availablePolicies
        self.onSave = onSave
        
        switch mode {
        case .add:
            _viewModel = StateObject(wrappedValue: RuleEditorViewModel(availablePolicies: availablePolicies))
        case .edit(let rule):
            _viewModel = StateObject(wrappedValue: RuleEditorViewModel(rule: rule, availablePolicies: availablePolicies))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("规则类型")) {
                    Picker("类型", selection: $viewModel.type) {
                        ForEach(RuleType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if viewModel.showValueField {
                    Section(header: Text("匹配值")) {
                        TextField(valuePlaceholder, text: $viewModel.value)
                    }
                }
                
                Section(header: Text("策略")) {
                    Picker("选择策略", selection: $viewModel.policy) {
                        ForEach(availablePolicies, id: \.self) { policy in
                            Text(policy).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("选项")) {
                    Toggle("No Resolve", isOn: $viewModel.noResolve)
                        .disabled(!viewModel.supportsNoResolve)
                }
                
                Section(header: Text("备注")) {
                    TextField("备注（可选）", text: $viewModel.comment)
                }
            }
            .navigationTitle(mode.isEdit ? "编辑规则" : "添加规则")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let rule = viewModel.buildRule()
                            await onSave(rule)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
    
    private var valuePlaceholder: String {
        switch viewModel.type {
        case "DOMAIN": return "例如: google.com"
        case "DOMAIN-SUFFIX": return "例如: google.com"
        case "DOMAIN-KEYWORD": return "例如: google"
        case "IP-CIDR": return "例如: 192.168.0.0/16"
        case "IP-CIDR6": return "例如: 2001:db8::/32"
        case "GEOIP": return "例如: CN"
        case "USER-AGENT": return "例如: *Safari*"
        case "URL-REGEX": return "例如: ^https://.*"
        case "PROCESS-NAME": return "例如: Telegram"
        default: return "输入匹配值"
        }
    }
}

extension SimpleRuleEditorSheet.Mode {
    var isEdit: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}

// MARK: - View Models

@MainActor
class RuleManagementViewModel: ObservableObject {
    @Published var rules: [RuleConfigModel] = []
    @Published var availablePolicies: [String] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadData() async {
        await loadRules()
        await loadAvailablePolicies()
    }
    
    func filteredRules(searchText: String) -> [RuleWrapper] {
        var result: [RuleWrapper] = []
        for (index, rule) in rules.enumerated() {
            if searchText.isEmpty || 
               rule.value.localizedCaseInsensitiveContains(searchText) || 
               rule.policy.localizedCaseInsensitiveContains(searchText) || 
               (rule.comment ?? "").localizedCaseInsensitiveContains(searchText) {
                result.append(RuleWrapper(index: index, rule: rule))
            }
        }
        return result
    }
    
    func loadRules() async {
        do {
            rules = try await apiClient.fetchAllRules()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func loadAvailablePolicies() async {
        do {
            let groups = try await apiClient.fetchAllProxyGroups()
            availablePolicies = groups.map { $0.name } + ["DIRECT", "REJECT"]
        } catch {
            // Silently fail, use defaults
            availablePolicies = ["DIRECT", "REJECT"]
        }
    }
    
    func addRule(_ rule: RuleConfigModel) async {
        do {
            try await apiClient.addRule(rule)
            await loadRules()
        } catch {
            errorMessage = "添加失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func updateRule(index: Int, rule: RuleConfigModel) async {
        do {
            try await apiClient.updateRule(index: index, rule: rule)
            await loadRules()
        } catch {
            errorMessage = "更新失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func deleteRule(index: Int) async {
        do {
            try await apiClient.deleteRule(index: index)
            await loadRules()
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func moveRules(from source: IndexSet, to destination: Int) async {
        guard let from = source.first else { return }
        
        // Optimistic update
        // Note: For complex moves with IndexSet we might need better logic, but List usually sends one item at a time for drags.
        
        do {
            try await apiClient.moveRule(fromIndex: from, toIndex: destination)
            await loadRules() // Reload to ensure sync
        } catch {
            errorMessage = "移动失败: \(error.localizedDescription)"
            showError = true
            await loadRules() // Revert
        }
    }
}

@MainActor
class RuleEditorViewModel: ObservableObject {
    @Published var type = "DOMAIN-SUFFIX"
    @Published var value = ""
    @Published var policy = "DIRECT"
    @Published var noResolve = false
    @Published var comment = ""
    
    let availablePolicies: [String]
    
    init(rule: RuleConfigModel? = nil, availablePolicies: [String]) {
        self.availablePolicies = availablePolicies
        
        if let rule = rule {
            self.type = rule.type
            self.value = rule.value
            self.policy = rule.policy
            self.noResolve = rule.noResolve ?? false
            self.comment = rule.comment ?? ""
        }
    }
    
    var showValueField: Bool {
        type != "FINAL"
    }
    
    var supportsNoResolve: Bool {
        ["DOMAIN-SUFFIX", "DOMAIN", "DOMAIN-KEYWORD", "IP-CIDR", "IP-CIDR6"].contains(type)
    }
    
    var isValid: Bool {
        if type == "FINAL" {
            return !policy.isEmpty
        }
        return !value.isEmpty && !policy.isEmpty
    }
    
    func buildRule() -> RuleConfigModel {
        RuleConfigModel(
            type: type,
            value: type == "FINAL" ? "" : value,
            policy: policy,
            params: nil, // TODO: Parse params if needed
            noResolve: supportsNoResolve ? noResolve : nil,
            updateInterval: nil,
            comment: comment.isEmpty ? nil : comment
        )
    }
}

#Preview {
    RuleManagementView()
}
