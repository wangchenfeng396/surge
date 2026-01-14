//
//  RuleMatchView.swift
//  SurgeProxy
//
//  Created for Rule Matching Testing
//

import SwiftUI

struct RuleMatchView: View {
    @State private var url: String = "https://www.google.com"
    @State private var sourceIP: String = "127.0.0.1"
    @State private var processName: String = ""
    @State private var isTesting = false
    @State private var result: APIClient.RuleMatchResponse?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Rule Match Tester")
                .font(.title2)
                .fontWeight(.bold)
            
            Divider()
            
            // Input Form
            Form {
                TextField("URL", text: $url)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Source IP", text: $sourceIP)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Process Name (Optional)", text: $processName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.bottom)
            
            HStack {
                Button(action: testMatch) {
                    if isTesting {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Text("Test Match")
                    }
                }
                .disabled(isTesting || url.isEmpty)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Divider()
            
            // Result Display
            if let res = result {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Match Result")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ResultRow(label: "Rule", value: res.rule)
                    ResultRow(label: "Policy", value: res.policy)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .transition(.opacity)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func testMatch() {
        guard !url.isEmpty else { return }
        
        isTesting = true
        errorMessage = nil
        result = nil
        
        Task {
            do {
                let res = try await APIClient.shared.matchRule(url: url, sourceIP: sourceIP, process: processName)
                await MainActor.run {
                    self.result = res
                    self.isTesting = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Match failed: \(error.localizedDescription)"
                    self.isTesting = false
                }
            }
        }
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}
