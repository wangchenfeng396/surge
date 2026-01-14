//
//  ProxyTestManager.swift
//  SurgeProxy
//
//  Manager for testing proxy servers
//

import Foundation

class ProxyTestManager: ObservableObject {
    let apiBaseURL = "http://localhost:9090"
    
    // Test HTTP proxy
    func testHTTPProxy(proxyURL: String, testURL: String, completion: @escaping (Result<TestResult, Error>) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)/api/test/http") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["proxy_url": proxyURL, "test_url": testURL]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let result = try JSONDecoder().decode(TestResult.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Test SOCKS5 proxy
    func testSOCKS5Proxy(proxyAddr: String, testHost: String, testPort: Int, completion: @escaping (Result<TestResult, Error>) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)/api/test/socks5") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["proxy_addr": proxyAddr, "test_host": testHost, "test_port": testPort] as [String : Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let result = try JSONDecoder().decode(TestResult.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Test direct connection
    func testDirect(testURL: String, completion: @escaping (Result<TestResult, Error>) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)/api/test/direct") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["test_url": testURL]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let result = try JSONDecoder().decode(TestResult.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

struct TestResult: Codable {
    let success: Bool
    let latency: Int
    let error: String?
}
