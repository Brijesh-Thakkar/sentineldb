#!/usr/bin/env bash
set -e

echo "========================================="
echo "  SentinelDB HTTP API Demo"
echo "========================================="
echo ""

BASE_URL="http://localhost:8080"

# Check if server is running
if ! curl -s "$BASE_URL/policy" > /dev/null 2>&1; then
    echo "❌ Error: HTTP server not responding at $BASE_URL"
    echo ""
    echo "Please start the server first:"
    echo "   ./build/http_server --port 8080"
    echo ""
    echo "Or run via Docker:"
    echo "   docker run -p 8080:8080 sentineldb"
    exit 1
fi

echo "📋 This demo shows SentinelDB's HTTP API for policy control and write negotiation."
echo ""

echo "---[ STEP 1: Get Current Policy ]---"
echo "GET /policy"
echo ""
curl -s "$BASE_URL/policy" | grep -o '"policy":"[^"]*"' || curl -s "$BASE_URL/policy"
echo ""
echo ""

echo "---[ STEP 2: Switch to DEV_FRIENDLY Policy ]---"
echo "POST /policy {\"policy\":\"DEV_FRIENDLY\"}"
echo ""
curl -s -X POST "$BASE_URL/policy" \
    -H "Content-Type: application/json" \
    -d '{"policy":"DEV_FRIENDLY"}'
echo ""
echo ""

echo "---[ STEP 3: Verify Policy Changed ]---"
echo "GET /policy"
echo ""
curl -s "$BASE_URL/policy" | grep -o '"policy":"[^"]*"' || curl -s "$BASE_URL/policy"
echo ""
echo ""

echo "---[ STEP 4: Add Guard Constraint ]---"
echo "Adding guard via CLI (guards not yet exposed in HTTP API)"
echo "Guard: temperature* must be in [0, 100]"
echo ""
# Note: This requires the CLI to be available
if [ -f "./build/redis_db" ]; then
    ./build/redis_db <<EOF > /dev/null 2>&1
GUARD ADD temperature* RANGE_INT 0 100
EXIT
EOF
    echo "✓ Guard added"
else
    echo "(Skipped - redis_db not found)"
fi
echo ""

echo "---[ STEP 5: Propose Invalid Write ]---"
echo "POST /propose {\"key\":\"temperature\",\"value\":\"150\"}"
echo "Expected: COUNTER_OFFER (clamped to 100 under DEV_FRIENDLY)"
echo ""
curl -s -X POST "$BASE_URL/propose" \
    -H "Content-Type: application/json" \
    -d '{"key":"temperature","value":"150"}'
echo ""
echo ""

echo "---[ STEP 6: Write Valid Value ]---"
echo "POST /set {\"key\":\"temperature\",\"value\":\"72\"}"
echo ""
curl -s -X POST "$BASE_URL/set" \
    -H "Content-Type: application/json" \
    -d '{"key":"temperature","value":"72"}'
echo ""
echo ""

echo "---[ STEP 7: View Temporal History ]---"
echo "GET /history?key=temperature"
echo ""
curl -s "$BASE_URL/history?key=temperature"
echo ""
echo ""

echo "========================================="
echo "✅ HTTP API demo complete!"
echo "========================================="
echo ""
echo "Available endpoints:"
echo "  • GET  /policy         - View current decision policy"
echo "  • POST /policy         - Change decision policy"
echo "  • POST /set            - Write key-value"
echo "  • GET  /get?key=...    - Read latest value"
echo "  • GET  /history?key=.. - View all versions"
echo "  • POST /propose        - Simulate write (get verdict)"
echo ""
