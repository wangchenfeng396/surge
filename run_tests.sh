#!/bin/bash

# SurgeProxy Comprehensive Automated Test Suite
# Based on testing_report.md

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result function
test_result() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo "╔════════════════════════════════════════════════════════╗"
echo "║     SurgeProxy Automated Test Suite v1.0              ║"
echo "║     Date: $(date '+%Y-%m-%d %H:%M:%S')                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ============================================================
# SECTION 1: BUILD TESTS
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECTION 1: BUILD TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 1.1: Backend binary exists
if [ -f "surge-go/surge" ]; then
    test_result 0 "Backend binary exists"
else
    test_result 1 "Backend binary exists"
fi

# Test 1.2: Backend binary is executable
if [ -x "surge-go/surge" ]; then
    test_result 0 "Backend binary is executable"
else
    test_result 1 "Backend binary is executable"
fi

# Test 1.3: Universal binary check
ARCH_COUNT=$(lipo -info surge-go/surge 2>/dev/null | grep -c "architecture" || echo "0")
if [ "$ARCH_COUNT" -ge 2 ]; then
    test_result 0 "Universal binary (x86_64 + arm64)"
else
    test_result 1 "Universal binary (x86_64 + arm64)"
fi

# Test 1.4: Frontend app exists
if [ -d "SurgeProxy/build/Debug/SurgeProxy.app" ] || [ -d "$HOME/Library/Developer/Xcode/DerivedData/SurgeProxy-*/Build/Products/Debug/SurgeProxy.app" ]; then
    test_result 0 "Frontend app bundle exists"
else
    test_result 1 "Frontend app bundle exists"
fi

echo ""

# ============================================================
# SECTION 2: BACKEND API TESTS
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECTION 2: BACKEND API TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start backend
echo "Starting backend..."
cd surge-go
./surge > /tmp/surge_test.log 2>&1 &
SURGE_PID=$!
cd ..
sleep 3

# Test 2.1: Backend process running
if ps -p $SURGE_PID > /dev/null; then
    test_result 0 "Backend process started (PID: $SURGE_PID)"
else
    test_result 1 "Backend process started"
fi

# Test 2.2: API port listening
if lsof -i :9090 > /dev/null 2>&1; then
    test_result 0 "API server listening on port 9090"
else
    test_result 1 "API server listening on port 9090"
fi

# Test 2.3: GET /api/stats
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/stats)
if [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "GET /api/stats returns 200"
else
    test_result 1 "GET /api/stats returns 200 (got $HTTP_CODE)"
fi

# Test 2.4: GET /api/proxies
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/proxies)
if [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "GET /api/proxies returns 200"
else
    test_result 1 "GET /api/proxies returns 200 (got $HTTP_CODE)"
fi

# Test 2.5: GET /api/rules
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/rules)
if [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "GET /api/rules returns 200"
else
    test_result 1 "GET /api/rules returns 200 (got $HTTP_CODE)"
fi

# Test 2.6: Stats response format
STATS_JSON=$(curl -s http://localhost:9090/api/stats)
if echo "$STATS_JSON" | jq -e '.upload' > /dev/null 2>&1; then
    test_result 0 "Stats JSON contains 'upload' field"
else
    test_result 1 "Stats JSON contains 'upload' field"
fi

if echo "$STATS_JSON" | jq -e '.download' > /dev/null 2>&1; then
    test_result 0 "Stats JSON contains 'download' field"
else
    test_result 1 "Stats JSON contains 'download' field"
fi

if echo "$STATS_JSON" | jq -e '.connections' > /dev/null 2>&1; then
    test_result 0 "Stats JSON contains 'connections' field"
else
    test_result 1 "Stats JSON contains 'connections' field"
fi

# Test 2.7: Proxies response format
PROXIES_JSON=$(curl -s http://localhost:9090/api/proxies)
if echo "$PROXIES_JSON" | jq -e '.proxies' > /dev/null 2>&1; then
    test_result 0 "Proxies JSON contains 'proxies' array"
else
    test_result 1 "Proxies JSON contains 'proxies' array"
fi

# Test 2.8: Rules response format
RULES_JSON=$(curl -s http://localhost:9090/api/rules)
if echo "$RULES_JSON" | jq -e '.rules' > /dev/null 2>&1; then
    test_result 0 "Rules JSON contains 'rules' array"
else
    test_result 1 "Rules JSON contains 'rules' array"
fi

# Test 2.9: POST /api/config
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:9090/api/config \
    -H "Content-Type: application/json" \
    -d '{"config":"[General]\nloglevel = info"}')
if [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "POST /api/config accepts configuration"
else
    test_result 1 "POST /api/config accepts configuration (got $HTTP_CODE)"
fi

# Test 2.10: POST /api/rules
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:9090/api/rules \
    -H "Content-Type: application/json" \
    -d '{"rules":["DOMAIN,google.com,DIRECT","FINAL,PROXY"]}')
if [ "$HTTP_CODE" = "200" ]; then
    test_result 0 "POST /api/rules accepts rules"
else
    test_result 1 "POST /api/rules accepts rules (got $HTTP_CODE)"
fi

echo ""

# ============================================================
# SECTION 3: PERFORMANCE TESTS
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECTION 3: PERFORMANCE TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 3.1: API response time
START_TIME=$(date +%s%N)
curl -s http://localhost:9090/api/stats > /dev/null
END_TIME=$(date +%s%N)
RESPONSE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
if [ $RESPONSE_TIME -lt 100 ]; then
    test_result 0 "API response time < 100ms (${RESPONSE_TIME}ms)"
else
    test_result 1 "API response time < 100ms (${RESPONSE_TIME}ms)"
fi

# Test 3.2: Memory usage
MEM_KB=$(ps -o rss= -p $SURGE_PID)
MEM_MB=$((MEM_KB / 1024))
if [ $MEM_MB -lt 50 ]; then
    test_result 0 "Backend memory usage < 50MB (${MEM_MB}MB)"
else
    test_result 1 "Backend memory usage < 50MB (${MEM_MB}MB)"
fi

# Test 3.3: CPU usage
CPU=$(ps -o %cpu= -p $SURGE_PID | tr -d ' ')
CPU_INT=${CPU%.*}
if [ "$CPU_INT" -lt 5 ]; then
    test_result 0 "Backend CPU usage < 5% (${CPU}%)"
else
    test_result 1 "Backend CPU usage < 5% (${CPU}%)"
fi

echo ""

# ============================================================
# SECTION 4: FILE STRUCTURE TESTS
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SECTION 4: FILE STRUCTURE TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 4.1: Embedded binary in Resources
if [ -f "SurgeProxy/SurgeProxy/Resources/surge" ]; then
    test_result 0 "Embedded binary exists in Resources"
else
    test_result 1 "Embedded binary exists in Resources"
fi

# Test 4.2: UI view files
VIEW_COUNT=$(find SurgeProxy/SurgeProxy/Views -name "*.swift" -type f | wc -l | tr -d ' ')
if [ "$VIEW_COUNT" -ge 20 ]; then
    test_result 0 "UI view files present ($VIEW_COUNT files)"
else
    test_result 1 "UI view files present ($VIEW_COUNT files)"
fi

# Test 4.3: Backend source files
if [ -f "surge-go/internal/singbox/converter.go" ]; then
    test_result 0 "Backend converter.go exists"
else
    test_result 1 "Backend converter.go exists"
fi

if [ -f "surge-go/internal/api/server.go" ]; then
    test_result 0 "Backend server.go exists"
else
    test_result 1 "Backend server.go exists"
fi

echo ""

# ============================================================
# CLEANUP
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLEANUP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Stopping backend (PID: $SURGE_PID)..."
kill $SURGE_PID 2>/dev/null || true
sleep 1
if ps -p $SURGE_PID > /dev/null 2>&1; then
    kill -9 $SURGE_PID 2>/dev/null || true
fi
echo "✅ Backend stopped"
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo "╔════════════════════════════════════════════════════════╗"
echo "║                    TEST SUMMARY                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
echo ""

PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo "Pass Rate:    ${PASS_RATE}%"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 ALL TESTS PASSED! 🎉                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║          ⚠️  SOME TESTS FAILED  ⚠️                     ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
