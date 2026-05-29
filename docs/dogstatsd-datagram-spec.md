# DogStatsD Datagram Spec

DogStatsD sends UDP datagrams to the Datadog Agent at `localhost:8125` (configurable).

## Metric Datagram Format

```
<metric_name>:<value>|<type>[|@<sample_rate>][|#<tags>]
```

### Metric Types

| Type | Symbol | Description |
|------|--------|-------------|
| Counter | `c` | Monotonically increasing count |
| Gauge | `g` | Arbitrary value snapshot |
| Histogram | `h` | Statistical distribution |
| Set | `s` | Count of unique values |
| Timing | `ms` | Duration in milliseconds |

### Sample Rate

When `sampleRate < 1.0`, the `|@<rate>` field MUST be present so the Agent
can scale the value. The doggy client:
1. Uses `sysrand` entropy to decide whether to send (probability = sampleRate).
2. If sent, includes `|@<rate>` in the datagram.
3. If NOT sent, increments `droppedCount` (no socket attempt).
4. `sampleRate = 1.0` is a no-op (fast path, no RNG draw).

### Tags

Tags are comma-separated key:value pairs after `|#`:

```
hits:1|c|#env:prod,region:us-east-1,version:1.2.3
```

### Examples

```
# Counter: 1 hit
page.views:1|c

# Counter with sample rate and tags
api.requests:1|c|@0.1|#method:GET,status:200

# Gauge: current value
memory.used:1073741824|g|#env:prod

# Histogram: request duration
http.response_time:123.4|h

# Set: unique users
active.users:user-42|s

# Timing: duration in ms
db.query_time:45.2|ms|@0.5
```

## Event Datagram Format

```
_e{<title_len>,<text_len>}:<title>|<text>|t:<alert_type>[|#<tags>]
```

Newlines in title or text are escaped to `\n`.

Alert types: `info`, `warning`, `error`, `success`.

### Example

```
_e{6,12}:Deploy|Deploy v1.0|t:success|#env:prod
```

## Service Check Datagram Format

```
_sc|<name>|<status>[|#<tags>][|m:<message>]
```

Status values: `0` (ok), `1` (warning), `2` (critical), `3` (unknown).

**Important**: Tags MUST precede the message field (`|m:`). The message field
runs to end-of-packet and would absorb any `|#tags` that follow it.

### Example

```
_sc|redis.ping|0|#env:prod,region:us|m:Connection healthy
```

## Error Contract

The doggy DogStatsD client is fire-and-forget:
- `send()` never raises.
- Socket errors increment `droppedCount` and invoke the optional `onError` callback.
- Sample-rate drops increment `droppedCount` but do NOT invoke `onError`.
- All sends are synchronous on the caller's thread (no background thread).
