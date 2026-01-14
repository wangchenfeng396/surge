//
//  CompleteRuleView.swift
//  SurgeProxy
//
//  Complete Rule management view matching Surge's design
//

import SwiftUI

struct CompleteRuleView: View {
    @State private var rules: [ProxyRule] = []
    @State private var searchText = ""
    @State private var showingAddRule = false
    @State private var editingRule: ProxyRule?
    @State private var selectedRuleIDs = Set<ProxyRule.ID>()
    @State private var selectedRules = Set<UUID>()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var availablePolicies: [String] = ["DIRECT", "REJECT", "PROXY"]
    @State private var proxyGroups: [String] = []
    @State private var proxyNames: [String] = []
    @State private var showingAddLogicalRule = false
    @State private var showingAddRuleset = false
    
    var filteredRules: [ProxyRule] {
        if searchText.isEmpty {
            return rules
        }
        return rules.filter { rule in
            rule.value.localizedCaseInsensitiveContains(searchText) ||
            rule.policy.localizedCaseInsensitiveContains(searchText) ||
            rule.comment.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            // headerSection removed as Table provides its own headers

            
            Divider()
            
            if isLoading {
                ProgressView("加载规则...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("重试") { loadRules() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Rules table
                rulesTable
            }
            
            Divider()
            
            // Bottom toolbar
            bottomToolbar
        }
        .sheet(isPresented: $showingAddRule) {
            RuleEditorSheet(
                rule: nil,
                availablePolicies: availablePolicies,
                groups: proxyGroups,
                proxies: proxyNames
            ) { newRule in
                addRule(newRule)
            }
        }
        .sheet(isPresented: $showingAddLogicalRule) {
             CompositeRuleEditorView(
                groups: proxyGroups,
                proxies: proxyNames
             ) { newRule in
                // For now, convert back to simple rules or handle composite separately?
                // The current app architecture stores everything as ProxyRule (simple).
                // AdvancedRuleTypes.swift suggests we have separate 'compositeRules' in RuleManager.
                // But CompleteRuleView uses [ProxyRule].
                // We likely need to adapt 'newRule' (CompositeRule) into 'ProxyRule' or handle it.
                // Since 'ProxyRule' has 'type' which can be 'AND', 'OR', etc.
                // Let's create a ProxyRule from CompositeRule manually for now.
                
                let ruleString = newRule.toSurgeFormat()
                if let parsed = parseRuleString(ruleString, index: rules.count) {
                    addRule(parsed)
                }
             }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorSheet(
                rule: rule,
                availablePolicies: availablePolicies,
                groups: proxyGroups,
                proxies: proxyNames
            ) { updatedRule in
                updateRule(updatedRule)
            }
        }
        .navigationTitle("Rule (\(rules.count))")
        .searchable(text: $searchText, placement: .automatic, prompt: "搜索规则")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: loadRules) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新")
            }
        }
        .onAppear {
            loadRules()
            loadPolicies()
        }
    }
    
    // MARK: - Header Section
    
    // MARK: - Rules Table
    
    private var rulesTable: some View {
        Table(filteredRules, selection: $selectedRuleIDs) {
            TableColumn("") { rule in
                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { _ in toggleRule(rule) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }
            .width(30)
            
            TableColumn("#") { rule in
                Text(rule.backendID.map { "\($0)" } ?? "-")
                    .foregroundColor(.secondary)
            }
            .width(40)
            
            TableColumn("Type") { rule in
                Text(rule.type)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor(for: rule.type).opacity(0.2))
                    .foregroundColor(typeColor(for: rule.type))
                    .cornerRadius(4)
            }
            .width(120)
            
            TableColumn("Value") { rule in
                Text(rule.value)
                    .font(.system(.body, design: .monospaced))
            }
            
            TableColumn("Policy") { rule in
                Text(rule.policy)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            .width(120)
            
            TableColumn("Used") { rule in
                Text("\(rule.used)")
                    .foregroundColor(rule.used > 0 ? .primary : .secondary)
            }
            .width(60)
            
            TableColumn("Comment") { rule in
                Text(rule.comment)
                    .foregroundColor(.secondary)
            }
            
            TableColumn("Actions") { rule in
                HStack(spacing: 8) {
                    Button(action: { editingRule = rule }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { deleteRule(rule) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .width(60)
        }
    }
    
    // Helper for Table Column Color
    private func typeColor(for type: String) -> Color {
        switch type {
        case "DOMAIN": return .blue
        case "DOMAIN-SUFFIX": return .purple
        case "DOMAIN-KEYWORD": return .indigo
        case "IP-CIDR", "IP-CIDR6": return .orange
        case "GEOIP": return .green
        case "FINAL": return .red
        case "RULE-SET": return .cyan
        case "PROCESS-NAME": return .pink
        default: return .gray
        }
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack {
            Menu {
                Button("Standard Rule") { showingAddRule = true }
                Button("Logical Rule") { showingAddLogicalRule = true }
                Button("Ruleset") { showingAddRuleset = true }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("添加")
                }
            }
            .menuStyle(.borderlessButton)
            
            Menu {
                Button("导出为 JSON") { exportRulesAsJSON() }
                Button("从 JSON 导入") { importRulesFromJSON() }
                Divider()
                Button("导出为 Surge 格式") { exportSurgeFormat() }
                Button("从 Surge 格式导入") { importSurgeFormat() }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.on.square")
                    Text("导入/导出")
                }
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
            
            Button("重置计数器") {
                resetCounters()
            }
            .buttonStyle(.bordered)
            
            Button("保存更改") {
                saveRulesToBackend()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Data Loading
    
    private func loadRules() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use fetchRulesDetail to get rich data (hit count, enabled, etc)
                let response = try await APIClient.shared.fetchRulesDetail()
                
                let mappedRules = response.rules.map { dto in
                     ProxyRule(
                        id: UUID(),
                        backendID: dto.id,
                        enabled: dto.enabled,
                        type: dto.type,
                        value: dto.payload,
                        policy: dto.policy,
                        used: Int(dto.hit_count),
                        comment: dto.comment
                     )
                }
                
                await MainActor.run {
                    self.rules = mappedRules
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "加载规则失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadPolicies() {
        Task {
            do {
                let groups = try await APIClient.shared.fetchAllProxyGroups()
                let proxies = try await APIClient.shared.fetchProxies()
                
                var policies = ["DIRECT", "REJECT"]
                policies.append(contentsOf: groups.map { $0.name })
                policies.append(contentsOf: proxies.proxies.map { $0.name })
                
                await MainActor.run {
                    self.proxyGroups = groups.map { $0.name }
                    self.proxyNames = proxies.proxies.map { $0.name }
                    self.availablePolicies = Array(Set(policies))
                }
            } catch {
                // 使用默认策略
            }
        }
    }
    
    private func parseRulesFromStrings(_ ruleStrings: [String]) -> [ProxyRule] {
        return ruleStrings.enumerated().compactMap { index, ruleString in
            parseRuleString(ruleString, index: index)
        }
    }
    
    private func parseRuleString(_ ruleString: String, index: Int) -> ProxyRule? {
        // 格式: TYPE,VALUE,POLICY 或 TYPE,VALUE,POLICY // comment
        var str = ruleString
        var comment = ""
        
        if let commentRange = str.range(of: " // ") {
            comment = String(str[commentRange.upperBound...])
            str = String(str[..<commentRange.lowerBound])
        }
        
        let parts = str.components(separatedBy: ",")
        guard parts.count >= 2 else { return nil }
        
        let type = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts.count > 2 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        let policy = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : parts[1].trimmingCharacters(in: .whitespaces)
        
        return ProxyRule(
            id: UUID(),
            backendID: index, // Approximation for legacy parser
            enabled: true,
            type: type,
            value: value,
            policy: policy,
            used: 0,
            comment: comment
        )
    }
    
    // MARK: - CRUD Operations
    
    private func addRule(_ rule: ProxyRule) {
        rules.append(rule)
        saveRulesToBackend()
    }
    
    private func updateRule(_ rule: ProxyRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            // Optimistic update, but we should probably reload or ensure backendID is preserved
            saveRulesToBackend()
        }
    }
    
    private func deleteRule(_ rule: ProxyRule) {
        rules.removeAll { $0.id == rule.id }
        saveRulesToBackend()
    }
    
    private func duplicateRule(_ rule: ProxyRule) {
        let newRule = ProxyRule(
            id: UUID(),
            backendID: nil, // New rule
            enabled: rule.enabled,
            type: rule.type,
            value: rule.value,
            policy: rule.policy,
            used: 0,
            comment: rule.comment + " (副本)"
        )
        rules.append(newRule)
    }
    
    private func resetCounters() {
        // Optimistic clear
        for i in 0..<rules.count {
            rules[i].used = 0
        }
        
        Task {
            do {
                try await APIClient.shared.resetRuleCounters()
                // Reload to sync
                loadRules()
            } catch {
                print("重置计数失败: \(error)")
            }
        }
    }
    
    private func toggleRule(_ rule: ProxyRule) {
        guard let backendID = rule.backendID else { 
            // If no backend ID, just toggle local state (might be new rule not saved)
            if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[index].enabled.toggle()
            }
            return 
        }
        
        let newState = !rule.enabled
        // Optimistic update
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].enabled = newState
        }
        
        Task {
            do {
                try await APIClient.shared.toggleRule(id: backendID, enabled: newState)
            } catch {
                // Revert on error
                await MainActor.run {
                    if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                        rules[index].enabled = !newState
                    }
                }
            }
        }
    }
    
    private func saveRulesToBackend() {
        let ruleStrings = rules.map { rule -> String in
            var str = "\(rule.type),\(rule.value),\(rule.policy)"
            if !rule.comment.isEmpty {
                str += " // \(rule.comment)"
            }
            return str
        }
        
        Task {
            do {
                try await APIClient.shared.updateRules(ruleStrings)
                // Reload to get new IDs
                loadRules()
            } catch {
                print("保存规则失败: \(error)")
            }
        }
    }
    
    // MARK: - Import/Export
    
    private func exportRulesAsJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(rules),
              let json = String(data: data, encoding: .utf8) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "rules.json"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? json.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func importRulesFromJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = try? Data(contentsOf: url),
                   let imported = try? JSONDecoder().decode([ProxyRule].self, from: data) {
                    rules.append(contentsOf: imported)
                    saveRulesToBackend()
                }
            }
        }
    }
    
    private func exportSurgeFormat() {
        let content = rules.map { rule -> String in
            var str = "\(rule.type),\(rule.value),\(rule.policy)"
            if !rule.comment.isEmpty {
                str += " // \(rule.comment)"
            }
            return str
        }.joined(separator: "\n")
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "surge_rules.conf"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func importSurgeFormat() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.text]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let content = try? String(contentsOf: url) {
                    let lines = content.components(separatedBy: .newlines)
                    let imported = lines.enumerated().compactMap { parseRuleString($0.element, index: $0.offset) }
                    rules.append(contentsOf: imported)
                    saveRulesToBackend()
                }
            }
        }
    }
}

// MARK: - Rule Row View

struct RuleRowView: View {
    let index: Int
    let rule: ProxyRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            Text("\(index)")
                .frame(width: 40, alignment: .leading)
                .foregroundColor(.secondary)
            
            Text(rule.type)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(typeColor.opacity(0.2))
                .foregroundColor(typeColor)
                .cornerRadius(4)
                .frame(width: 120, alignment: .leading)
            
            Text(rule.value)
                .frame(minWidth: 250, alignment: .leading)
                .lineLimit(1)
            
            Text(rule.policy)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
                .frame(width: 100, alignment: .leading)
            
            // Usage count
            Text("\(rule.used)")
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(rule.used > 0 ? .primary : .secondary)
                .padding(.trailing, 8)
                
            Text(rule.comment)
                .frame(minWidth: 100, alignment: .leading)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(rule.enabled ? Color.clear : Color.gray.opacity(0.1))
        .opacity(rule.enabled ? 1.0 : 0.6)
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
    
    private var typeColor: Color {
        switch rule.type {
        case "DOMAIN": return .blue
        case "DOMAIN-SUFFIX": return .purple
        case "DOMAIN-KEYWORD": return .indigo
        case "IP-CIDR", "IP-CIDR6": return .orange
        case "GEOIP": return .green
        case "FINAL": return .red
        case "RULE-SET": return .cyan
        case "PROCESS-NAME": return .pink
        default: return .gray
        }
    }
}

// MARK: - Rule Editor Sheet

struct RuleEditorSheet: View {
    let rule: ProxyRule?
    let availablePolicies: [String]
    let groups: [String]
    let proxies: [String]
    let onSave: (ProxyRule) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var ruleType: RuleType
    @State private var value: String
    @State private var policy: String
    @State private var comment: String
    @State private var noResolve = false
    
    @State private var extendedMatching = false
    @State private var notifications = false
    @State private var notificationText = ""
    @State private var notificationInterval = 300
    
    init(rule: ProxyRule?, availablePolicies: [String], groups: [String], proxies: [String], onSave: @escaping (ProxyRule) -> Void) {
        self.rule = rule
        self.availablePolicies = availablePolicies
        self.groups = groups
        self.proxies = proxies
        self.onSave = onSave
        
        _ruleType = State(initialValue: RuleType(rawValue: rule?.type ?? "") ?? .domain)
        _value = State(initialValue: rule?.value ?? "")
        _policy = State(initialValue: rule?.policy ?? "DIRECT")
        _comment = State(initialValue: rule?.comment ?? "")
        
        _extendedMatching = State(initialValue: rule?.extendedMatching ?? false)
        _notifications = State(initialValue: rule?.notification ?? false)
        _notificationText = State(initialValue: rule?.notificationText ?? "")
        _notificationInterval = State(initialValue: rule?.notificationInterval ?? 300)
        _noResolve = State(initialValue: rule?.noResolve ?? false)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(rule == nil ? "New Standard Rule" : "Edit Standard Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            HStack(alignment: .top, spacing: 20) {
                // Left Column: Rule & Action
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Rule Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rule Type:")
                            .fontWeight(.medium)
                        
                        Picker("", selection: $ruleType) {
                            ForEach(RuleType.allCases.filter { $0.needsValue && $0 != .ruleSet }, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .frame(width: 200)
                        
                        Text(ruleType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    
                    // Value
                    if ruleType != .final {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(labelForValue)
                                .fontWeight(.medium)
                            
                            TextField(placeholder, text: $value)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // Policy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Policy:")
                            .fontWeight(.medium)
                        
                        PolicyPickerView(selection: $policy, groups: groups, proxies: proxies)
                            .frame(width: 250)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    
                    // Comment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comment:")
                            .fontWeight(.medium)
                        
                        TextField("Comment", text: $comment)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Right Column: Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Options")
                        .fontWeight(.medium)
                    
                    // Notification
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show a notification when the rule is matched", isOn: $notifications)
                            .toggleStyle(.checkbox)
                        
                        if notifications {
                            TextField("Notification Text", text: $notificationText)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack {
                                Text("Show the next notification only after")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("", value: $notificationInterval, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                Text("seconds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Extended Matching
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Extended Matching", isOn: $extendedMatching)
                            .toggleStyle(.checkbox)
                        Text("After enabling this option, the rule will try to match both the SNI of HTTPS requests and the Host field of HTTP requests at the same time.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // No Resolve
                    if ruleType == .ipCidr || ruleType == .ipCidr6 || ruleType == .geoip {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("No Resolve", isOn: $noResolve)
                                .toggleStyle(.checkbox)
                            Text("Skip the rule if the hostname of request is a domain")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 300)
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Done") {
                    var finalValue = value
                    if noResolve && (ruleType == .ipCidr || ruleType == .ipCidr6 || ruleType == .geoip) {
                        finalValue += ",no-resolve"
                    }
                    
                    let newRule = ProxyRule(
                        id: rule?.id ?? UUID(),
                        enabled: rule?.enabled ?? true,
                        type: ruleType.rawValue,
                        value: finalValue,
                        policy: policy,
                        used: rule?.used ?? 0,
                        comment: comment,
                        notification: notifications,
                        notificationText: notificationText,
                        notificationInterval: notificationInterval,
                        extendedMatching: extendedMatching,
                        preMatching: false // Standard rules usually don't have pre-matching exposed in this UI
                    )
                    onSave(newRule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(ruleType != .final && value.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
    }
    
    private var labelForValue: String {
        switch ruleType {
        case .domain, .domainSuffix, .domainKeyword: return "Domain:"
        case .processName: return "Process Name:"
        case .userAgent: return "User Agent:"
        case .urlRegex: return "Regex:"
        default: return "Value:"
        }
    }
    
    private var placeholder: String {
        switch ruleType {
        case .domain, .domainSuffix, .domainKeyword:
            return "example.com"
        case .ipCidr, .ipCidr6:
            return "192.168.0.0/16"
        case .geoip:
            return "CN"
        case .processName:
            return "Safari"
        case .urlRegex:
            return "^https?://.*\\.example\\.com"
        case .ruleSet:
            return "https://example.com/rules.list"
        default:
            return "值"
        }
    }
}

// ProxyRule and RuleType are defined in RuleModel.swift and ConfigModels.swift

struct PolicyPickerView: View {
    @Binding var selection: String
    let groups: [String]
    let proxies: [String]
    
    var body: some View {
        Picker("", selection: $selection) {
            Section("Built-in") {
                Text("DIRECT").tag("DIRECT")
                Text("REJECT").tag("REJECT")
            }
            
            if !groups.isEmpty {
                Section("Policy Group") {
                    ForEach(groups, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }
            }
            
            if !proxies.isEmpty {
                Section("Proxy") {
                    ForEach(proxies, id: \.self) { proxy in
                        Text(proxy).tag(proxy)
                    }
                }
            }
            
            Section("Advanced") {
                Text("REJECT-NO-DROP").tag("REJECT-NO-DROP")
                Text("REJECT-DROP").tag("REJECT-DROP")
                Text("REJECT-TINYGIF").tag("REJECT-TINYGIF")
            }
        }
        .pickerStyle(.menu)
    }
}

#Preview {
    CompleteRuleView()
        .frame(width: 1000, height: 700)
}

