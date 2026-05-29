# doggy

Datadog-native observability for Nim — **RUM, DogStatsD, Error Tracking, and Custom Events**.

`doggy` covers the Datadog signals that have no OpenTelemetry equivalent: Real User Monitoring (sessions, views, actions, resources, errors, vitals), DogStatsD (UDP custom metrics), Error Tracking (crash/exception ingestion), and the Custom Events REST API. It complements [observy](https://github.com/mattsp1290/observy), which handles the OpenTelemetry signals (traces, OTLP metrics, logs).

**Zero Nimble dependencies.** Pure Nim — the only system library needed is OpenSSL (for HTTPS via `-d:ssl`).

---

## Installation

```bash
nimble install doggy
```

Compile your project with:

```bash
nim c --mm:orc --threads:on -d:ssl myapp.nim
```

---

## Quick start

### DogStatsD

Send metrics to the Datadog Agent (default `localhost:8125`). Fire-and-forget — never blocks.

```nim
import doggy/dogstatsd/types, doggy/dogstatsd/client

proc main() =
  var statsd: DogStatsd
  initDogStatsd(statsd, defaultStatsdConfig())
  defer: deinitDogStatsd(statsd)

  statsd.counter("game.frames", 1.0, tags = @["scene:gameplay"])
  statsd.gauge("game.players_online", 42.0)
  statsd.timing("game.frame_time_ms", 16.7)

main()
```

### RUM

Send session, view, action, resource, error, and vital events to Datadog browser intake.

```nim
import std/os
import doggy/rum/types, doggy/rum/vitals, doggy/rum/exporter

proc main() =
  var rum: RumExporter
  initRumExporter(rum, defaultRumConfig(
    clientToken   = getEnv("DD_CLIENT_TOKEN"),
    applicationId = getEnv("DD_APPLICATION_ID"),
    service       = "my-game",
  ))
  defer: rum.shutdown()

  discard rum.newView()

  var view = RumViewEvent(name: "MainMenu", url: "game://menu")
  rum.send(view)

  var vitalEv = newFrameTimeVital(16.7)
  rum.send(vitalEv)

main()
```

### Error Tracking

Report crashes and exceptions to Datadog via the logs intake. Surfaces in the Error Tracking UI.

```nim
import std/os
import doggy/error_tracking/types, doggy/error_tracking/exporter

proc main() =
  var et: ErrorTrackingExporter
  initErrorTrackingExporter(et, defaultErrorTrackingConfig(
    apiKey  = getEnv("DD_API_KEY"),
    service = "my-game",
  ))
  defer: et.shutdown()

  et.reportException(
    "NilAccessError",
    "Player entity was nil",
    "at game/player.nim:42",
  )

main()
```

### Custom Events

Post game lifecycle events to `POST /api/v2/events`.

```nim
import std/os
import doggy/site
import doggy/events/types, doggy/events/client

let client = newEventsClient(defaultEventsConfig(getEnv("DD_API_KEY")))

discard client.send(DdEvent(
  title:     "Level Completed",
  text:      "Player finished World 1-1 in 45s",
  alertType: datSuccess,
  tags:      @["level:1-1", "env:prod"],
))
```

---

## DD_SITE configuration

Set `DD_SITE` in your environment to target a specific Datadog region:

| `DD_SITE` | Region |
|-----------|--------|
| `datadoghq.com` (default) | US1 |
| `datadoghq.eu` | EU1 |
| `us3.datadoghq.com` | US3 |
| `us5.datadoghq.com` | US5 |
| `ap1.datadoghq.com` | AP1 |

Unknown values raise a `ValueError` at startup. See `docs/dd-site-mapping.md` for the full URL table.

---

## Game loop integration

### DogStatsD from a hot loop

```nim
proc gameLoop() =
  var frameCount = 0
  while true:
    let t0 = getMonoTime()
    updateGame()
    renderFrame()

    # fire-and-forget; never blocks the game loop
    statsd.timing("game.frame_time", frameMs())
    statsd.gauge("game.fps", 1000.0 / frameMs(), sampleRate = 0.1)

    inc frameCount
```

- `sampleRate = 1.0` (default) → every call sent; skips RNG draw entirely.
- `sampleRate < 1.0` → draws once from `sysrand` per call; dropped sends increment `droppedCount` (not `onError`).
- All sends are synchronous UDP; no background thread used.

### RUM vitals from a frame callback

```nim
proc onFrame(frameMs, fps: float64) =
  var ev = newFrameTimeVital(frameMs)
  rum.send(ev)  # serializes and enqueues; never blocks
```

### Session/view lifecycle around screen transitions

```nim
proc onSceneChanged(name, url: string) =
  discard rum.newView()  # rotates view ID
  var v = RumViewEvent(name: name, url: url)
  rum.send(v)
```

---

## Lifecycle

### Background exporters (RUM and Error Tracking)

Both exporters run a background worker thread that batches events and POSTs them periodically.

```nim
# Force all pending events to send now (best-effort, races the worker)
rum.forceFlush()
et.forceFlush()

# Drain the queue and stop the worker thread (blocking)
rum.shutdown()
et.shutdown()
```

Call `shutdown()` before process exit — it ensures all queued events are flushed. `defer: rum.shutdown()` is the idiomatic pattern.

**Do not** call `report`/`send`/`forceFlush` after `shutdown()` — they are no-ops.

---

## Environment variables

| Variable | Used by | Default |
|----------|---------|---------|
| `DD_SITE` | All HTTP signals | `datadoghq.com` |
| `DD_CLIENT_TOKEN` | RUM | _(required)_ |
| `DD_APPLICATION_ID` | RUM | _(required)_ |
| `DD_API_KEY` | Error Tracking, Events | _(required)_ |
| `DD_STATSD_HOST` | DogStatsD (examples only) | `localhost` |
| `DD_STATSD_PORT` | DogStatsD (examples only) | `8125` |

---

## Retry policy

HTTP calls from the Error Tracking, Events, and RUM exporters honor Datadog's retry guidance:

- **Retried**: 429, 502, 503, 504 — exponential backoff (1s → 2s → 4s), up to 3 retries.
- **Retry-After**: delta-seconds form honored; other forms fall back to the exponential schedule.
- **Not retried**: other 4xx — warning logged, response returned.
- **429 after retries exhausted**: returns the 429 response (does not raise). Check `resp.code` if you need to handle exhausted-retry 429s explicitly.
- **5xx in retry set after retries exhausted**: raises `IOError`.
- **Other 5xx** (not in retry set): raises `IOError` immediately.
- **Worker threads**: retries are synchronous on the worker thread (not the caller's thread).

---

## License

MIT — see [LICENSE](LICENSE).
