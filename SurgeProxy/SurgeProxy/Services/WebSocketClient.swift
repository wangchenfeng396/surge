//
//  WebSocketClient.swift
//  SurgeProxy
//
//  WebSocket client for real-time updates from Go backend
//

import Foundation
import Combine

class WebSocketClient: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var latestStats: NetworkStats?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var url = URL(string: "ws://localhost:19090/ws")! // Default
    
    func setPort(_ port: Int) {
        self.url = URL(string: "ws://localhost:\(port)/ws")!
        print("WebSocketClient configured to use port: \(port)")
    }
    
    private var reconnectTimer: Timer?
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard webSocketTask == nil else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
        }
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("Max reconnect attempts reached")
            return
        }
        
        reconnectAttempts += 1
        print("Reconnecting... attempt \(reconnectAttempts)")
        
        disconnect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(reconnectAttempts)) {
            self.connect()
        }
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue receiving
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleDisconnection()
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseStatsUpdate(text)
            
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseStatsUpdate(text)
            }
            
        @unknown default:
            break
        }
    }
    
    private func parseStatsUpdate(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let stats = try decoder.decode(NetworkStats.self, from: data)
            DispatchQueue.main.async {
                self.latestStats = stats
            }
        } catch {
            print("Failed to decode stats: \(error)")
        }
    }
    
    private func handleDisconnection() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.reconnect()
        }
    }
    
    // MARK: - Send Messages
    
    func send(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
        }
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        print("WebSocket disconnected")
        handleDisconnection()
    }
}
