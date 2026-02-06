# SentinelDB

SentinelDB is a negotiating temporal database that simulates writes, enforces guardrails, and proposes safe alternatives instead of blindly accepting or rejecting data.

## Why SentinelDB Exists

Traditional databases operate in binary mode: accept or reject writes. In practice, this leads to cryptic errors, failed transactions, and frustrated developers debugging constraint violations. SentinelDB introduces a decision layer that evaluates writes before they happen, explains why they would fail, and proposes valid alternatives. Instead of saying "no," the database negotiates.

This approach makes data validation transparent, gives developers actionable feedback, and allows systems to adapt their strictness based on context (development vs production).

## 10-Second Example

**STRICT Policy** - Hard rejection:
```
redis> POLICY SET STRICT
redis> GUARD ADD score* RANGE_INT 0 100
redis> PROPOSE SET score 150

Result: REJECT ✗
Reason: Value 150 outside acceptable range [0, 100]
```

**DEV_FRIENDLY Policy** - Negotiation with alternatives:
```
redis> POLICY SET DEV_FRIENDLY
redis> PROPOSE SET score 150

Result: COUNTER_OFFER ⚠
Reason: Value 150 outside acceptable range [0, 100]

Safe Alternatives:
  1) "100" → Maximum allowed value
  2) "75"  → Conservative midpoint
```

Same constraint. Different policy. Different outcome.

## Key Features

- **Temporal Versioning** - Every key maintains complete version history with timestamps
- **Write-Ahead Logging** - All operations persisted to disk with millisecond timestamps
- **Snapshot-Based Compaction** - Prevent WAL growth while maintaining durability
- **Guard System** - Define constraints (RANGE_INT, ENUM, LENGTH) with pattern matching
- **Proposal-Based Writes** - `PROPOSE SET` simulates writes without committing
- **Decision Policies** - STRICT (reject), SAFE_DEFAULT (negotiate when safe), DEV_FRIENDLY (always help)
- **Policy Persistence** - Decision policies survive restarts via WAL and snapshots
- **Explainable Queries** - `EXPLAIN GET key AT time` shows temporal selection reasoning
- **Configurable Retention** - Control version history (FULL, LAST_N, LAST_T)
- **CLI + HTTP API** - Full feature parity across interfaces

## 🚀 Quick Start (Docker)

Get SentinelDB running in under 2 minutes with Docker. This guide walks you through deployment, testing the guard system, and verifying Write-Ahead Log (WAL) persistence.

### Step 1: Clone the Repository
```bash
git clone https://github.com/Brijesh-Thakkar/sentineldb.git
cd sentineldb
```

### Step 2: Build the Docker Image
```bash
docker build -t sentineldb .
```

This compiles the C++ codebase and packages the HTTP server into a container.

### Step 3: Run SentinelDB
```bash
docker run -d \
  --name sentineldb \
  -p 8080:8080 \
  -v sentineldb-data:/app/data \
  sentineldb
```

The `-v sentineldb-data:/app/data` flag ensures data persists across container restarts using a named Docker volume.

### Step 4: Health Check
```bash
curl http://localhost:8080/health
```

**Expected Response:**
```json
{"status":"ok"}
```

✅ SentinelDB is now running and ready to accept requests.

### Step 5: Add a Guard Constraint
```bash
curl -X POST http://localhost:8080/guards \
  -H "Content-Type: application/json" \
  -d '{
    "type":"RANGE_INT",
    "name":"score_guard",
    "keyPattern":"score*",
    "min":"0",
    "max":"100"
  }'
```

**Expected Response:**
```json
{
  "status": "ok",
  "message": "Guard 'score_guard' added successfully",
  "guard": {
    "name": "score_guard",
    "type": "RANGE_INT",
    "keyPattern": "score*",
    "description": "RANGE_INT [0, 100]"
  }
}
```

This guard ensures any key matching `score*` must have an integer value between 0 and 100.

### Step 6: Propose a Write (Test the Guard)
```bash
curl -X POST http://localhost:8080/propose \
  -H "Content-Type: application/json" \
  -d '{"key":"score","value":"150"}'
```

**Expected Response:**
```json
{
  "proposal": {
    "key": "score",
    "value": "150"
  },
  "result": "COUNTER_OFFER",
  "reason": "Value 150 outside acceptable range [0, 100]",
  "triggeredGuards": ["score_guard"],
  "alternatives": [
    {
      "value": "100",
      "explanation": "Maximum allowed value (proposed 150 is too high)"
    },
    {
      "value": "75",
      "explanation": "Conservative value within range"
    }
  ]
}
```

Instead of rejecting the write, SentinelDB **negotiates** by proposing safe alternatives.

### Step 7: Verify WAL Persistence (Restart-Safe)
```bash
docker restart sentineldb
sleep 3
curl http://localhost:8080/guards
```

**Expected Response:**
```json
{
  "guards": [
    {
      "name": "score_guard",
      "keyPattern": "score*",
      "description": "Integer range: [0, 100]",
      "enabled": true
    }
  ]
}
```

✅ The guard survived the restart. SentinelDB uses a **Write-Ahead Log (WAL)** to ensure all guards, policies, and data persist to disk before acknowledging writes. WAL replay during startup guarantees idempotent recovery—restarting multiple times produces identical state.

---

### Deployment Notes

**AWS EC2 Demo Instance**  
A public demo instance is available at `http://3.107.112.47:8080` for testing. This instance is **not production-grade** and may be stopped or reset at any time. Use it for experimentation only.

⚠️ **For production deployments:**
- Use a Docker restart policy: `docker run --restart=unless-stopped ...`
- Mount persistent volumes for `/app/data` to preserve WAL and snapshots
- Run behind a reverse proxy (e.g., nginx) with proper authentication
- Configure firewall rules to restrict access to trusted IPs

**WAL and Data Durability**  
SentinelDB writes all operations (guards, policies, data) to a WAL before acknowledging success. On restart, the WAL is replayed to restore exact state. Duplicate entries (e.g., guards with the same name) are automatically deduplicated during replay to maintain idempotency.

## Run with Docker

Build the image:
```bash
docker build -t sentineldb .
```

Run the HTTP server:
```bash
docker run -p 8080:8080 sentineldb
```

The server runs on port 8080. Data persists in the `/app/data` volume across container restarts.

For persistent storage:
```bash
docker run -p 8080:8080 -v sentineldb-data:/app/data sentineldb
```

## Run Demos

**CLI Demo** - Shows policy negotiation behavior:
```bash
./demos/demo_cli.sh
```
Demonstrates STRICT rejection vs DEV_FRIENDLY counter-proposals.

**HTTP API Demo** - Shows remote policy control:
```bash
./demos/demo_http.sh
```
Tests policy changes, write proposals, and temporal queries via REST API.

**Restart Demo** - Proves policy persistence:
```bash
./demos/demo_restart.sh
```
Verifies that policy changes survive server restarts.

## Build Locally

Requirements: C++17, CMake 3.10+, g++ or clang

```bash
cmake -S . -B build
cmake --build build
```

Run CLI:
```bash
./build/redis_db
```

Run HTTP server:
```bash
./build/http_server --port 8080
```

## HTTP API Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/set` | POST | Write key-value (commits immediately) |
| `/get` | GET | Read latest value |
| `/history` | GET | Retrieve all versions |
| `/propose` | POST | Simulate write, get verdict |
| `/policy` | GET | View current decision policy |
| `/policy` | POST | Change decision policy |

All endpoints accept/return JSON.

## Project Status

SentinelDB is feature-complete and stable. It was built to explore:
- How databases can provide better feedback than "constraint violation"
- Whether negotiation is a viable alternative to rejection
- How decision policies can adapt based on deployment context

The codebase is production-quality but intended for experimentation, research, and learning. It demonstrates concepts that could be integrated into existing database systems.

Core functionality:
- Temporal versioning with millisecond precision
- Durable persistence via WAL and snapshots
- Policy-driven write evaluation
- Full CLI and HTTP parity
- Comprehensive test coverage

## Documentation

- [POLICIES.md](POLICIES.md) - Decision policy behavior and use cases
- [POLICY_PERSISTENCE.md](POLICY_PERSISTENCE.md) - How policies persist across restarts
- [TEMPORAL.md](TEMPORAL.md) - Temporal versioning and queries
- [RETENTION.md](RETENTION.md) - Version retention configuration
- [QUICKREF.md](QUICKREF.md) - Command reference

## License

This project is open source. See the code for implementation details.
