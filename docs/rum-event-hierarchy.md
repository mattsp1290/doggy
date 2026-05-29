# RUM Event Hierarchy

## Overview

All RUM events share a common base and propagate session and view ancestry.
The Datadog RUM intake at `https://browser-intake-{DD_SITE}/api/v2/rum` accepts
NDJSON-formatted batches (one event JSON per line).

## Common Fields (All Event Types)

| JSON Path | Type | Notes |
|-----------|------|-------|
| `_dd.format_version` | int (2) | Always 2 |
| `type` | string | `session`, `view`, `action`, `resource`, `error`, `vital` |
| `date` | int64 | Milliseconds since Unix epoch |
| `application.id` | string | applicationId from RumConfig |
| `session.id` | string | UUID v4, managed by RumSession |
| `view.id` | string | UUID v4, changes on newView() |
| `service` | string | From RumConfig; omitted if empty |
| `version` | string | From RumConfig; omitted if empty |
| `ddtags` | string | Comma-separated tags; omitted if empty |

## Event Types

### session

```json
{
  "_dd": {"format_version": 2},
  "type": "session",
  "date": 1748476800000,
  "application": {"id": "abc123"},
  "session": {"id": "uuid-v4"},
  "view": {"id": "uuid-v4"},
  "service": "my-game"
}
```

Emitted when a new session starts.

### view

```json
{
  "_dd": {"format_version": 2},
  "type": "view",
  "date": 1748476800000,
  "application": {"id": "abc123"},
  "session": {"id": "uuid-v4"},
  "view": {
    "id": "uuid-v4",
    "name": "MainMenu",
    "url": "game://main"
  }
}
```

**Required**: `view.name`. `view.url` omitted if empty.

### action

```json
{
  "type": "action",
  "action": {
    "type": "click",
    "target": {"name": "PlayButton"}
  },
  "view": {"id": "uuid-v4"},
  ...
}
```

Action types: `click`, `tap`, `swipe`, `custom`. `action.target` omitted if name is empty.

### resource

```json
{
  "type": "resource",
  "resource": {
    "type": "image",
    "url": "game://asset.png",
    "duration": 250
  },
  ...
}
```

Resource types: `image`, `audio`, `other`. `duration` is milliseconds.

### error

```json
{
  "type": "error",
  "error": {
    "message": "NullPointerException",
    "source": "source",
    "stack": "at main.nim:42\n..."
  },
  ...
}
```

`source` and `stack` omitted if empty.

### vital

```json
{
  "type": "vital",
  "vital": {
    "name": "frame_time",
    "value": 16.7,
    "unit": "ms"
  },
  ...
}
```

`unit` omitted if empty. See `rum/vitals.nim` for helpers:
- `newFrameTimeVital(ms)` → name=`frame_time`, unit=`ms`
- `newFpsVital(fps)` → name=`fps`, unit=`fps`
- `newMemoryVital(bytes)` → name=`memory`, unit=`byte`
- `newCustomVital(name, value, unit)`

## Session and View Propagation

- All child events (action, resource, error, vital) inherit `session.id` and `view.id` from the active session.
- `session.id` changes on session expiry (4h total or 15min inactivity).
- `view.id` changes on `exporter.newView()` or session rotation.
- The `RumExporter.send()` procs fill in session and view fields automatically at enqueue time.

## NDJSON Batch Format

Each POST contains one or more JSON events, one per line, with no trailing newline:

```
{"type":"session",...}
{"type":"view",...}
{"type":"action",...}
```

Authentication: append `?dd-api-key=<clientToken>` as a URL query parameter.
The `DD-API-KEY` HTTP header is NOT used for RUM.
