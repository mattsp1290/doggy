## HTTP client retry logic tests using a thread-based TCP responder.

import std/[net, os, atomics, httpclient]
import doggy/http_client

# ----- minimal TCP responder -----

proc httpResp(code: int; retryAfter = ""): string =
  let statusText = case code
    of 200: "OK"
    of 404: "Not Found"
    of 429: "Too Many Requests"
    of 500: "Internal Server Error"
    of 502: "Bad Gateway"
    of 503: "Service Unavailable"
    of 504: "Gateway Timeout"
    else:   "Status"
  result = "HTTP/1.1 " & $code & " " & statusText & "\r\nContent-Length: 4\r\n"
  if retryAfter.len > 0: result &= "Retry-After: " & retryAfter & "\r\n"
  result &= "Connection: close\r\nContent-Type: text/plain\r\n\r\nbody"

type
  Codes = array[8, int]
  ServerArg = object
    port:       int
    codes:      Codes
    nCodes:     int
    callCount:  Atomic[int]
    retryAfter: string

# Module-level storage so thread arg is alive until joinThread
var gArg: ServerArg

proc serverThread(arg: ptr ServerArg) {.thread.} =
  var srv = newSocket()
  srv.setSockOpt(OptReuseAddr, true)
  srv.bindAddr(Port(arg[].port))
  srv.listen()
  for i in 0 ..< arg[].nCodes:
    var client: Socket
    try: srv.accept(client)
    except: break
    var buf = newString(8192)
    try: discard client.recv(buf, 8192, timeout = 500)
    except: discard
    client.send(httpResp(arg[].codes[i], arg[].retryAfter))
    client.close()
    discard arg[].callCount.fetchAdd(1)
  srv.close()

var gServerThread: Thread[ptr ServerArg]

proc pickPort(): int =
  var s = newSocket()
  s.setSockOpt(OptReuseAddr, true)
  s.bindAddr(Port(0))
  let p = s.getLocalAddr()[1].int
  s.close()
  p

proc startServer(codes: openArray[int]; retryAfter = ""): string =
  gArg = ServerArg()
  gArg.port = pickPort()
  gArg.nCodes = min(codes.len, 8)
  for i in 0 ..< gArg.nCodes: gArg.codes[i] = codes[i]
  gArg.retryAfter = retryAfter
  gArg.callCount.store(0)
  createThread(gServerThread, serverThread, addr gArg)
  sleep(30)
  result = "http://127.0.0.1:" & $gArg.port & "/test"

proc stopServer() = joinThread(gServerThread)
proc calls(): int = gArg.callCount.load()

# ----- tests -----

block two_oh_oh_no_retry:
  let url = startServer([200])
  let resp = postJson(url, "{}", "")
  assert resp.code.int == 200, "Expected 200, got " & $resp.code.int
  assert calls() == 1, "Expected 1 call, got " & $calls()
  stopServer()

block four_oh_four_no_retry:
  let url = startServer([404])
  let resp = postJson(url, "{}", "")
  assert resp.code.int == 404
  assert calls() == 1, "404 must not retry, got " & $calls() & " calls"
  stopServer()

block five_hundred_not_in_retry_set:
  let url = startServer([500])
  var raised = false
  try: discard postJson(url, "{}", "")
  except IOError: raised = true
  assert raised, "IOError expected on 500"
  assert calls() == 1, "500 not in retry set, got " & $calls()
  stopServer()

block five_oh_two_retries_exhausted:
  let url = startServer([502, 502, 502, 502])
  var raised = false
  try: discard postJson(url, "{}", "")
  except IOError: raised = true
  assert raised, "IOError expected after exhausting 502 retries"
  assert calls() == 4, "Expected 4 calls (1+3 retries) on 502, got " & $calls()
  stopServer()

block four_twenty_nine_retries_exhausted:
  # 429 is retried but is NOT >= 500, so after exhausting retries it returns
  # the final 429 response (logs warning) rather than raising IOError.
  let url = startServer([429, 429, 429, 429])
  let resp = postJson(url, "{}", "")
  assert resp.code.int == 429, "Expected 429 response after retries, got " & $resp.code.int
  assert calls() == 4, "Expected 4 calls on 429, got " & $calls()
  stopServer()

block recovers_on_retry:
  let url = startServer([503, 200])
  let resp = postJson(url, "{}", "")
  assert resp.code.int == 200, "Expected 200 on successful retry, got " & $resp.code.int
  assert calls() == 2, "Expected 2 calls (503 then 200), got " & $calls()
  stopServer()

when isMainModule:
  echo "HTTP client retry tests passed"
