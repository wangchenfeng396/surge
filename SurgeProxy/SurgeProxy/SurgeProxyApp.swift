//
//  SurgeProxyApp.swift
//  SurgeProxy
//
//  A native macOS application for controlling the Surge HTTP/HTTPS proxy server
//

import SwiftUI

@main
struct SurgeProxyApp: App {
    @StateObject private var proxyManager = GoProxyManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            NewContentView()
                .environmentObject(proxyManager)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Inject dependency into AppDelegate
                    appDelegate.proxyManager = proxyManager
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SurgeProxy") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "SurgeProxy",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 SurgeProxy"
                        ]
                    )
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(proxyManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var proxyManager: GoProxyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize configuration file
        Task {
            await ConfigFileManager.shared.ensureConfigFileExists()
            
            // Validate configuration
            let (isValid, error) = await ConfigFileManager.shared.validateConfigFile()
            if !isValid {
                print("⚠️ Configuration validation warning: \(error ?? "Unknown error")")
            }
        }
        
        setupMenuBar()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("⚠️ AppDelegate: Application will terminate")
        if let pm = proxyManager {
            print("⚠️ AppDelegate: Terminating backend process...")
            pm.backendManager.terminate()
            // Give it a moment to flush
            usleep(100000) // 0.1s
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: "Proxy Status")
            button.image?.isTemplate = true
        }
        
        // Ensure menu is updated when it opens to reflect current state
        let menu = NSMenu()
        menu.delegate = self
        
        // Proxy Mode Submenu
        let modeMenu = NSMenu()
        let modeItem = NSMenuItem(title: "Outbound Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        
        // Add Mode Items (Tags: 0=Rule, 1=Global, 2=Direct)
        let ruleItem = NSMenuItem(title: "Rule Based", action: #selector(setModeRule), keyEquivalent: "")
        let globalItem = NSMenuItem(title: "Global Proxy", action: #selector(setModeGlobal), keyEquivalent: "")
        let directItem = NSMenuItem(title: "Direct Outbound", action: #selector(setModeDirect), keyEquivalent: "")
        
        modeMenu.addItem(ruleItem)
        modeMenu.addItem(globalItem)
        modeMenu.addItem(directItem)
        
        menu.addItem(modeItem)
        menu.addItem(NSMenuItem.separator())
        
        // Controls
        menu.addItem(NSMenuItem(title: "Start Proxy", action: #selector(startProxy), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Stop Proxy", action: #selector(stopProxy), keyEquivalent: "x"))
        menu.addItem(NSMenuItem.separator())
        
        // Tools
        menu.addItem(NSMenuItem(title: "Dashboard...", action: #selector(openDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Copy Shell Command", action: #selector(copyShellCommand), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        
        // App
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "w"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    
    @objc func startProxy() {
        NotificationCenter.default.post(name: NSNotification.Name("StartProxy"), object: nil)
    }
    
    @objc func stopProxy() {
        NotificationCenter.default.post(name: NSNotification.Name("StopProxy"), object: nil)
    }
    
    @objc func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func setModeRule() {
        proxyManager?.mode = .ruleBased
        updateMenuState()
    }
    
    @objc func setModeGlobal() {
        proxyManager?.mode = .global
    }
    
    @objc func setModeDirect() {
        proxyManager?.mode = .direct
    }
    
    @objc func openDashboard() {
        // Open web dashboard based on configured port + 1 (usually) or external web controller port
        // Assuming default 9090 for now
        if let url = URL(string: "http://127.0.0.1:9090/ui") {
             NSWorkspace.shared.open(url)
        }
    }
    
    @objc func copyShellCommand() {
        guard let port = proxyManager?.config.port else { return }
        let command = "export https_proxy=http://127.0.0.1:\(port); export http_proxy=http://127.0.0.1:\(port); export all_proxy=socks5://127.0.0.1:\(port)"
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
    }
    
    // NSMenuDelegate to update checkmarks
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuState()
    }
    
    private func updateMenuState() {
        guard let menu = statusItem?.menu,
              let modeItem = menu.items.first(where: { $0.title == "Outbound Mode" }),
              let submenu = modeItem.submenu,
              let currentMode = proxyManager?.mode else { return }
        
        submenu.items.forEach { $0.state = .off }
        
        switch currentMode {
        case .ruleBased:
            submenu.item(at: 0)?.state = .on
        case .global:
            submenu.item(at: 1)?.state = .on
        case .direct:
            submenu.item(at: 2)?.state = .on
        }
    }
}

extension AppDelegate: NSMenuDelegate {}


