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

### 1. Run SentinelDB
```bash
docker run -d \
  --name sentineldb \
  -p 8080:8080 \
  -v sentineldb-data:/app/data \
  sentineldb
```

### 2. Health check
```bash
curl http://localhost:8080/health
```

### 3. Add a guard
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

### 4. Propose a write
```bash
curl -X POST http://localhost:8080/propose \
  -d '{"key":"score","value":"150"}'
```

### 5. Restart-safe
```bash
docker restart sentineldb
curl http://localhost:8080/guards
```

Guards persist automatically using Write-Ahead Logging (WAL).

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
