//
//  NewContentView.swift
//  SurgeProxy
//
//  Main application view with sidebar navigation
//

import SwiftUI

struct NewContentView: View {
    @EnvironmentObject var proxyManager: GoProxyManager
    @State private var selectedItem: NavigationItem = .activity
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            NavigationStack {
                switch selectedItem {
                case .activity:
                    ActivityView()
                case .overview:
                    OverviewView()
                case .process:
                    NewProcessView()
                case .device:
                    NewDeviceView()
                case .policy:
                    NewPolicyView()
                case .rule:
                    CompleteRuleView()
                case .capture:
                    CaptureView()
                case .decrypt:
                    DecryptView()
                case .rewrite:
                    RewriteMappingView()
                case .more:
                    MoreView()
                case .dashboard:
                    PlaceholderView(title: selectedItem.title)
                }
            }
        }
    }
}

struct RuleView: View {
    var body: some View {
        VStack {
            Text("Rule")
                .font(.title2)
                .fontWeight(.bold)
            Text("Rule configuration coming soon...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlaceholderView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension NavigationItem {
    var title: String {
        switch self {
        case .activity: return "Activity"
        case .overview: return "Overview"
        case .process: return "Process"
        case .device: return "Device"
        case .policy: return "Policy"
        case .rule: return "Rule"
        case .capture: return "Capture"
        case .decrypt: return "Decrypt"
        case .rewrite: return "Rewrite"
        case .more: return "More"
        case .dashboard: return "Dashboard"
        }
    }
}

#Preview {
    NewContentView()
        .environmentObject(GoProxyManager())
        .frame(width: 1200, height: 800)
}
