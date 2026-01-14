//
//  SidebarView.swift
//  SurgeProxy
//
//  Sidebar navigation matching Surge's layout
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationItem
    
    var body: some View {
        List(selection: $selection) {
            // Main section
            Section {
                NavigationLink(value: NavigationItem.activity) {
                    Label("Activity", systemImage: "chart.bar.fill")
                }
                NavigationLink(value: NavigationItem.overview) {
                    Label("Overview", systemImage: "square.grid.2x2.fill")
                }
            }
            
            // Clients section
            Section("Clients") {
                NavigationLink(value: NavigationItem.process) {
                    Label("Process", systemImage: "cpu")
                }
                NavigationLink(value: NavigationItem.device) {
                    Label("Device", systemImage: "desktopcomputer")
                }
            }
            
            // Proxies section
            Section("Proxies") {
                NavigationLink(value: NavigationItem.policy) {
                    Label("Policy", systemImage: "arrow.triangle.branch")
                }
                NavigationLink(value: NavigationItem.rule) {
                    Label("Rule", systemImage: "list.bullet.rectangle")
                }
            }
            
            // HTTP section
            Section("HTTP") {
                NavigationLink(value: NavigationItem.capture) {
                    Label("Capture", systemImage: "dot.radiowaves.left.and.right")
                }
                NavigationLink(value: NavigationItem.decrypt) {
                    Label("Decrypt", systemImage: "lock.open.fill")
                }
                NavigationLink(value: NavigationItem.rewrite) {
                    Label("Rewrite", systemImage: "pencil.and.outline")
                }
            }
            
            Spacer()
            
            // Bottom section
            Section {
                NavigationLink(value: NavigationItem.more) {
                    Label("More", systemImage: "ellipsis.circle")
                }
                NavigationLink(value: NavigationItem.dashboard) {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
            }

        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
             BackendStatusView()
                .padding(.bottom, 8)
        }
        .frame(minWidth: 200)
    }
}

enum NavigationItem: Hashable {
    case activity
    case overview
    case process
    case device
    case policy
    case rule
    case capture
    case decrypt
    case rewrite
    case more
    case dashboard
}

#Preview {
    SidebarView(selection: .constant(.activity))
        .frame(width: 200, height: 600)
}
