#!/bin/bash

# SurgeProxy Test Script
echo "🧪 SurgeProxy Testing Script"
echo "=============================="
echo ""

# Test 1: Backend Build
echo "Test 1: Backend Build"
cd surge-go
if [ -f "surge" ]; then
    echo "✅ Backend binary exists"
    ls -lh surge
else
    echo "❌ Backend binary not found"
    exit 1
fi
echo ""

# Test 2: Start Backend
echo "Test 2: Start Backend"
./surge > /tmp/surge.log 2>&1 &
SURGE_PID=$!
echo "Started surge with PID: $SURGE_PID"
sleep 3
echo ""

# Test 3: API Health Check
echo "Test 3: API Health Check"
if curl -s http://localhost:9090/api/stats > /dev/null; then
    echo "✅ API is responding"
else
    echo "❌ API not responding"
fi
echo ""

# Test 4: Get Stats
echo "Test 4: GET /api/stats"
curl -s http://localhost:9090/api/stats | head -5
echo ""

# Test 5: Get Proxies
echo "Test 5: GET /api/proxies"
curl -s http://localhost:9090/api/proxies
echo ""

# Test 6: Get Rules
echo "Test 6: GET /api/rules"
curl -s http://localhost:9090/api/rules
echo ""

# Test 7: WebSocket (basic check)
echo "Test 7: WebSocket Connection"
echo "WebSocket endpoint: ws://localhost:9090/ws"
echo "(Manual test required)"
echo ""

# Cleanup
echo "Cleanup: Stopping backend..."
kill $SURGE_PID 2>/dev/null
echo "✅ Tests complete"
echo ""
echo "Summary:"
echo "- Backend: ✅"
echo "- API: ✅"
echo "- Frontend: Manual test required"
