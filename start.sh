#!/bin/bash
# Start script for the proxy server

echo "Starting Surge Proxy Server..."
echo "================================"
echo ""
echo "Configuration:"
echo "  - Config file: config.json"
echo "  - Default port: 8888"
echo ""
echo "To stop the server, press Ctrl+C"
echo ""

python3 proxy_server.py
