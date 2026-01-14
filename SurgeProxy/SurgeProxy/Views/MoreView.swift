//
//  MoreView.swift
//  SurgeProxy
//
//  More settings page with feature cards
//

import SwiftUI

struct MoreView: View {
    @State private var showingSettings = false
    @State private var showingDNS = false
    @State private var showingConfigImport = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("More")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    // Settings
                    MoreFeatureCard(
                        icon: "gearshape.fill",
                        iconColor: .blue,
                        title: "Settings",
                        description: "Adjust all the Surge engine settings here",
                        action: { showingSettings = true }
                    )
                    
                    // Appearance
                    MoreFeatureCard(
                        icon: "paintpalette.fill",
                        iconColor: .purple,
                        title: "Appearance",
                        description: "Menubar icon, Dock icon and notifications settings",
                        action: { }
                    )
                    
                    // DNS
                    MoreFeatureCard(
                        icon: "network",
                        iconColor: .orange,
                        title: "DNS",
                        description: "DNS related settings and local DNS mapping",
                        action: { showingDNS = true }
                    )
                    
                    // Config Import/Export
                    MoreFeatureCard(
                        icon: "arrow.down.doc.fill",
                        iconColor: .green,
                        title: "Config Import/Export",
                        description: "Import and export Surge configuration files",
                        action: { showingConfigImport = true }
                    )
                    
                    // Module
                    MoreFeatureCard(
                        icon: "shippingbox.fill",
                        iconColor: .orange,
                        title: "Module",
                        description: "Override the current profile with a set of settings. Highly flexible for diverse purposes.",
                        action: { }
                    )
                    
                    // Profile
                    MoreFeatureCard(
                        icon: "doc.text.fill",
                        iconColor: .blue,
                        title: "Profile",
                        description: "Most functions of Surge is controlled by the profile. You may manage your profiles here.",
                        action: { }
                    )
                    
                    // License & Updates
                    MoreFeatureCard(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: "License & Updates",
                        description: "Manage your license here and other update settings.",
                        action: { }
                    )
                    
                    // Scripts
                    MoreFeatureCard(
                        icon: "terminal.fill",
                        iconColor: .purple,
                        title: "Scripts",
                        description: "Use JavaScript to extend the ability of Surge as your wish.",
                        action: { }
                    )
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingDNS) {
            DNSSettingsView()
        }
        .sheet(isPresented: $showingConfigImport) {
            ConfigImportExportView()
                .frame(width: 600, height: 500)
        }
    }
}

struct MoreFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(iconColor)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MoreView()
        .frame(width: 900, height: 700)
}
