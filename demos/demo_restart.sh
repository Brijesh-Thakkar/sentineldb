#!/usr/bin/env bash
set -e

echo "========================================="
echo "  SentinelDB Restart Demo: Policy Persistence"
echo "========================================="
echo ""

BASE_URL="http://localhost:8080"
SERVER_BIN="./build/http_server"

echo "📋 This demo verifies that decision policies persist across server restarts."
echo ""

# Check if server binary exists
if [ ! -f "$SERVER_BIN" ]; then
    echo "❌ Error: $SERVER_BIN not found. Please build the project first:"
    echo "   cmake -S . -B build && cmake --build build"
    exit 1
fi

# Check if server is already running
if curl -s "$BASE_URL/policy" > /dev/null 2>&1; then
    echo "⚠️  HTTP server is already running. Stopping it first..."
    pkill -f "http_server" || true
    sleep 1
fi

echo "---[ STEP 1: Start HTTP Server ]---"
echo "Starting server in background..."
"$SERVER_BIN" --port 8080 > /tmp/sentineldb_demo.log 2>&1 &
SERVER_PID=$!
echo "Server PID: $SERVER_PID"
sleep 2

# Verify server started
if ! curl -s "$BASE_URL/policy" > /dev/null 2>&1; then
    echo "❌ Failed to start server"
    cat /tmp/sentineldb_demo.log
    exit 1
fi
echo "✓ Server running"
echo ""

echo "---[ STEP 2: Check Initial Policy ]---"
echo "GET /policy"
INITIAL_POLICY=$(curl -s "$BASE_URL/policy" | grep -o '"policy":"[^"]*"' | cut -d'"' -f4)
echo "Current policy: $INITIAL_POLICY"
echo ""

echo "---[ STEP 3: Change Policy to STRICT ]---"
echo "POST /policy {\"policy\":\"STRICT\"}"
curl -s -X POST "$BASE_URL/policy" \
    -H "Content-Type: application/json" \
    -d '{"policy":"STRICT"}'
echo ""
sleep 1

echo "Verifying change..."
NEW_POLICY=$(curl -s "$BASE_URL/policy" | grep -o '"policy":"[^"]*"' | cut -d'"' -f4)
echo "Policy now: $NEW_POLICY"
echo ""

if [ "$NEW_POLICY" != "STRICT" ]; then
    echo "❌ Policy change failed"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo "---[ STEP 4: Stop Server ]---"
echo "Killing server process $SERVER_PID..."
kill $SERVER_PID 2>/dev/null || true
sleep 2
echo "✓ Server stopped"
echo ""

echo "---[ STEP 5: Restart Server ]---"
echo "Starting server again..."
"$SERVER_BIN" --port 8080 > /tmp/sentineldb_demo.log 2>&1 &
SERVER_PID=$!
echo "Server PID: $SERVER_PID"
sleep 2

# Verify server started
if ! curl -s "$BASE_URL/policy" > /dev/null 2>&1; then
    echo "❌ Failed to restart server"
    cat /tmp/sentineldb_demo.log
    exit 1
fi
echo "✓ Server running"
echo ""

echo "---[ STEP 6: Verify Policy Persisted ]---"
echo "GET /policy (after restart)"
RESTORED_POLICY=$(curl -s "$BASE_URL/policy" | grep -o '"policy":"[^"]*"' | cut -d'"' -f4)
echo "Policy after restart: $RESTORED_POLICY"
echo ""

# Cleanup
echo "---[ Cleanup ]---"
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null || true
sleep 1
echo "✓ Done"
echo ""

# Final verdict
echo "========================================="
if [ "$RESTORED_POLICY" = "STRICT" ]; then
    echo "✅ Policy persistence verified!"
    echo ""
    echo "Result:"
    echo "  Before restart: STRICT"
    echo "  After restart:  STRICT"
    echo ""
    echo "Policy changes are persisted via WAL and survive restarts."
else
    echo "❌ Policy persistence failed!"
    echo ""
    echo "Expected: STRICT"
    echo "Got:      $RESTORED_POLICY"
    exit 1
fi
echo "========================================="
echo ""
