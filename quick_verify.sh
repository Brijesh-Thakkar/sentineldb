# Quick Test: Verify All Requirements

echo "Testing: POLICY SET STRICT -> Restart -> POLICY GET"
rm -f data/wal.log data/snapshot.db

cat > /tmp/quick1.txt << 'EOF'
POLICY SET STRICT
EXIT
EOF

./build/redis_db < /tmp/quick1.txt 2>&1 > /dev/null

cat > /tmp/quick2.txt << 'EOF'
POLICY GET
EXIT
EOF

OUTPUT=$(./build/redis_db < /tmp/quick2.txt 2>&1)

if echo "$OUTPUT" | grep -q "STRICT"; then
    echo "✓ CLI Persistence: PASSED"
else
    echo "✗ CLI Persistence: FAILED"
    exit 1
fi

# HTTP Test
rm -f data/wal.log
./build/http_server --port 8891 --wal data/wal.log > /dev/null 2>&1 &
HTTP_PID=$!
sleep 2

curl -s -X POST http://localhost:8891/policy \
    -H "Content-Type: application/json" \
    -d '{"policy":"STRICT"}' > /dev/null

kill $HTTP_PID 2>/dev/null
sleep 1

./build/http_server --port 8891 --wal data/wal.log > /dev/null 2>&1 &
HTTP_PID=$!
sleep 2

RESPONSE=$(curl -s http://localhost:8891/policy)
kill $HTTP_PID 2>/dev/null

if echo "$RESPONSE" | grep -q "STRICT"; then
    echo "✓ HTTP Persistence: PASSED"
else
    echo "✗ HTTP Persistence: FAILED"
    exit 1
fi

rm -f /tmp/quick*.txt

echo ""
echo "✅ All requirements working!"
echo ""
echo "The following has been verified:"
echo "  • POLICY SET STRICT"
echo "  • Process restart"
echo "  • POLICY GET → STRICT"
echo "  • HTTP POST /policy"
echo "  • HTTP GET /policy (after restart)"
echo ""
echo "Implementation complete!"
