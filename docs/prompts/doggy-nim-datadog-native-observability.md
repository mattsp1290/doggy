# Project Planning with Beads

## Agent Instructions

You are an expert software architect creating a comprehensive task breakdown. This task graph will be executed by AI agents working in parallel, coordinated through MCP Agent Mail with file reservations to prevent conflicts.

<quality_expectations>
Create a thorough, production-ready task graph. Include all necessary setup, implementation, testing, and documentation tasks. Go beyond the basics - consider edge cases, error handling, security considerations, and integration points. Each task should be specific enough for an agent to execute independently without ambiguity.
</quality_expectations>

## Project Information

### Links to Relevant Documentation
- https://docs.datadoghq.com/real_user_monitoring/ — RUM overview
- https://docs.datadoghq.com/real_user_monitoring/guide/understanding-the-rum-event-hierarchy/ — event hierarchy (sessions, views, actions, resources, errors, vitals)
- https://docs.datadoghq.com/api/latest/rum/ — RUM query/search API
- https://docs.datadoghq.com/opentelemetry/compatibility/ — OTel gap reference (confirms RUM, DogStatsD, Error Tracking have no OTel equivalent)
- https://docs.datadoghq.com/developers/dogstatsd/ — DogStatsD UDP protocol
- https://docs.datadoghq.com/events/ingest/ — Custom Events API
- https://github.com/mattsp1290/observy — sibling OTLP library (style/API/lifecycle reference)
- https://github.com/guzba/zippy — Nim style reference
- https://github.com/treeform/puppy — Nim style reference

### Project Description
`doggy` — A Nim library for Datadog-native observability that complements observy. Covers the signals Datadog does not expose via OpenTelemetry: Real User Monitoring (sessions, views, actions, resources, errors, vitals), DogStatsD (UDP custom metrics and events), and Error Tracking (crash/exception ingestion). Styled like zippy/puppy — pure Nim, zero Nimble dependencies, `nimble install doggy`. Primary target: video games built in Nim, with view/action types mapped to game concepts (screens/levels, player inputs, asset loads, frame vitals).

**Signal coverage:**
- **RUM** — sessions, views, actions, resources, errors, vitals; intake via POST newline-delimited JSON to `https://browser-intake-{DD_SITE}/api/v2/rum`
- **DogStatsD** — UDP datagrams to port 8125; counters, gauges, histograms, sets, timings, custom events, service checks
- **Error Tracking** — crash and exception ingestion via the **logs intake** (`POST https://http-intake.logs.{DD_SITE}/api/v2/logs`) using `DD-API-KEY` header; payload is a JSON array of log events with required fields: `error.stack` (string), `error.kind` (exception type), `error.message`, `ddsource`, `service`, `hostname`, and `ddtags`; this surfaces in Datadog's Error Tracking UI as standalone (non-RUM) errors and complements observy's backend traces
- **Custom Events** — `POST /api/v2/events` REST endpoint for game lifecycle events (match started, level completed, etc.)

### Technical Stack
- Language: Nim — no Nimble dependencies; only acceptable system-library dependency is OpenSSL (required for HTTPS via `-d:ssl`). HTTP-only deployments need no external libraries.
- Transport: Nim's stdlib `httpclient` for RUM/Error Tracking/Events HTTP intake (HTTP/1.1); stdlib `net` UDP sockets for DogStatsD
- Serialization: Hand-rolled JSON encoder (no stdlib `json` dependency required — simple key/value emission); newline-delimited JSON (NDJSON) for RUM intake batches
- Package manager: Nimble (`.nimble` package file, published to nimble.directory)
- Testing: `testament` (Nim's built-in test runner)
- CI: GitHub Actions
- Nim version target: minimum `nim >= 2.0.0` (matching observy); CI tests against latest stable; compiled with `--mm:orc --threads:on`

### Specific Requirements
- **Zero Nimble dependencies** — same constraint as observy; OpenSSL is the only allowed system-level dep (for TLS)
- **DD_SITE environment variable** — selects the Datadog site; default `datadoghq.com`. The URL builder must use a **hardcoded per-site lookup table** (not string interpolation) because intake subdomains are not uniform. Required mapping:

  | DD_SITE | RUM intake | Logs intake | API |
  |---|---|---|---|
  | `datadoghq.com` | `browser-intake-datadoghq.com` | `http-intake.logs.datadoghq.com` | `api.datadoghq.com` |
  | `datadoghq.eu` | `browser-intake-datadoghq.eu` | `http-intake.logs.datadoghq.eu` | `api.datadoghq.eu` |
  | `us3.datadoghq.com` | `browser-intake-us3-datadoghq.com` | `http-intake.logs.us3.datadoghq.com` | `api.us3.datadoghq.com` |
  | `us5.datadoghq.com` | `browser-intake-us5-datadoghq.com` | `http-intake.logs.us5.datadoghq.com` | `api.us5.datadoghq.com` |
  | `ap1.datadoghq.com` | `browser-intake-ap1-datadoghq.com` | `http-intake.logs.ap1.datadoghq.com` | `api.ap1.datadoghq.com` |

  Unknown DD_SITE values must raise a clear error at init time.
- **RUM authentication** — uses a **client token** (not `DD_API_KEY`) passed as the `dd-api-key` query parameter, plus a required `applicationId` field on every RUM payload; both are set programmatically or via `DD_CLIENT_TOKEN` / `DD_APPLICATION_ID` env vars. The `DD-API-KEY` header is NOT used for RUM.
- **DD-API-KEY header** — required for Error Tracking and Events HTTP intakes only; read from `DD_API_KEY` env var or set programmatically
- **DogStatsD is fire-and-forget** — UDP sends must never block the calling thread; suitable for use in game loop hot paths; configurable host/port (default `localhost:8125`). Error contract: send errors (e.g. `ENOBUFS`, closed socket) are silently swallowed and counted in an atomic `droppedCount` field; users may optionally register an `onError: proc(msg: string)` callback at init time; no exceptions are ever raised from a send call.
- **RUM session management** — client-side UUID v4 session ID generator; session expiry after 4h activity or 15min inactivity; session continuity across views; `applicationId` is a required field on every RUM event (session, view, action, resource, error, vital) and must be set at exporter init time alongside the client token
- **Game-specific vitals** — frame time (ms) and FPS as first-class RUM vital types; memory usage; custom performance counters
- **Async batch export** for RUM and Error Tracking — configurable batch size and flush interval; thread-safe using Nim channels with `--mm:orc --threads:on`; `Isolated[T]` for cross-thread payload passing
- **Exporter lifecycle** — `forceFlush()` and blocking `shutdown()` (drains queue, stops worker thread); matches observy's lifecycle interface
- **Retry policy** — exponential backoff on HTTP 429/502/503/504 for RUM/Error Tracking/Events; honor `Retry-After` header; drop with warning when queue full; no retry on other 4xx
- **RUM event hierarchy fidelity** — view.id and session.id propagated to all child events (actions, resources, errors, vitals); timestamps in milliseconds since epoch
- **Clean idiomatic Nim API** — users fill in value types (`RumView`, `RumAction`, `DogStatsd`, etc.) and call `send()`/`flush()`; no JSON knowledge needed
- **`examples/` directory** — one runnable file per signal: `examples/rum.nim`, `examples/dogstatsd.nim`, `examples/error_tracking.nim`, `examples/events.nim`. Routing per signal: DogStatsD → local Agent at `localhost:8125`; RUM → `browser-intake-{DD_SITE}/api/v2/rum`; Error Tracking → `http-intake.logs.{DD_SITE}/api/v2/logs`; Events → `api.{DD_SITE}/api/v2/events`. All examples read credentials and site from env vars (`DD_CLIENT_TOKEN`, `DD_APPLICATION_ID`, `DD_API_KEY`, `DD_SITE`) so no code changes are needed to switch targets.
- **Comprehensive README** — quick-start per signal, DD_SITE setup, game loop integration example showing DogStatsD from a hot loop alongside RUM vitals
- **Test suite** — unit tests for JSON serialization, DogStatsD datagram encoding, UUID generation, session expiry logic; integration tests send real payloads to `DD_SITE=us3.datadoghq.com` and validate results using `$HOME/git/pup/target/release/pup` (the project's Datadog CLI tool); CI requires `DD_API_KEY`, `DD_CLIENT_TOKEN`, and `DD_APPLICATION_ID` secrets

---

## Your Task

Analyze this project and create a comprehensive **Beads task graph** using the `bd` CLI. Beads provides dependency-aware, conflict-free task management for multi-agent execution.

---

<critical_constraint>
Your ONLY output is a bash shell script. Do NOT use `bd add` — the correct command to create a bead is `bd create`. Use `bd dep add` for dependencies. Do not implement anything yourself.
</critical_constraint>

## Output Format

Generate a shell script that creates the full task graph. The script should:

1. **Initialize Beads** (if not already initialized)
2. **Create all beads** with appropriate priorities
3. **Establish dependencies** between beads
4. **Add labels** for phase grouping

### Example Output

```bash
#!/bin/bash
# Project: doggy
# Generated: 2026-05-28

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating project beads..."

# ========================================
# Phase 1: Project Setup & Infrastructure
# ========================================

SETUP_NIMBLE=$(bd create "Initialize Nimble package and repo structure" -p 0 --label setup --silent)

SETUP_LINT=$(bd create "Configure CI and linting" -p 1 --label setup --silent)
bd dep add $SETUP_LINT $SETUP_NIMBLE

# ========================================
# Phase 2: Core Utilities
# ========================================

CORE_UUID=$(bd create "Implement UUID v4 generator" -p 0 --label core --silent)
bd dep add $CORE_UUID $SETUP_NIMBLE

CORE_JSON=$(bd create "Implement NDJSON encoder for RUM intake" -p 0 --label core --silent)
bd dep add $CORE_JSON $SETUP_NIMBLE

CORE_SITE=$(bd create "Implement DD_SITE resolver and intake URL builder" -p 0 --label core --silent)
bd dep add $CORE_SITE $SETUP_NIMBLE

# ... continue for all phases ...

echo ""
echo "Bead graph created! View with:"
echo "  bd ready              # List unblocked tasks"
```

---

## Bead Creation Guidelines

### Priority Levels
- `-p 0` = Critical (blocking other work)
- `-p 1` = High (important but not blocking)
- `-p 2` = Medium (standard work)
- `-p 3` = Low (nice to have)

### Labels (Phase Grouping)
Use `--label` to group beads by phase:
- `setup` - Project initialization
- `core` - Shared utilities (UUID, JSON, DD_SITE, HTTP client wrapper)
- `rum` - RUM signal implementation
- `dogstatsd` - DogStatsD UDP client
- `error-tracking` - Error Tracking ingestion
- `events` - Custom Events API
- `testing` - Test coverage
- `docs` - Documentation and examples
- `deploy` - CI/CD and Nimble publishing

### Dependency Rules
1. Never create cycles
2. Every bead should have a clear dependency chain back to setup tasks
3. Use `bd dep add CHILD PARENT` (child depends on parent completing first)
4. Parallel work should share a common ancestor, not depend on each other

### Task Granularity
- Each bead should be completable in **under 750 lines of code**
- Tasks should be atomic enough for one agent to complete without coordination
- If a task requires multiple file areas, consider splitting by file area

---

## File Reservation Planning

For each major work area, note the file patterns that will need exclusive reservation:

```bash
# Core utilities: src/doggy/uuid.nim, src/doggy/site.nim, src/doggy/json_emit.nim, src/doggy/http.nim
# RUM: src/doggy/rum.nim, src/doggy/rum/session.nim, src/doggy/rum/types.nim, tests/rum/
# DogStatsD: src/doggy/dogstatsd.nim, tests/dogstatsd/
# Error Tracking: src/doggy/error_tracking.nim, tests/error_tracking/
# Events: src/doggy/events.nim, tests/events/
# Examples: examples/*.nim
```

---

## Context Documentation

Place any important context in `docs/` for agents to reference:
- RUM event hierarchy and required fields per event type
- DogStatsD datagram format spec
- DD_SITE → intake URL mapping table
- Game loop integration patterns (DogStatsD from hot loop, RUM vitals from frame callback)

---

## Verification Steps

After generating the script:

1. **Run it**: `chmod +x setup-beads.sh && ./setup-beads.sh`
2. **Check ready work**: `bd ready` should show initial setup tasks

---

## Completeness Checklist

Ensure your task graph includes:

- [ ] Nimble package setup (`doggy.nimble`, module structure)
- [ ] DD_SITE resolver + intake URL builder
- [ ] UUID v4 generator (for session IDs, view IDs) — must use `std/sysrand` for entropy (not `std/random`); unit test asserts uniqueness across N=10_000 generated IDs
- [ ] NDJSON emitter for RUM batch payloads
- [ ] HTTP client wrapper (DD-API-KEY auth, retry policy, batch flush)
- [ ] RUM session lifecycle (create, expire, continuity across views; applicationId propagated to all events)
- [ ] RUM event types: session, view, action, resource, error, vital
- [ ] Game-specific vitals: frame_time, fps, memory
- [ ] DogStatsD UDP client (counter, gauge, histogram, set, timing, event, service check)
- [ ] DogStatsD fire-and-forget threading model
- [ ] Error Tracking ingestion (stack trace serialization)
- [ ] Custom Events REST API client
- [ ] `forceFlush()` and `shutdown()` lifecycle for async exporters
- [ ] Unit tests: JSON encoding, datagram format, UUID, session expiry
- [ ] Integration tests against local Datadog Agent
- [ ] Examples for each signal
- [ ] README with DD_SITE setup and game loop integration guide
- [ ] CI (GitHub Actions) with testament
- [ ] Nimble publishing checklist
