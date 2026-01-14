#!/usr/bin/env python3
"""
Test client for the proxy server
Tests basic HTTP and HTTPS proxying functionality
"""

import socket
import ssl
import sys

def test_http_proxy(proxy_host='127.0.0.1', proxy_port=8888):
    """Test HTTP proxying"""
    print("Testing HTTP proxy...")
    
    try:
        # Create connection to proxy
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((proxy_host, proxy_port))
        
        # Send HTTP request through proxy
        request = (
            "GET http://example.com/ HTTP/1.1\r\n"
            "Host: example.com\r\n"
            "Connection: close\r\n"
            "\r\n"
        )
        sock.send(request.encode())
        
        # Receive response
        response = b""
        while True:
            data = sock.recv(4096)
            if not data:
                break
            response += data
        
        sock.close()
        
        # Check if we got a valid response
        if b"HTTP/" in response and b"200" in response:
            print("✓ HTTP proxy test passed")
            print(f"  Response size: {len(response)} bytes")
            return True
        else:
            print("✗ HTTP proxy test failed")
            print(f"  Response: {response[:200]}")
            return False
            
    except Exception as e:
        print(f"✗ HTTP proxy test failed with error: {e}")
        return False


def test_https_proxy(proxy_host='127.0.0.1', proxy_port=8888):
    """Test HTTPS proxying using CONNECT method"""
    print("\nTesting HTTPS proxy...")
    
    try:
        # Create connection to proxy
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((proxy_host, proxy_port))
        
        # Send CONNECT request
        connect_request = (
            "CONNECT example.com:443 HTTP/1.1\r\n"
            "Host: example.com:443\r\n"
            "\r\n"
        )
        sock.send(connect_request.encode())
        
        # Receive CONNECT response
        response = sock.recv(4096)
        
        if b"200 Connection Established" not in response:
            print("✗ HTTPS proxy test failed: CONNECT not established")
            print(f"  Response: {response}")
            sock.close()
            return False
        
        # Wrap socket with SSL (use secure TLS version)
        context = ssl.create_default_context()
        context.minimum_version = ssl.TLSVersion.TLSv1_2  # Enforce TLS 1.2 or higher
        ssl_sock = context.wrap_socket(sock, server_hostname='example.com')
        
        # Send HTTP request over SSL
        request = (
            "GET / HTTP/1.1\r\n"
            "Host: example.com\r\n"
            "Connection: close\r\n"
            "\r\n"
        )
        ssl_sock.send(request.encode())
        
        # Receive response
        response = b""
        while True:
            try:
                data = ssl_sock.recv(4096)
                if not data:
                    break
                response += data
            except Exception:
                break
        
        ssl_sock.close()
        
        # Check if we got a valid response
        if b"HTTP/" in response and b"200" in response:
            print("✓ HTTPS proxy test passed")
            print(f"  Response size: {len(response)} bytes")
            return True
        else:
            print("✗ HTTPS proxy test failed")
            print(f"  Response: {response[:200]}")
            return False
            
    except Exception as e:
        print(f"✗ HTTPS proxy test failed with error: {e}")
        return False


def main():
    """Run all tests"""
    print("=" * 50)
    print("Proxy Server Test Suite")
    print("=" * 50)
    print()
    
    # Get proxy settings from command line or use defaults
    proxy_host = sys.argv[1] if len(sys.argv) > 1 else '127.0.0.1'
    proxy_port = int(sys.argv[2]) if len(sys.argv) > 2 else 8888
    
    print(f"Testing proxy at {proxy_host}:{proxy_port}")
    print()
    
    # Run tests
    http_passed = test_http_proxy(proxy_host, proxy_port)
    https_passed = test_https_proxy(proxy_host, proxy_port)
    
    # Summary
    print()
    print("=" * 50)
    print("Test Summary")
    print("=" * 50)
    print(f"HTTP Proxy:  {'PASS' if http_passed else 'FAIL'}")
    print(f"HTTPS Proxy: {'PASS' if https_passed else 'FAIL'}")
    print()
    
    if http_passed and https_passed:
        print("All tests passed! ✓")
        return 0
    else:
        print("Some tests failed. ✗")
        return 1


if __name__ == "__main__":
    sys.exit(main())
