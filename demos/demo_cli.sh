#!/usr/bin/env bash
set -e

echo "========================================="
echo "  SentinelDB CLI Demo: Negotiating Writes"
echo "========================================="
echo ""

# Check if redis_db exists
if [ ! -f "./build/redis_db" ]; then
    echo "❌ Error: ./build/redis_db not found. Please build the project first:"
    echo "   cmake -S . -B build && cmake --build build"
    exit 1
fi

echo "📋 This demo shows how SentinelDB negotiates writes instead of just rejecting them."
echo ""
echo "---[ STEP 1: STRICT Policy ]---"
echo "Under STRICT policy, all guard violations are rejected without negotiation."
echo ""

./build/redis_db <<EOF
POLICY SET STRICT
POLICY GET
EXIT
EOF

echo ""
echo "---[ STEP 2: Add Guard Constraint ]---"
echo "Adding RANGE_INT guard: score* must be between [0, 100]"
echo ""

./build/redis_db <<EOF
GUARD ADD score* RANGE_INT 0 100
EXIT
EOF

echo ""
echo "---[ STEP 3: Propose Invalid Write (STRICT) ]---"
echo "Attempting: PROPOSE SET score 150 (violates guard)"
echo "Expected: REJECT"
echo ""

./build/redis_db <<EOF
PROPOSE SET score 150
EXIT
EOF

echo ""
echo "---[ STEP 4: Switch to DEV_FRIENDLY Policy ]---"
echo "DEV_FRIENDLY policy offers counter-proposals instead of rejecting."
echo ""

./build/redis_db <<EOF
POLICY SET DEV_FRIENDLY
POLICY GET
EXIT
EOF

echo ""
echo "---[ STEP 5: Propose Same Write (DEV_FRIENDLY) ]---"
echo "Attempting: PROPOSE SET score 150 (same violation)"
echo "Expected: COUNTER_OFFER with clamped value (100)"
echo ""

./build/redis_db <<EOF
PROPOSE SET score 150
EXIT
EOF

echo ""
echo "---[ STEP 6: Commit Valid Write ]---"
echo "Writing valid value: SET score 85"
echo ""

./build/redis_db <<EOF
SET score 85
GET score
EXIT
EOF

echo ""
echo "---[ STEP 7: View Temporal History ]---"
echo "Showing all versions of 'score' key:"
echo ""

./build/redis_db <<EOF
HISTORY score
EXIT
EOF

echo ""
echo "========================================="
echo "✅ Demo complete!"
echo "========================================="
echo ""
echo "Key takeaway:"
echo "  • STRICT policy → Hard rejection"
echo "  • DEV_FRIENDLY policy → Counter-proposal"
echo "  • Database negotiates instead of failing"
echo ""
