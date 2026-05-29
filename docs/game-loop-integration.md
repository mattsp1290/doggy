# Game Loop Integration

## DogStatsD from a Hot Loop

DogStatsD sends are synchronous UDP on the caller's thread. For a 60fps game loop,
each send takes microseconds (DNS resolution happens once at init). Use sample rates
to reduce volume:

```nim
import doggy/dogstatsd/client, doggy/dogstatsd/types

var statsd: DogStatsd
initDogStatsd(statsd, defaultStatsdConfig())

proc gameLoop() =
  var frameCount = 0

  while true:
    let frameStart = getTime()

    # --- update & render ---
    updateGame()
    renderFrame()

    # --- metrics (fire-and-forget, never blocks) ---
    let frameMs = (getTime() - frameStart).inMilliseconds.float64

    # Send every frame — tiny overhead, critical metric
    statsd.timing("game.frame_time", frameMs, sampleRate = 1.0)

    # FPS — sample at 10% to reduce volume
    statsd.gauge("game.fps", 1000.0 / frameMs, sampleRate = 0.1)

    # Memory — sample at 1% (expensive to read)
    if frameCount mod 100 == 0:
      statsd.gauge("game.memory_mb", getMemoryMb(), sampleRate = 1.0)

    inc frameCount
```

**Key rules**:
- `initDogStatsd` opens the UDP socket once. Keep the client alive for the app lifetime.
- `deinitDogStatsd` closes the socket on shutdown.
- Errors (socket failures) are silently counted in `droppedCount`; use `onError` if you want a log.
- `sampleRate = 0.0` drops all sends with zero socket overhead (useful for debug builds).

## RUM Vitals from a Frame Callback

The `RumExporter` is thread-safe via its internal queue. You can call `send()` from
any thread — it serializes the event and enqueues it for the worker thread to POST.

```nim
import doggy/rum/exporter, doggy/rum/types, doggy/rum/vitals

var rum: RumExporter
initRumExporter(rum, defaultRumConfig(
  clientToken   = getEnv("DD_CLIENT_TOKEN"),
  applicationId = getEnv("DD_APPLICATION_ID"),
  service       = "my-game",
))

# Start a view (e.g., on scene transition)
discard rum.newView()
var viewEv = RumViewEvent(name: "GameplayScene", url: "game://gameplay")
rum.send(viewEv)

proc onFrameComplete(frameMs: float64; fps: float64) =
  var vital = newFrameTimeVital(frameMs)
  rum.send(vital)

  var fpsvital = newFpsVital(fps)
  rum.send(fpsvital)

# On game close
rum.shutdown()  # drains queue, joins worker thread
```

## Combining DogStatsD and RUM

DogStatsD and RUM serve complementary roles:
- **DogStatsD**: aggregate metrics dashboards, infra-level views (counters, gauges, histograms)
- **RUM**: per-session user experience (session timeline, error tracking, vital trends)

```nim
proc onPlayerDied(cause: string; sessionMs: int64) =
  # DogStatsD: aggregated counter for dashboards
  statsd.counter("game.player_death", tags = @["cause:" & cause])

  # RUM: individual error event in the user's session timeline
  var err = RumErrorEvent(message: "Player died: " & cause, source: "gameplay")
  rum.send(err)
```

## Graceful Shutdown

Always call `shutdown()` on the `RumExporter` before exit to drain pending events:

```nim
proc onApplicationExit() =
  rum.shutdown()   # blocks until queue drained and worker stopped
  deinitDogStatsd(statsd)
```

`forceFlush()` sends pending events immediately from the calling thread
without stopping the background worker — useful for checkpoint saves or
level transitions where you want metrics committed before continuing.
