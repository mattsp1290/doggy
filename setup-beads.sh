#!/bin/bash
# Project: doggy — Datadog-native observability for Nim
# Generated: 2026-05-28

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating doggy project bead graph..."

# ========================================
# Phase 1: Project Setup & Infrastructure
# ========================================

SETUP_NIMBLE=$(bd create "Initialize Nimble package and module structure" \
  -d "Create doggy.nimble with metadata (name, version, author, description, license, srcDir=src, requires nim>=2.0.0). Create directory tree: src/doggy/, tests/rum/, tests/dogstatsd/, tests/error_tracking/, tests/events/, examples/. Add src/doggy.nim as the top-level re-export module. Stub out empty placeholder files for each submodule so the package compiles from day one." \
  -p 0 -l setup --silent)

SETUP_DOCS_CONTEXT=$(bd create "Write agent context docs in docs/" \
  -d "Create docs/rum-event-hierarchy.md: document every required field for each RUM event type (session, view, action, resource, error, vital), the NDJSON batch format, and how view.id and session.id propagate to child events. Create docs/dogstatsd-datagram-spec.md: datagram wire format, metric types, tag syntax, event/service-check format. Create docs/dd-site-mapping.md: the full per-site intake URL lookup table. Create docs/game-loop-integration.md: patterns for calling DogStatsD from a hot loop without blocking and emitting frame vitals from a frame callback." \
  -p 0 -l docs --silent)

SETUP_CI=$(bd create "Configure GitHub Actions CI workflow" \
  -d "Create .github/workflows/ci.yml. Steps: checkout, install Nim (latest stable via nim-lang/setup-nim-action), compile all examples with --mm:orc --threads:on -d:ssl, run testament tests with DD_API_KEY / DD_CLIENT_TOKEN / DD_APPLICATION_ID secrets injected as env vars. Add a separate job that runs unit-only tests (no secrets required) for PRs from forks. Cache the Nim compiler between runs." \
  -p 1 -l setup --silent)

bd dep add "$SETUP_DOCS_CONTEXT" "$SETUP_NIMBLE"
bd dep add "$SETUP_CI" "$SETUP_NIMBLE"

# ========================================
# Phase 2: Core Utilities
# ========================================

CORE_SITE=$(bd create "Implement DD_SITE resolver and intake URL builder" \
  -d "Create src/doggy/site.nim. Define a DdSite enum or distinct string type. Implement a hardcoded lookup table (NOT string interpolation) for the five supported sites: datadoghq.com, datadoghq.eu, us3.datadoghq.com, us5.datadoghq.com, ap1.datadoghq.com. Expose rumIntakeUrl(), logsIntakeUrl(), apiBaseUrl() procs. Read DD_SITE env var in an initSite() constructor; raise a clear ValueError for unknown values. See docs/dd-site-mapping.md for the full table." \
  -p 0 -l core --silent)

CORE_UUID=$(bd create "Implement UUID v4 generator using std/sysrand" \
  -d "Create src/doggy/uuid.nim. Generate RFC 4122 v4 UUIDs using std/sysrand (NOT std/random) for entropy. Output standard hyphenated lowercase string form (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx). Expose newUuid4(): string. Unit test (in tests/test_uuid.nim) must assert uniqueness across N=10_000 generated IDs using a HashSet." \
  -p 0 -l core --silent)

CORE_JSON=$(bd create "Implement hand-rolled JSON and NDJSON emitter" \
  -d "Create src/doggy/json_emit.nim. No stdlib json dependency. Implement a JsonBuilder object with methods: addStr(key, val: string), addInt(key: string, val: int64), addFloat(key: string, val: float64), addBool(key: string, val: bool), addNull(key: string), startObj(key: string), endObj(), startArr(key: string), endArr(). Expose build(): string to get the final JSON object. Implement toNdjson(lines: seq[string]): string joining with newlines. Handle string escaping: backslash, double-quote, control characters." \
  -p 0 -l core --silent)

CORE_HTTP=$(bd create "Implement HTTP client wrapper with auth and retry policy" \
  -d "Create src/doggy/http_client.nim. Wrap stdlib httpclient. Implement postJson(url: string, body: string, apiKey: string, extraHeaders: openArray[(string,string)] = []): HttpResponse. Implement retry logic: exponential backoff on 429/502/503/504, honor Retry-After header (parse int seconds), max 3 retries, no retry on other 4xx. Raise on 5xx after retries exhausted. No retry means log warning and return response. Compile with -d:ssl for HTTPS; support HTTP-only builds without ssl flag." \
  -p 0 -l core --silent)

CORE_CHAN=$(bd create "Implement thread-safe queue using Nim channels and Isolated[T]" \
  -d "Create src/doggy/queue.nim. Implement a generic AsyncQueue[T] using Channel[Isolated[T]] compiled with --mm:orc --threads:on. Expose enqueue(item: sink T): bool (returns false if queue full, never raises), tryDequeue(): Option[T], drain(): seq[T]. Configure a max-size constant (default 8192 items). This queue is used by RUM and Error Tracking exporters." \
  -p 0 -l core --silent)

bd dep add "$CORE_SITE" "$SETUP_NIMBLE"
bd dep add "$CORE_UUID" "$SETUP_NIMBLE"
bd dep add "$CORE_JSON" "$SETUP_NIMBLE"
bd dep add "$CORE_HTTP" "$CORE_SITE"
bd dep add "$CORE_HTTP" "$CORE_JSON"
bd dep add "$CORE_CHAN" "$SETUP_NIMBLE"

# ========================================
# Phase 3: RUM — Types and Session
# ========================================

RUM_TYPES=$(bd create "Define RUM event types and public API surface" \
  -d "Create src/doggy/rum/types.nim. Define value types (no hidden pointers): RumSessionEvent, RumViewEvent, RumActionEvent (type: click|tap|swipe|custom), RumResourceEvent (type: image|audio|other; duration_ms), RumErrorEvent (message, source, stack), RumVitalEvent (name, value: float64, unit: string). Each type includes: sessionId, viewId, applicationId, timestamp (ms since epoch), ddtags, service, version. Define RumConfig: clientToken, applicationId, service, version, site: DdSite, batchSize: int = 50, flushIntervalMs: int = 10_000." \
  -p 0 -l rum --silent)

RUM_SESSION=$(bd create "Implement RUM session lifecycle manager" \
  -d "Create src/doggy/rum/session.nim. Implement RumSession object tracking: sessionId (UUID v4), currentViewId, lastActivityMs (epoch ms). Rules: session expires after 4h total or 15min inactivity from lastActivityMs; touch() updates lastActivityMs; newView() generates a new viewId UUID, touches the session, returns viewId; isExpired(): bool checks both limits; newSession() resets both IDs. All IDs generated via uuid.nim. Thread-safe via Mutex for shared state." \
  -p 0 -l rum --silent)

RUM_SERIALIZE=$(bd create "Implement RUM event serialization to NDJSON" \
  -d "Create src/doggy/rum/serialize.nim. Implement toJson(ev: RumSessionEvent): string, toJson(ev: RumViewEvent): string, etc. for all six event types. Use json_emit.nim. Required top-level fields on every event: _dd.format_version=2, type (session|view|action|resource|error|vital), date (ms epoch), application.id, session.id, view.id. Follow the RUM event hierarchy from docs/rum-event-hierarchy.md for required per-type fields." \
  -p 0 -l rum --silent)

RUM_VITALS=$(bd create "Implement game-specific RUM vitals: frame_time, fps, memory" \
  -d "Create src/doggy/rum/vitals.nim. Add helper constructors: newFrameTimeVital(ms: float64): RumVitalEvent, newFpsVital(fps: float64): RumVitalEvent, newMemoryVital(bytes: int64): RumVitalEvent, newCustomVital(name: string, value: float64, unit: string): RumVitalEvent. These call the RumVitalEvent constructor with the correct name/unit/value fields defined in rum/types.nim." \
  -p 2 -l rum --silent)

RUM_EXPORTER=$(bd create "Implement async RUM batch exporter with lifecycle" \
  -d "Create src/doggy/rum/exporter.nim. Implement RumExporter object. Constructor takes RumConfig. Worker thread reads from AsyncQueue[string] (NDJSON lines), batches up to batchSize events or flushIntervalMs, then POSTs NDJSON to the RUM intake URL (client token as dd-api-key query param, no DD-API-KEY header). Implement send(ev: RumViewEvent) etc overloads (serializes and enqueues). Implement forceFlush(): drains queue and flushes immediately. Implement shutdown(): signals worker to drain and stop, joins thread. Drop with warning when queue full." \
  -p 0 -l rum --silent)

bd dep add "$RUM_TYPES" "$CORE_JSON"
bd dep add "$RUM_TYPES" "$CORE_SITE"
bd dep add "$RUM_SESSION" "$RUM_TYPES"
bd dep add "$RUM_SESSION" "$CORE_UUID"
bd dep add "$RUM_SERIALIZE" "$RUM_TYPES"
bd dep add "$RUM_SERIALIZE" "$RUM_SESSION"
bd dep add "$RUM_VITALS" "$RUM_TYPES"
bd dep add "$RUM_EXPORTER" "$RUM_SERIALIZE"
bd dep add "$RUM_EXPORTER" "$RUM_VITALS"
bd dep add "$RUM_EXPORTER" "$CORE_HTTP"
bd dep add "$RUM_EXPORTER" "$CORE_CHAN"

# ========================================
# Phase 4: DogStatsD UDP Client
# ========================================

STATSD_TYPES=$(bd create "Define DogStatsD metric and event types" \
  -d "Create src/doggy/dogstatsd/types.nim. Define StatsdConfig: host: string = 'localhost', port: int = 8125, defaultTags: seq[string] = @[], onError: proc(msg: string) = nil. Define metric constructor procs (NOT types that need encoding knowledge): newCounter, newGauge, newHistogram, newSet, newTiming — each takes name, value, tags, sampleRate. Define StatsdEvent: title, text, alertType (info|warning|error|success), tags. Define StatsdServiceCheck: name, status (ok|warning|critical|unknown), message, tags." \
  -p 0 -l dogstatsd --silent)

STATSD_ENCODER=$(bd create "Implement DogStatsD datagram encoder" \
  -d "Create src/doggy/dogstatsd/encoder.nim. Implement encodeMetric(name: string, value: string, metricType: string, sampleRate: float, tags: seq[string]): string producing the wire format: 'name:value|type|@rate|#tag1,tag2'. Implement encodeEvent(ev: StatsdEvent): string per the _e{title.len,text.len}:title|text|... format. Implement encodeServiceCheck(sc: StatsdServiceCheck): string per _sc|name|status|... format. See docs/dogstatsd-datagram-spec.md." \
  -p 0 -l dogstatsd --silent)

STATSD_CLIENT=$(bd create "Implement DogStatsD fire-and-forget UDP client" \
  -d "Create src/doggy/dogstatsd/client.nim. Implement DogStatsd object with an atomic droppedCount: Atomic[int64] and optional onError callback. Open UDP socket on init (resolving host/port via stdlib net). Implement send(datagram: string) — calls socket.sendTo, on any OSError increments droppedCount atomically and calls onError if set; NEVER raises. Implement counter(), gauge(), histogram(), set(), timing(), event(), serviceCheck() public procs as thin wrappers over encodeX + send. No background thread — all sends are synchronous fire-and-forget on the caller's thread." \
  -p 0 -l dogstatsd --silent)

bd dep add "$STATSD_TYPES" "$SETUP_NIMBLE"
bd dep add "$STATSD_ENCODER" "$STATSD_TYPES"
bd dep add "$STATSD_CLIENT" "$STATSD_ENCODER"

# ========================================
# Phase 5: Error Tracking
# ========================================

ET_TYPES=$(bd create "Define Error Tracking types and payload schema" \
  -d "Create src/doggy/error_tracking/types.nim. Define ErrorEvent: errorStack (string), errorKind (string — exception type name), errorMessage (string), ddSource (string = 'nim'), service (string), hostname (string), ddTags (string), version (string). Define ErrorTrackingConfig: apiKey, service, hostname, version, site: DdSite, batchSize: int = 20, flushIntervalMs: int = 5_000. hostname should default to std/os.getHostname() if not set." \
  -p 0 -l error-tracking --silent)

ET_SERIALIZE=$(bd create "Implement Error Tracking event serialization to JSON log array" \
  -d "Create src/doggy/error_tracking/serialize.nim. Implement toJson(ev: ErrorEvent): string using json_emit.nim. Required fields: error.stack, error.kind, error.message, ddsource, service, hostname, ddtags. Implement toJsonArray(events: seq[ErrorEvent]): string wrapping in a JSON array (not NDJSON). These payloads go to the logs intake endpoint which expects a JSON array, not NDJSON." \
  -p 0 -l error-tracking --silent)

ET_EXPORTER=$(bd create "Implement async Error Tracking batch exporter with lifecycle" \
  -d "Create src/doggy/error_tracking/exporter.nim. Implement ErrorTrackingExporter with worker thread and AsyncQueue[ErrorEvent]. Batch up to batchSize events or flushIntervalMs, then POST JSON array to the logs intake URL with DD-API-KEY header (not client token). Implement report(ev: ErrorEvent), forceFlush(), shutdown() matching the same lifecycle contract as RumExporter. Convenience: reportException(name, msg, stack: string) to build and enqueue an ErrorEvent." \
  -p 0 -l error-tracking --silent)

bd dep add "$ET_TYPES" "$CORE_JSON"
bd dep add "$ET_TYPES" "$CORE_SITE"
bd dep add "$ET_SERIALIZE" "$ET_TYPES"
bd dep add "$ET_EXPORTER" "$ET_SERIALIZE"
bd dep add "$ET_EXPORTER" "$CORE_HTTP"
bd dep add "$ET_EXPORTER" "$CORE_CHAN"

# ========================================
# Phase 6: Custom Events API
# ========================================

EVENTS_TYPES=$(bd create "Define Custom Events types and payload schema" \
  -d "Create src/doggy/events/types.nim. Define DdEvent: title (string), text (string), dateHappened (int64, epoch seconds), alertType (info|warning|error|success), tags (seq[string]), sourceTypeName (string). Define EventsConfig: apiKey, site: DdSite. Implement toJson(ev: DdEvent): string using json_emit.nim per the /api/v2/events schema." \
  -p 1 -l events --silent)

EVENTS_CLIENT=$(bd create "Implement Custom Events REST API client" \
  -d "Create src/doggy/events/client.nim. Implement EventsClient wrapping postJson from http_client.nim. Implement send(ev: DdEvent): bool — POSTs to api.{DD_SITE}/api/v2/events with DD-API-KEY header; returns true on 2xx, false otherwise (logs warning). Synchronous, no background thread. Provide newEventsClient(cfg: EventsConfig): EventsClient constructor." \
  -p 1 -l events --silent)

bd dep add "$EVENTS_TYPES" "$CORE_JSON"
bd dep add "$EVENTS_TYPES" "$CORE_SITE"
bd dep add "$EVENTS_CLIENT" "$EVENTS_TYPES"
bd dep add "$EVENTS_CLIENT" "$CORE_HTTP"

# ========================================
# Phase 7: Top-level public API module
# ========================================

API_MODULE=$(bd create "Write top-level doggy.nim re-export module" \
  -d "Update src/doggy.nim to re-export all public symbols: include from rum/types, rum/session, rum/vitals, rum/exporter; dogstatsd/types, dogstatsd/client; error_tracking/types, error_tracking/exporter; events/types, events/client. Also re-export site.nim and uuid.nim. Ensure users can do 'import doggy' and get everything without knowing the internal structure." \
  -p 1 -l impl --silent)

bd dep add "$API_MODULE" "$RUM_EXPORTER"
bd dep add "$API_MODULE" "$STATSD_CLIENT"
bd dep add "$API_MODULE" "$ET_EXPORTER"
bd dep add "$API_MODULE" "$EVENTS_CLIENT"

# ========================================
# Phase 8: Unit Tests
# ========================================

TEST_UUID=$(bd create "Unit tests: UUID v4 generator" \
  -d "Create tests/test_uuid.nim using testament. Test: (1) generated string matches regex xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx, (2) uniqueness — generate 10_000 UUIDs into a HashSet, assert len == 10_000, (3) entropy from sysrand (no seeding required — just verify it compiles with no random import). Run with: testament tests/test_uuid.nim" \
  -p 1 -l testing --silent)

TEST_JSON=$(bd create "Unit tests: JSON and NDJSON emitter" \
  -d "Create tests/test_json_emit.nim using testament. Test: (1) basic key/value emission for all types, (2) nested objects, (3) arrays, (4) string escaping (backslash, quotes, control chars), (5) empty object, (6) toNdjson joins lines with newline, (7) round-trip: parse emitted JSON with stdlib json and assert field values." \
  -p 1 -l testing --silent)

TEST_STATSD=$(bd create "Unit tests: DogStatsD datagram encoder" \
  -d "Create tests/dogstatsd/test_encoder.nim using testament. Test datagram wire format for: counter (name:value|c|#tags), gauge (name:value|g), histogram (name:value|h), set (name:value|s), timing (name:value|ms), sample rate formatting (@0.5), tag serialization (comma-separated), event wire format (_e{t,m}:title|text|...), service check wire format (_sc|name|status). Assert exact string output for each." \
  -p 1 -l testing --silent)

TEST_SESSION=$(bd create "Unit tests: RUM session expiry and continuity" \
  -d "Create tests/rum/test_session.nim using testament. Test: (1) newSession() generates two distinct UUIDs for sessionId and viewId, (2) newView() returns a new viewId but same sessionId, (3) isExpired() returns false immediately, (4) simulate 15min inactivity by manipulating lastActivityMs directly — isExpired() must return true, (5) simulate 4h total by adjusting sessionStartMs — isExpired() returns true, (6) touch() resets inactivity timer, (7) session continuity: viewId changes on newView(), sessionId unchanged." \
  -p 1 -l testing --silent)

TEST_SITE=$(bd create "Unit tests: DD_SITE resolver" \
  -d "Create tests/test_site.nim using testament. Test: (1) each of the five valid DD_SITE values resolves to the correct rum/logs/api URL, (2) unknown DD_SITE raises ValueError with a message containing the invalid value, (3) empty DD_SITE string raises ValueError, (4) default site (env var unset) resolves to datadoghq.com URLs." \
  -p 1 -l testing --silent)

TEST_HTTP_RETRY=$(bd create "Unit tests: HTTP retry logic" \
  -d "Create tests/test_http_client.nim using testament. Use a mock HTTP server (stdlib asynchttpserver or a simple TCP responder) to simulate: (1) 429 with Retry-After: 1 triggers one retry, (2) 502/503/504 trigger retries up to max, (3) 400/401/403/404 do NOT retry, (4) Retry-After header parsed correctly. Assert droppedCount stays zero on successful send. Keep server on a random port to avoid collisions." \
  -p 2 -l testing --silent)

bd dep add "$TEST_UUID" "$CORE_UUID"
bd dep add "$TEST_JSON" "$CORE_JSON"
bd dep add "$TEST_STATSD" "$STATSD_ENCODER"
bd dep add "$TEST_SESSION" "$RUM_SESSION"
bd dep add "$TEST_SITE" "$CORE_SITE"
bd dep add "$TEST_HTTP_RETRY" "$CORE_HTTP"

# ========================================
# Phase 9: Integration Tests
# ========================================

ITEST_RUM=$(bd create "Integration tests: RUM intake against Datadog" \
  -d "Create tests/rum/test_integration.nim using testament. Requires DD_CLIENT_TOKEN, DD_APPLICATION_ID, DD_SITE env vars. Send one RumSessionEvent, one RumViewEvent, one RumActionEvent, one RumVitalEvent (frame_time). Call forceFlush(). Sleep 5s. Use pup CLI ($HOME/git/pup/target/release/pup) to query the RUM API and assert events appear. Skip test if credentials not set (use testament's skip mechanism). Test labeled 'integration' for CI separation." \
  -p 1 -l testing --silent)

ITEST_STATSD=$(bd create "Integration tests: DogStatsD against local Agent" \
  -d "Create tests/dogstatsd/test_integration.nim using testament. Sends counter, gauge, histogram, event, and service check to localhost:8125. Uses pup CLI to query the metrics API after a 10s wait and asserts values appear. Marks test as skipped if DD_API_KEY not set. Verifies droppedCount is zero after all sends." \
  -p 2 -l testing --silent)

ITEST_ET=$(bd create "Integration tests: Error Tracking intake against Datadog" \
  -d "Create tests/error_tracking/test_integration.nim using testament. Requires DD_API_KEY, DD_SITE. Report one error event with a synthetic stack trace. Call forceFlush(). Sleep 10s. Use pup CLI to query logs/error-tracking and assert the event appears. Skip if credentials not set." \
  -p 1 -l testing --silent)

ITEST_EVENTS=$(bd create "Integration tests: Custom Events API against Datadog" \
  -d "Create tests/events/test_integration.nim using testament. Requires DD_API_KEY, DD_SITE. Send one DdEvent and assert a 2xx response is returned synchronously. Optionally use pup CLI to confirm the event appears in the events stream. Skip if credentials not set." \
  -p 2 -l testing --silent)

bd dep add "$ITEST_RUM" "$RUM_EXPORTER"
bd dep add "$ITEST_RUM" "$TEST_SESSION"
bd dep add "$ITEST_STATSD" "$STATSD_CLIENT"
bd dep add "$ITEST_STATSD" "$TEST_STATSD"
bd dep add "$ITEST_ET" "$ET_EXPORTER"
bd dep add "$ITEST_ET" "$TEST_JSON"
bd dep add "$ITEST_EVENTS" "$EVENTS_CLIENT"

# ========================================
# Phase 10: Examples
# ========================================

EXAMPLE_RUM=$(bd create "Write examples/rum.nim — runnable RUM demo" \
  -d "Create examples/rum.nim. Read DD_CLIENT_TOKEN, DD_APPLICATION_ID, DD_SITE from env vars. Init RumExporter. Simulate a game session: start session, record a view (main_menu), fire a RumActionEvent (button click), record frame vitals (60fps, 16.7ms frame), record a view transition (gameplay), send a resource load (asset_load), send an error. Call shutdown(). Print each step. No hardcoded credentials." \
  -p 1 -l docs --silent)

EXAMPLE_STATSD=$(bd create "Write examples/dogstatsd.nim — runnable DogStatsD demo" \
  -d "Create examples/dogstatsd.nim. Read DD_AGENT_HOST (default localhost), DD_AGENT_PORT (default 8125) from env. Init DogStatsd with onError callback that prints to stderr. Simulate 100 game loop iterations: increment a frame counter, send gauge for fps, send histogram for frame_time_ms, send a custom event every 10 iterations. Print droppedCount at end. Demonstrates safe hot-loop usage." \
  -p 1 -l docs --silent)

EXAMPLE_ET=$(bd create "Write examples/error_tracking.nim — runnable Error Tracking demo" \
  -d "Create examples/error_tracking.nim. Read DD_API_KEY, DD_SITE from env. Init ErrorTrackingExporter. Report two synthetic errors: one with a multi-line stack trace, one using reportException() convenience. Call shutdown(). Print confirmation. No real exceptions needed — construct stack strings manually for the demo." \
  -p 1 -l docs --silent)

EXAMPLE_EVENTS=$(bd create "Write examples/events.nim — runnable Custom Events demo" \
  -d "Create examples/events.nim. Read DD_API_KEY, DD_SITE from env. Init EventsClient. Send three DdEvents representing game lifecycle milestones: match_started (info), player_died (warning), level_completed (success). Print HTTP result for each. Demonstrates synchronous fire-and-check pattern." \
  -p 1 -l docs --silent)

bd dep add "$EXAMPLE_RUM" "$RUM_EXPORTER"
bd dep add "$EXAMPLE_RUM" "$API_MODULE"
bd dep add "$EXAMPLE_STATSD" "$STATSD_CLIENT"
bd dep add "$EXAMPLE_STATSD" "$API_MODULE"
bd dep add "$EXAMPLE_ET" "$ET_EXPORTER"
bd dep add "$EXAMPLE_ET" "$API_MODULE"
bd dep add "$EXAMPLE_EVENTS" "$EVENTS_CLIENT"
bd dep add "$EXAMPLE_EVENTS" "$API_MODULE"

# ========================================
# Phase 11: Documentation & Deploy
# ========================================

DOCS_README=$(bd create "Write comprehensive README.md" \
  -d "Rewrite README.md. Sections: (1) What is doggy (elevator pitch, OTel gap context), (2) Installation (nimble install doggy, -d:ssl note), (3) Quick start per signal — RUM, DogStatsD, Error Tracking, Events — each a minimal runnable snippet, (4) DD_SITE configuration table with all five sites, (5) Game loop integration guide: DogStatsD counter/gauge from hot loop without blocking, frame vitals from frame callback, session/view lifecycle around screen transitions, (6) Lifecycle: forceFlush/shutdown, (7) Environment variables reference table, (8) License." \
  -p 1 -l docs --silent)

DEPLOY_CI_SECRETS=$(bd create "Document CI secrets and finalize workflow" \
  -d "Update .github/workflows/ci.yml to separate unit-test job (no secrets, runs on PRs from forks) from integration-test job (requires DD_API_KEY, DD_CLIENT_TOKEN, DD_APPLICATION_ID, DD_SITE secrets). Add pup binary cache step or build-from-source step using $HOME/git/pup. Add testament --tags:integration flag to the integration job. Document in docs/ which secrets must be set in GitHub repo settings." \
  -p 2 -l deploy --silent)

DEPLOY_NIMBLE=$(bd create "Finalize Nimble package for publishing" \
  -d "Update doggy.nimble: verify version, description, author, license (MIT), homepage (GitHub URL), srcDir, skipDirs for tests/examples. Add a 'test' task that runs testament. Verify 'nimble install' from the repo root succeeds in a clean environment. Check nimble.directory for any name conflicts. Document publish steps (nimble publish, version bump checklist) in docs/publishing.md." \
  -p 2 -l deploy --silent)

bd dep add "$DOCS_README" "$EXAMPLE_RUM"
bd dep add "$DOCS_README" "$EXAMPLE_STATSD"
bd dep add "$DOCS_README" "$EXAMPLE_ET"
bd dep add "$DOCS_README" "$EXAMPLE_EVENTS"
bd dep add "$DOCS_README" "$SETUP_DOCS_CONTEXT"
bd dep add "$DEPLOY_CI_SECRETS" "$SETUP_CI"
bd dep add "$DEPLOY_CI_SECRETS" "$ITEST_RUM"
bd dep add "$DEPLOY_CI_SECRETS" "$ITEST_ET"
bd dep add "$DEPLOY_NIMBLE" "$DOCS_README"
bd dep add "$DEPLOY_NIMBLE" "$DEPLOY_CI_SECRETS"
bd dep add "$DEPLOY_NIMBLE" "$API_MODULE"

echo ""
echo "Bead graph created! View with:"
echo "  bd ready              # List unblocked tasks"
echo "  bd graph              # Show dependency graph"
echo "  bd list               # Show all beads"
