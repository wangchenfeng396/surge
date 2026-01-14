//
//  RulesetManagerView.swift
//  SurgeProxy
//
//  Ruleset management view
//

import SwiftUI

struct RulesetManagerView: View {
    @StateObject private var ruleManager = RuleManager()
    @State private var showingAddRuleset = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rulesets")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingAddRuleset = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Ruleset")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            if ruleManager.rulesets.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Rulesets")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Add remote rulesets to manage rules efficiently")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(ruleManager.rulesets) { ruleset in
                        RulesetRow(ruleset: ruleset, ruleManager: ruleManager)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddRuleset) {
            RulesetEditorView { newRuleset in
                ruleManager.rulesets.append(newRuleset)
            }
        }
    }
}

struct RulesetRow: View {
    let ruleset: RulesetReference
    let ruleManager: RuleManager
    @State private var isUpdating = false
    
    var body: some View {
        HStack {
            Toggle("", isOn: .constant(ruleset.enabled))
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ruleset.name)
                    .font(.headline)
                
                Text(ruleset.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text("\(ruleset.ruleCount) rules")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    if let lastUpdated = ruleset.lastUpdated {
                        Text("Updated \(lastUpdated, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not updated yet")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if isUpdating {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Update") {
                    updateRuleset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func updateRuleset() {
        isUpdating = true
        ruleManager.updateRuleset(ruleset) { result in
            DispatchQueue.main.async {
                isUpdating = false
                switch result {
                case .success(let count):
                    print("Updated ruleset with \(count) rules")
                case .failure(let error):
                    print("Failed to update ruleset: \(error)")
                }
            }
        }
    }
}

struct RulesetEditorView: View {
    let onSave: (RulesetReference) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var policy = "PROXY"
    @State private var updateInterval = 24
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Add Ruleset")
                .font(.title2)
                .fontWeight(.semibold)
                .padding()
            
            Divider()
            
            Form {
                TextField("Name:", text: $name)
                TextField("URL:", text: $url)
                Picker("Policy:", selection: $policy) {
                    Text("DIRECT").tag("DIRECT")
                    Text("PROXY").tag("PROXY")
                    Text("REJECT").tag("REJECT")
                }
                Stepper("Update Interval: \(updateInterval) hours", value: $updateInterval, in: 1...168)
            }
            .padding()
            
            Divider()
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let ruleset = RulesetReference(
                        name: name,
                        url: url,
                        policy: policy,
                        updateInterval: updateInterval
                    )
                    onSave(ruleset)
                    dismiss()
                }
                .disabled(name.isEmpty || url.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
    }
}

#Preview {
    RulesetManagerView()
}
