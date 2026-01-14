//
//  AdvancedRuleEditorView.swift
//  SurgeProxy
//
//  Advanced rule editor with all Surge rule types
//

import SwiftUI

struct AdvancedRuleEditorView: View {
    @State private var rules: [ProxyRule] = []
    @State private var showingAddRule = false
    @State private var editingRule: ProxyRule?
    @State private var availablePolicies = ["DIRECT", "REJECT", "REJECT-NO-DROP", "REJECT-DROP", "REJECT-TINYGIF", "PROXY"]
    
    var body: some View {
        VStack {
            if rules.isEmpty {
                emptyState
            } else {
                ruleList
            }
        }
        .navigationTitle("Advanced Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add Rule") {
                        showingAddRule = true
                    }
                    Button("Import Rules") {
                        // Import functionality
                    }
                    Button("Export Rules") {
                        // Export functionality
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AdvancedRuleEditorSheet(rule: nil, policies: availablePolicies) { newRule in
                rules.append(newRule)
                saveRules()
            }
        }
        .sheet(item: $editingRule) { rule in
            AdvancedRuleEditorSheet(rule: rule, policies: availablePolicies) { updatedRule in
                if let index = rules.firstIndex(where: { $0.id == updatedRule.id }) {
                    rules[index] = updatedRule
                    saveRules()
                }
            }
        }
        .onAppear(perform: loadRules)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Rules")
                .font(.title2)
            Text("Create rules to control traffic routing")
                .foregroundColor(.secondary)
            Button("Add First Rule") {
                showingAddRule = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var ruleList: some View {
        List {
            ForEach(rules) { rule in
                AdvancedRuleRow(rule: rule)
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
                        Button("Duplicate") {
                            duplicateRule(rule)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteRule(rule)
                        }
                    }
            }
            .onMove(perform: moveRules)
            .onDelete(perform: deleteRules)
        }
    }
    
    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: "ProxyRules"),
           let decoded = try? JSONDecoder().decode([ProxyRule].self, from: data) {
            rules = decoded
        }
    }
    
    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: "ProxyRules")
        }
    }
    
    private func toggleRule(_ rule: ProxyRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].enabled.toggle()
            saveRules()
        }
    }
    
    private func duplicateRule(_ rule: ProxyRule) {
        let newRule = ProxyRule(
            enabled: rule.enabled,
            type: rule.type,
            value: rule.value,
            policy: rule.policy,
            used: rule.used,
            comment: rule.comment
        )
        rules.append(newRule)
        saveRules()
    }
    
    private func deleteRule(_ rule: ProxyRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }
    
    private func deleteRules(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }
    
    private func moveRules(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        saveRules()
    }
}

struct AdvancedRuleRow: View {
    let rule: ProxyRule
    
    var body: some View {
        HStack {
            Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.enabled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.type)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(3)
                    
                    Text(rule.value)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                }
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(rule.policy)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !rule.comment.isEmpty {
                        Text("// \(rule.comment)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            if rule.used > 0 {
                Text("\(rule.used)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .opacity(rule.enabled ? 1.0 : 0.5)
    }
}

struct AdvancedRuleEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var rule: ProxyRule
    let policies: [String]
    let onSave: (ProxyRule) -> Void
    
    // Sub-rules state
    @State private var subRules: [SubRule] = []
    
    init(rule: ProxyRule?, policies: [String], onSave: @escaping (ProxyRule) -> Void) {
        self._rule = State(initialValue: rule ?? ProxyRule(
            enabled: true,
            type: "DOMAIN",
            value: "",
            policy: "DIRECT"
        ))
        self.policies = policies
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Type") {
                    Picker("Type", selection: $rule.type) {
                        ForEach(RuleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .onChange(of: rule.type) { _ in
                         // Reset or parse logic handled manually or via onAppear
                    }
                }
                
                if isLogicalType {
                    Section {
                        if subRules.isEmpty {
                            Text("No sub-rules added")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            List {
                                ForEach($subRules) { $subRule in
                                    HStack {
                                        Picker("", selection: $subRule.type) {
                                            ForEach(simpleRuleTypes, id: \.self) { type in
                                                Text(type.rawValue).tag(type)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 140)
                                        
                                        TextField("Value", text: $subRule.value)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                                .onDelete { indexSet in
                                    subRules.remove(atOffsets: indexSet)
                                }
                            }
                            // Using frame to give it some height in Form
                            .frame(minHeight: 200)
                        }
                        
                        Button(action: addSubRule) {
                            Label("Add Sub-Rule", systemImage: "plus")
                        }
                    } header: {
                        Text("Sub-Rules")
                    } footer: {
                        Text("Logical rules match based on these conditions.")
                    }
                } else {
                    Section("Match Value") {
                        HStack {
                            TextField(placeholderForType(RuleType(rawValue: rule.type) ?? .domain), text: $rule.value)
                                .font(.system(.body, design: .monospaced))
                            
                            if RuleType(rawValue: rule.type) == .processName {
                                Button("Select App...") {
                                    let panel = NSOpenPanel()
                                    panel.allowsMultipleSelection = false
                                    panel.canChooseDirectories = false
                                    panel.canChooseFiles = true
                                    panel.allowedContentTypes = [.application]
                                    
                                    if panel.runModal() == .OK, let url = panel.url {
                                        if let bundleName = Bundle(url: url)?.infoDictionary?["CFBundleExecutable"] as? String {
                                            rule.value = bundleName
                                        } else {
                                            rule.value = url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Text(hintForType(RuleType(rawValue: rule.type) ?? .domain))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Policy") {
                    Picker("Action", selection: $rule.policy) {
                        ForEach(policies, id: \.self) { policy in
                            Text(policy).tag(policy)
                        }
                    }
                }
                
                Section("Options") {
                    Toggle("Enabled", isOn: $rule.enabled)
                    
                    TextField("Comment (optional)", text: $rule.comment)
                }
            }
            .navigationTitle(rule.value.isEmpty && !isLogicalType ? "New Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isLogicalType {
                            rule.value = formatSubRules()
                        }
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if isLogicalType {
                    parseSubRules()
                }
            }
        }
    }
    
    private func placeholderForType(_ type: RuleType) -> String {
        switch type {
        case .domain:
            return "example.com"
        case .domainSuffix:
            return "google.com"
        case .domainKeyword:
            return "keyword"
        case .ipCidr:
            return "192.168.1.0/24"
        case .geoip:
            return "CN"
        case .processName:
            return "Electron"
        case .urlRegex:
            return "^https?://.*\\.example\\.com"
        default:
            return "Value"
        }
    }
    
    private func hintForType(_ type: RuleType) -> String {
        switch type {
        case .domain:
            return "Exact domain match"
        case .domainSuffix:
            return "Matches domain and all subdomains"
        case .domainKeyword:
            return "Matches if domain contains keyword"
        case .ipCidr:
            return "IP address range in CIDR notation"
        case .geoip:
            return "Country code (e.g., CN, US, JP)"
        case .processName:
            return "Process Name (e.g. Surge) or Full Path"
        case .urlRegex:
            return "Regular expression pattern"
        default:
            return "Enter the match value"
        }
    }
    
    private var isLogicalType: Bool {
        let t = RuleType(rawValue: rule.type)
        return t == .and || t == .or || t == .not
    }
    
    private var isValid: Bool {
        if isLogicalType {
            return !subRules.isEmpty && subRules.allSatisfy { !$0.value.isEmpty }
        }
        return !rule.value.isEmpty
    }
    
    private var simpleRuleTypes: [RuleType] {
        return RuleType.allCases.filter { type in
            type != .and && type != .or && type != .not && type != .final && type != .ruleSet
        }
    }
    
    private func addSubRule() {
        subRules.append(SubRule(type: .domain, value: ""))
    }
    
    private func parseSubRules() {
        // Parse "((Type,Value),(Type,Value))"
        var str = rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("((") && str.hasSuffix("))") {
            str = String(str.dropFirst(2).dropLast(2))
        } else if str.hasPrefix("(") && str.hasSuffix(")") {
             str = String(str.dropFirst(1).dropLast(1))
        }
        
        let components = str.components(separatedBy: "),(")
        var parsed: [SubRule] = []
        
        for comp in components {
            let parts = comp.split(separator: ",", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                if let type = RuleType(rawValue: parts[0].trimmingCharacters(in: .whitespaces)),
                   simpleRuleTypes.contains(type) {
                    parsed.append(SubRule(type: type, value: parts[1].trimmingCharacters(in: .whitespaces)))
                } else {
                    if let type = RuleType(rawValue: parts[0]) {
                         parsed.append(SubRule(type: type, value: parts[1]))
                    }
                }
            }
        }
        subRules = parsed
    }
    
    private func formatSubRules() -> String {
        let content = subRules.map { "(\($0.type.rawValue),\($0.value))" }.joined(separator: ",")
        return "((\(content)))"
    }
}

struct SubRule: Identifiable {
    let id = UUID()
    var type: RuleType
    var value: String
}

#Preview {
    NavigationView {
        AdvancedRuleEditorView()
    }
}
