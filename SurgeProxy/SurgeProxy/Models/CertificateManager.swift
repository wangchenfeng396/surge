//
//  CertificateManager.swift
//  SurgeProxy
//
//  MITM certificate generation and management
//

import Foundation
import Security

class CertificateManager: ObservableObject {
    @Published var certificateName = "Surge Generated CA"
    @Published var isTrusted = false
    @Published var serialNumber = ""
    @Published var validUntil: Date?
    
    init() {
        checkCertificate()
    }
    
    // Check if certificate exists and is trusted
    func checkCertificate() {
        // TODO: Implement actual certificate checking
        certificateName = "Surge Generated CA 16D9BC67"
        serialNumber = "16D9BC67"
        validUntil = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        isTrusted = false
    }
    
    // Generate new certificate
    func generateCertificate(completion: @escaping (Result<String, Error>) -> Void) {
        // This would use Security framework to generate a self-signed certificate
        // For now, simulate the process
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            let newSerial = String(format: "%08X", Int.random(in: 0...0xFFFFFFFF))
            
            DispatchQueue.main.async {
                self.serialNumber = newSerial
                self.certificateName = "Surge Generated CA \(newSerial)"
                self.validUntil = Calendar.current.date(byAdding: .year, value: 1, to: Date())
                completion(.success(newSerial))
            }
        }
    }
    
    // Install certificate to system keychain
    func installToSystem(completion: @escaping (Result<Void, Error>) -> Void) {
        // This would use security command or Security framework
        // security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain cert.pem
        
        let script = """
        osascript -e 'do shell script "echo Installing certificate..." with administrator privileges'
        """
        
        executeShellCommand(script) { result in
            switch result {
            case .success:
                self.isTrusted = true
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Export certificate for iOS Simulator
    func exportForSimulator(to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        // Export certificate in PEM format
        let certData = generatePEMCertificate()
        
        do {
            try certData.write(to: url)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // Import certificate from PKCS#12 file
    func importFromPKCS12(from url: URL, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            // TODO: Parse PKCS#12 file using Security framework
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // Helper: Generate PEM certificate
    private func generatePEMCertificate() -> Data {
        let pem = """
        -----BEGIN CERTIFICATE-----
        MIIDXTCCAkWgAwIBAgIJAKL0hKvN7NQZMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
        BAYTAkNOMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
        aWRnaXRzIFB0eSBMdGQwHhcNMjYwMTExMDAwMDAwWhcNMjcwMTExMDAwMDAwWjBF
        MQswCQYDVQQGEwJDTjETMBEGA1UECAwKU29tZS1TdGF0ZTEhMB8GA1UECgwYSW50
        ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
        CgKCAQEA0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z0Z
        -----END CERTIFICATE-----
        """
        return pem.data(using: .utf8) ?? Data()
    }
    
    // Helper: Execute shell command
    private func executeShellCommand(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if task.terminationStatus == 0 {
            completion(.success(output))
        } else {
            completion(.failure(NSError(domain: "ShellError", code: Int(task.terminationStatus))))
        }
    }
}
