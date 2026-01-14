#!/usr/bin/env python3
"""
Surge-like Proxy Server
A simple HTTP/HTTPS proxy server with configuration support
"""

import socket
import select
import threading
import logging
from typing import Optional, Dict, List
import json
import re
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ProxyConfig:
    """Configuration management for the proxy server"""
    
    def __init__(self, config_file: str = "config.json"):
        self.config_file = config_file
        self.port = 8888
        self.host = "0.0.0.0"
        self.buffer_size = 8192
        self.timeout = 30
        self.blocked_domains: List[str] = []
        self.direct_domains: List[str] = []
        self.rules: List[Dict] = []
        self.load_config()
    
    def load_config(self):
        """Load configuration from file"""
        try:
            if Path(self.config_file).exists():
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    self.port = config.get('port', self.port)
                    self.host = config.get('host', self.host)
                    self.buffer_size = config.get('buffer_size', self.buffer_size)
                    self.timeout = config.get('timeout', self.timeout)
                    self.blocked_domains = config.get('blocked_domains', [])
                    self.direct_domains = config.get('direct_domains', [])
                    self.rules = config.get('rules', [])
                    logger.info(f"Configuration loaded from {self.config_file}")
            else:
                logger.warning(f"Config file {self.config_file} not found, using defaults")
        except Exception as e:
            logger.error(f"Error loading config: {e}")
    
    def is_blocked(self, host: str) -> bool:
        """Check if a domain is blocked"""
        for domain in self.blocked_domains:
            if domain in host:
                return True
        return False
    
    def should_proxy(self, host: str) -> bool:
        """Check if a domain should be proxied"""
        for domain in self.direct_domains:
            if domain in host:
                return False
        return True


class ProxyServer:
    """Main proxy server implementation"""
    
    def __init__(self, config: ProxyConfig):
        self.config = config
        self.server_socket: Optional[socket.socket] = None
        self.running = False
    
    def start(self):
        """Start the proxy server"""
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.bind((self.config.host, self.config.port))
            self.server_socket.listen(100)
            self.running = True
            
            logger.info(f"Proxy server started on {self.config.host}:{self.config.port}")
            
            while self.running:
                try:
                    client_socket, client_address = self.server_socket.accept()
                    client_thread = threading.Thread(
                        target=self.handle_client,
                        args=(client_socket, client_address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                except KeyboardInterrupt:
                    logger.info("Shutting down server...")
                    break
                except Exception as e:
                    logger.error(f"Error accepting connection: {e}")
        
        finally:
            self.stop()
    
    def stop(self):
        """Stop the proxy server"""
        self.running = False
        if self.server_socket:
            self.server_socket.close()
        logger.info("Proxy server stopped")
    
    def handle_client(self, client_socket: socket.socket, client_address):
        """Handle a client connection"""
        try:
            # Receive the request
            request = client_socket.recv(self.config.buffer_size)
            if not request:
                return
            
            # Parse the request
            first_line = request.split(b'\n')[0]
            url = first_line.split(b' ')[1] if len(first_line.split(b' ')) > 1 else b''
            
            # Extract method and host
            method = first_line.split(b' ')[0].decode('utf-8', errors='ignore')
            
            # Handle CONNECT method (HTTPS)
            if method == 'CONNECT':
                self.handle_https(client_socket, request)
            else:
                self.handle_http(client_socket, request, url)
        
        except Exception as e:
            logger.error(f"Error handling client {client_address}: {e}")
        finally:
            client_socket.close()
    
    def handle_http(self, client_socket: socket.socket, request: bytes, url: bytes):
        """Handle HTTP request"""
        try:
            # Parse host and port
            host, port = self.parse_host_port(request, default_port=80)
            
            if not host:
                logger.error("Could not parse host from request")
                return
            
            # Check if blocked
            if self.config.is_blocked(host):
                logger.info(f"Blocked request to {host}")
                client_socket.send(b"HTTP/1.1 403 Forbidden\r\n\r\n")
                return
            
            logger.info(f"HTTP: {host}:{port}")
            
            # Connect to remote server
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.settimeout(self.config.timeout)
            remote_socket.connect((host, port))
            
            # Send request to remote server
            remote_socket.send(request)
            
            # Forward data between client and remote server
            self.forward_data(client_socket, remote_socket)
            
        except Exception as e:
            logger.error(f"HTTP error: {e}")
    
    def handle_https(self, client_socket: socket.socket, request: bytes):
        """Handle HTTPS CONNECT request"""
        try:
            # Parse host and port
            host, port = self.parse_host_port(request, default_port=443)
            
            if not host:
                logger.error("Could not parse host from CONNECT request")
                return
            
            # Check if blocked
            if self.config.is_blocked(host):
                logger.info(f"Blocked HTTPS request to {host}")
                client_socket.send(b"HTTP/1.1 403 Forbidden\r\n\r\n")
                return
            
            logger.info(f"HTTPS: {host}:{port}")
            
            # Connect to remote server
            remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_socket.settimeout(self.config.timeout)
            remote_socket.connect((host, port))
            
            # Send connection established response
            client_socket.send(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            
            # Forward data between client and remote server
            self.forward_data(client_socket, remote_socket)
            
        except Exception as e:
            logger.error(f"HTTPS error: {e}")
    
    def parse_host_port(self, request: bytes, default_port: int = 80) -> tuple:
        """Parse host and port from request"""
        try:
            lines = request.split(b'\r\n')
            first_line = lines[0].decode('utf-8', errors='ignore')
            
            # For CONNECT method
            if first_line.startswith('CONNECT'):
                host_port = first_line.split(' ')[1]
                if ':' in host_port:
                    host, port = host_port.rsplit(':', 1)
                    return host, int(port)
                return host_port, default_port
            
            # For other methods, look for Host header
            for line in lines[1:]:
                if line.startswith(b'Host:'):
                    host_line = line.decode('utf-8', errors='ignore')
                    host_value = host_line.split(':', 1)[1].strip()
                    if ':' in host_value:
                        host, port = host_value.rsplit(':', 1)
                        return host, int(port)
                    return host_value, default_port
            
            return None, default_port
        except Exception as e:
            logger.error(f"Error parsing host/port: {e}")
            return None, default_port
    
    def forward_data(self, client_socket: socket.socket, remote_socket: socket.socket):
        """Forward data between client and remote server"""
        try:
            sockets = [client_socket, remote_socket]
            timeout_count = 0
            
            while True:
                # Increment timeout counter only when no data is received
                timeout_count += 1
                if timeout_count > 60:
                    break
                
                receive_ready, _, error_ready = select.select(sockets, [], sockets, 1)
                
                if error_ready:
                    break
                
                if receive_ready:
                    for sock in receive_ready:
                        try:
                            data = sock.recv(self.config.buffer_size)
                            if not data:
                                return
                            
                            if sock is client_socket:
                                remote_socket.send(data)
                            else:
                                client_socket.send(data)
                            
                            # Reset timeout counter when data is received
                            timeout_count = 0
                        except Exception as e:
                            logger.debug(f"Error receiving/sending data: {e}")
                            return
        except Exception as e:
            logger.error(f"Error forwarding data: {e}")
        finally:
            try:
                remote_socket.close()
            except Exception as e:
                logger.debug(f"Error closing remote socket: {e}")


def main():
    """Main entry point"""
    config = ProxyConfig()
    server = ProxyServer(config)
    
    try:
        server.start()
    except KeyboardInterrupt:
        logger.info("Server interrupted by user")
    except Exception as e:
        logger.error(f"Server error: {e}")


if __name__ == "__main__":
    main()
