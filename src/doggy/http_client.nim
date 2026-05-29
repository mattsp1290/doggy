import std/[httpclient, strutils, os]

const MaxRetries = 3

proc shouldRetry(code: int): bool =
  code == 429 or code == 502 or code == 503 or code == 504

proc retryAfterMs(resp: Response; fallback: int): int =
  if resp.headers.hasKey("Retry-After"):
    let valStr: string = resp.headers["Retry-After"]
    try: return parseInt(valStr.strip()) * 1_000
    except ValueError: discard
  fallback

# Blocking: retries up to MaxRetries (3) times with exponential backoff
# (1s → 2s → 4s, or Retry-After seconds), worst-case ~7s + request time.
# Fine for background worker threads; avoid on latency-sensitive call paths.
proc postJson*(url: string; body: string; apiKey: string;
               extraHeaders: openArray[(string, string)] = []): Response =
  let client = newHttpClient()
  defer: client.close()

  var hdrs = @[("Content-Type", "application/json")]
  if apiKey.len > 0:
    hdrs.add(("DD-API-KEY", apiKey))
  for pair in extraHeaders:
    hdrs.add(pair)
  client.headers = newHttpHeaders(hdrs)

  var backoffMs = 1_000

  for attempt in 0 .. MaxRetries:
    let resp = client.post(url, body)
    let code = resp.code.int

    if shouldRetry(code) and attempt < MaxRetries:
      sleep(retryAfterMs(resp, backoffMs))
      backoffMs = backoffMs * 2
      continue

    if code >= 500:
      raise newException(IOError,
        "HTTP " & $code & " from " & url & " after " & $(attempt + 1) & " attempt(s)")

    if code >= 400 and code < 500:
      stderr.writeLine("doggy: HTTP " & $code & " warning for " & url)

    return resp

  raise newException(IOError, "unreachable: retry loop exited without returning")
