#!/usr/bin/env python3
"""
Demo script to show proxy functionality
Since the environment may not have external network access,
this script demonstrates the proxy server's capabilities
"""

import socket
import threading
import time
import sys

def mock_http_server(port=9000):
    """Run a simple HTTP server for testing"""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', port))
    server.listen(1)
    
    print(f"Mock HTTP server listening on 127.0.0.1:{port}")
    
    while True:
        try:
            client, addr = server.accept()
            request = client.recv(4096)
            
            # Send a simple HTTP response
            response = (
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: text/html\r\n"
                "Content-Length: 38\r\n"
                "\r\n"
                "<html><body>Test OK</body></html>"
            )
            client.send(response.encode())
            client.close()
        except Exception as e:
            print(f"Mock server error: {e}")
            break


def test_proxy_with_mock():
    """Test proxy with mock server"""
    print("\n" + "="*60)
    print("Surge Proxy Server - Functionality Demo")
    print("="*60)
    
    # Start mock server in background
    print("\n1. Starting mock HTTP server on port 9000...")
    server_thread = threading.Thread(target=mock_http_server, daemon=True)
    server_thread.start()
    time.sleep(1)
    
    # Test connection through proxy
    print("2. Testing proxy server connection...")
    try:
        # Connect to proxy
        proxy_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        proxy_socket.connect(('127.0.0.1', 8888))
        print("   ✓ Connected to proxy server on 127.0.0.1:8888")
        
        # Send HTTP request through proxy
        request = (
            "GET http://127.0.0.1:9000/ HTTP/1.1\r\n"
            "Host: 127.0.0.1:9000\r\n"
            "Connection: close\r\n"
            "\r\n"
        )
        proxy_socket.send(request.encode())
        print("   ✓ Sent HTTP request through proxy")
        
        # Receive response
        response = proxy_socket.recv(4096)
        proxy_socket.close()
        
        if b"200 OK" in response and b"Test OK" in response:
            print("   ✓ Received valid HTTP response through proxy")
            print("\n3. Response received:")
            print("   " + "-"*56)
            for line in response.decode().split('\r\n')[:5]:
                print("   " + line)
            print("   " + "-"*56)
            print("\n✅ SUCCESS: Proxy server is working correctly!")
            print("\nThe proxy server can:")
            print("  • Accept HTTP connections")
            print("  • Parse HTTP requests")
            print("  • Forward requests to target servers")
            print("  • Return responses to clients")
            return True
        else:
            print("   ✗ Invalid response received")
            return False
            
    except Exception as e:
        print(f"   ✗ Test failed: {e}")
        return False


def show_capabilities():
    """Show what the proxy server supports"""
    print("\n" + "="*60)
    print("Proxy Server Capabilities")
    print("="*60)
    print("""
✓ HTTP Proxy Support
  - Standard HTTP/1.1 proxy protocol
  - Request/response forwarding
  - Connection management

✓ HTTPS Proxy Support  
  - CONNECT method tunneling
  - Encrypted traffic forwarding
  - TLS/SSL passthrough

✓ Configuration System
  - JSON-based configuration
  - Port and host settings
  - Buffer size and timeout control

✓ Domain Filtering
  - Blocked domains list
  - Direct connection domains
  - Custom routing rules

✓ Logging & Monitoring
  - Request logging
  - Error tracking
  - Connection status

✓ Multi-threaded Architecture
  - Concurrent connection handling
  - Non-blocking I/O with select()
  - Efficient resource management
""")


if __name__ == "__main__":
    # Check if proxy is running
    try:
        test_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        test_sock.settimeout(1)
        test_sock.connect(('127.0.0.1', 8888))
        test_sock.close()
        print("Proxy server detected on port 8888")
    except:
        print("ERROR: Proxy server not running on port 8888")
        print("Please start the proxy server first:")
        print("  python3 proxy_server.py")
        sys.exit(1)
    
    # Run tests
    success = test_proxy_with_mock()
    show_capabilities()
    
    print("\n" + "="*60)
    if success:
        print("Demo completed successfully! ✓")
    else:
        print("Demo encountered issues.")
    print("="*60 + "\n")
    
    sys.exit(0 if success else 1)
