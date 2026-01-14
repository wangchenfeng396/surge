//
//  CompositeRuleEditorView.swift
//  SurgeProxy
//
//  Editor for AND/OR/NOT composite rules
//

import SwiftUI

struct CompositeRuleEditorView: View {
    let groups: [String]
    let proxies: [String]
    let onSave: (CompositeRule) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var ruleType: AdvancedRuleType = .and
    @State private var subrules: [ProxyRule] = []
    @State private var policy = "DIRECT"
    @State private var comment = ""
    @State private var showingAddSubrule = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Logical Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Use logical operator matching to support complex scenarios.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Logical Operator
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logical Operator")
                            .font(.headline)
                        
                        Picker("", selection: $ruleType) {
                            Text("AND").tag(AdvancedRuleType.and)
                            Text("OR").tag(AdvancedRuleType.or)
                            Text("NOT").tag(AdvancedRuleType.not)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                    
                    Divider()
                    
                    // Policy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Policy")
                            .font(.headline)
                        
                        PolicyPickerView(selection: $policy, groups: groups, proxies: proxies)
                            .frame(width: 250)
                    }
                    
                    Divider()
                    
                    // Comment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comment")
                            .font(.headline)
                        
                        TextField("Optional comment", text: $comment)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Divider()
                    
                    // Subrules Table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conditions")
                            .font(.headline)
                        
                        VStack(spacing: 0) {
                            // Table Header
                            HStack {
                                Text("Type")
                                    .frame(width: 120, alignment: .leading)
                                Text("Value")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            if subrules.isEmpty {
                                Text("No conditions")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(subrules, id: \.id) { rule in
                                    HStack {
                                        Text(rule.type)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(width: 120, alignment: .leading)
                                        
                                        Text(rule.value)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    
                                    Divider()
                                }
                            }
                            
                            // Toolbar
                            HStack(spacing: 0) {
                                Button(action: { showingAddSubrule = true }) {
                                    Image(systemName: "plus")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderless)
                                .frame(height: 24)
                                
                                Divider()
                                
                                Button(action: {
                                    if !subrules.isEmpty {
                                        subrules.removeLast()
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderless)
                                .frame(height: 24)
                                .disabled(subrules.isEmpty)
                            }
                            .frame(height: 24)
                            .background(Color(NSColor.controlBackgroundColor))
                        }
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Done") {
                    let rule = CompositeRule(
                        type: ruleType,
                        subrules: subrules,
                        policy: policy,
                        comment: comment
                    )
                    onSave(rule)
                    dismiss()
                }
                .disabled(subrules.isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingAddSubrule) {
            RuleEditorSheet(
                rule: nil,
                availablePolicies: ["DIRECT", "REJECT", "PROXY"] + groups + proxies,
                groups: groups,
                proxies: proxies
            ) { newRule in
                subrules.append(newRule)
            }
        }
    }
}

#Preview {
    CompositeRuleEditorView(
        groups: ["Netflix", "Apple"],
        proxies: ["HK-01", "US-01"],
        onSave: { _ in }
    )
}
