//
//  RulesetEditorView.swift
//  SurgeProxy
//
//  Editor for Rule Sets (System, LAN, External)
//

import SwiftUI

struct RulesetEditorView: View {
    let groups: [String]
    let proxies: [String]
    let onSave: (ProxyRule) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    enum RulesetSource: Int, CaseIterable {
        case system
        case lan
        case external
        
        var title: String {
            switch self {
            case .system: return "Internal Ruleset: System"
            case .lan: return "Internal Ruleset: LAN"
            case .external: return "External Ruleset"
            }
        }
        
        var description: String {
            switch self {
            case .system: return "Includes rules for most requests sent by macOS and iOS itself. Requests sent by App Store, iTunes and other content services are not included."
            case .lan: return "Includes rules for LAN IP addresses and .local suffix. Please notice this ruleset will trigger a DNS lookup."
            case .external: return "Ruleset from a URL or a local file. The ruleset file should be a text file. Each line contains a rule declaration without the policy."
            }
        }
    }
    
    @State private var source: RulesetSource = .system
    @State private var policy = "REJECT"
    @State private var url = "https://ruleset.skk.moe/list/non_ip/icloud_global.conf"
    @State private var notifications = false
    @State private var notificationText = ""
    @State private var notificationInterval = 300
    @State private var extendedMatching = false
    @State private var noResolve = false
    @State private var preMatching = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Ruleset")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            
            Text("A ruleset contains multiple sub-rules. The policy will be used if any sub-rule matches.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            HStack(alignment: .top, spacing: 20) {
                // Left Column: Source & Policy
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Policy
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Policy:")
                            .fontWeight(.medium)
                        
                        PolicyPickerView(selection: $policy, groups: groups, proxies: proxies)
                            .frame(width: 250)
                    }
                    
                    Divider()
                    
                    // Source Selection
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(RulesetSource.allCases, id: \.self) { type in
                            HStack(alignment: .top) {
                                Button(action: { source = type }) {
                                    Image(systemName: source == type ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(source == type ? .blue : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(type.title)
                                            .fontWeight(.medium)
                                        if type != .external {
                                             Image(systemName: "questionmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                    
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    
                    if source == .external {
                        TextField("URL or File Path", text: $url)
                            .textFieldStyle(.roundedBorder)
                    }
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
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("No Resolve", isOn: $noResolve)
                            .toggleStyle(.checkbox)
                        Text("Skip the rule if the hostname of request is a domain")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Pre-Matching
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Pre-Matching", isOn: $preMatching)
                            .toggleStyle(.checkbox)
                        Text("Setting a pre-matching flag for the rule will cause the rule to ignore the order of the rule set and attempt to reject the request before the connection starts, reducing overhead.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                    let type = "RULE-SET"
                    // Construct value based on source
                    var val = ""
                    switch source {
                    case .system: val = "SYSTEM"
                    case .lan: val = "LAN"
                    case .external: val = url
                    }
                    
                    let rule = ProxyRule(
                        type: type,
                        value: val,
                        policy: policy,
                        noResolve: noResolve,
                        notification: notifications,
                        notificationText: notificationText,
                        notificationInterval: notificationInterval,
                        extendedMatching: extendedMatching,
                        preMatching: preMatching
                    )
                    onSave(rule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
    }
}

#Preview {
    RulesetEditorView(
        groups: ["Netflix", "Apple"],
        proxies: ["HK-01", "US-01"],
        onSave: { _ in }
    )
}
