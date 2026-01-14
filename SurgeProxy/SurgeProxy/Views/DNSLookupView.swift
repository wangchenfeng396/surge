//
//  DNSLookupView.swift
//  SurgeProxy
//
//  Created for DNS Testing
//

import SwiftUI

struct DNSLookupView: View {
    @State private var host: String = "www.google.com"
    @State private var isLookup = false
    @State private var result: APIClient.DNSQueryResult?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DNS Lookup Tool")
                .font(.title2)
                .fontWeight(.bold)
            
            Divider()
            
            // Input Form
            HStack {
                TextField("Hostname", text: $host)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        lookup()
                    }
                
                Button(action: lookup) {
                    if isLookup {
                        ProgressView().scaleEffect(0.5)
                    } else {
                        Text("Lookup")
                    }
                }
                .disabled(isLookup || host.isEmpty)
            }
            .padding(.bottom)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Divider()
            
            // Result Display
            if let res = result {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result for: \(res.host)")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    if let ips = res.ips, !ips.isEmpty {
                        ForEach(ips, id: \.self) { ip in
                             HStack {
                                Image(systemName: "network")
                                    .foregroundColor(.blue)
                                Text(ip)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                            }
                        }
                    } else if let err = res.error {
                        Text("Error: \(err)")
                            .foregroundColor(.red)
                    } else {
                        Text("No records found.")
                            .foregroundColor(.secondary)
                    }
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
    
    private func lookup() {
        guard !host.isEmpty else { return }
        
        isLookup = true
        errorMessage = nil
        result = nil
        
        Task {
            do {
                let res = try await APIClient.shared.dnsQuery(host: host)
                await MainActor.run {
                    self.result = res
                    self.isLookup = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Lookup failed: \(error.localizedDescription)"
                    self.isLookup = false
                }
            }
        }
    }
}
