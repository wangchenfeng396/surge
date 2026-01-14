//
//  CaptureView.swift
//  SurgeProxy
//
//  HTTP Capture view for inspecting requests/responses
//

import SwiftUI

struct CaptureView: View {
    @State private var captures: [CaptureRequest] = []
    @State private var selectedCapture: CaptureRequest?
    @State private var filterText = ""
    @State private var timer: Timer?
    @State private var autoRefresh = true
    
    var filteredCaptures: [CaptureRequest] {
        if filterText.isEmpty {
            return captures.sorted { $0.timestamp > $1.timestamp }
        }
        return captures.filter {
            $0.url.localizedCaseInsensitiveContains(filterText) ||
            $0.method.localizedCaseInsensitiveContains(filterText) ||
            $0.rule.localizedCaseInsensitiveContains(filterText)
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Capture")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Toggle("Auto Refresh", isOn: $autoRefresh)
                    .toggleStyle(.switch)
                    .onChange(of: autoRefresh) { enable in
                       if enable { startTimer() } else { stopTimer() }
                    }
                
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()
            
            Divider()
            
            HSplitView {
                // Capture list
                VStack(spacing: 0) {
                    // Filter
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Filter URL, Method, Rule...", text: $filterText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    if captures.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "network")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No Captured Requests")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List(filteredCaptures, selection: $selectedCapture) { capture in
                            CaptureListItem(capture: capture)
                        }
                        .listStyle(.sidebar)
                    }
                }
                .frame(minWidth: 300)
                
                // Detail view
                if let capture = selectedCapture {
                    CaptureDetailView(capture: capture)
                } else {
                    VStack {
                        Text("Select a request to view details")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        refresh()
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            refresh()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refresh() {
        Task {
            do {
                let items = try await APIClient.shared.fetchCapture()
                await MainActor.run {
                    self.captures = items
                }
            } catch {
                print("Capture fetch error: \(error)")
            }
        }
    }
}

struct CaptureListItem: View {
    let capture: CaptureRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(capture.method)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(methodColor)
                    .cornerRadius(4)
                
                Text("\(capture.status)")
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(formatTime(capture.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(capture.url)
                .font(.caption)
                .lineLimit(1)
            
            HStack {
                Text(capture.policy)
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(capture.rule)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var methodColor: Color {
        switch capture.method {
        case "GET": return .blue
        case "POST": return .green
        case "CONNECT": return .purple
        case "TCP": return .purple
        case "UDP": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
    
    private var statusColor: Color {
        if capture.status == 0 { return .secondary } // Unknown/TCP
        if capture.status < 300 { return .green }
        if capture.status < 400 { return .orange }
        return .red
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct CaptureDetailView: View {
    let capture: CaptureRequest
    
    var body: some View {
        VStack(spacing: 0) {
            // URL header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(capture.url)
                        .font(.headline)
                        .textSelection(.enabled)
                    HStack {
                        Text(capture.method)
                        Text("•")
                        Text("\(capture.status)")
                        Text("•")
                        Text(String(format: "%.2fs", capture.duration))
                        Text("•")
                        Text(formatBytes(capture.uploadBytes) + " / " + formatBytes(capture.downloadBytes))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Detail List
            List {
                Section("General") {
                    LabeledContent("ID", value: capture.id)
                    LabeledContent("Timestamp", value: capture.timestamp.description)
                    LabeledContent("Source IP", value: capture.sourceIP)
                    LabeledContent("Policy", value: capture.policy)
                    LabeledContent("Rule", value: capture.rule)
                }
                
                if !capture.notes.isEmpty {
                    Section("Notes") {
                        Text(capture.notes)
                    }
                }
                
                Section("Traffic") {
                    LabeledContent("Upload", value: formatBytes(capture.uploadBytes))
                    LabeledContent("Download", value: formatBytes(capture.downloadBytes))
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}
