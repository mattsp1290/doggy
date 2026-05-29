## EventsClient unit tests using a thread-based TCP responder.
##
## All tests are hermetic: the mock TCP server runs in-process on a loopback
## address. EventsClient is pointed at it via the baseUrl constructor parameter,
## which overrides the site-derived URL in production use.

import std/[net, os, atomics, httpclient]
import doggy/events/types, doggy/events/client
import doggy/http_client
import doggy/site

# ----- minimal TCP responder -----

proc httpResp(code: int): string =
  let statusText = case code
    of 200: "OK"
    of 202: "Accepted"
    of 400: "Bad Request"
    of 403: "Forbidden"
    of 500: "Internal Server Error"
    else:   "Status"
  result = "HTTP/1.1 " & $code & " " & statusText &
           "\r\nContent-Length: 4\r\nConnection: close\r\n\r\nbody"

type
  ServerArg = object
    port:      int
    code:      int
    callCount: Atomic[int]

var gArg: ServerArg
var gServerThread: Thread[ptr ServerArg]

proc serverThread(arg: ptr ServerArg) {.thread.} =
  var srv = newSocket()
  srv.setSockOpt(OptReuseAddr, true)
  srv.bindAddr(Port(arg[].port))
  srv.listen()
  var cl: Socket
  try: srv.accept(cl)
  except CatchableError: srv.close(); return
  var buf = newString(8192)
  try: discard cl.recv(buf, 8192, timeout = 1000)
  except CatchableError: discard
  cl.send(httpResp(arg[].code))
  cl.close()
  discard arg[].callCount.fetchAdd(1)
  srv.close()

proc pickPort(): int =
  var s = newSocket()
  s.setSockOpt(OptReuseAddr, true)
  s.bindAddr(Port(0))
  let p = s.getLocalAddr()[1].int
  s.close()
  p

proc startServer(code: int): string =
  gArg = ServerArg()
  gArg.port = pickPort()
  gArg.code = code
  gArg.callCount.store(0)
  createThread(gServerThread, serverThread, addr gArg)
  sleep(30)
  "http://127.0.0.1:" & $gArg.port

proc stopServer() = joinThread(gServerThread)
proc calls(): int = gArg.callCount.load()

# ----- EventsClient.send() tests (via baseUrl injection) -----

block send_returns_true_on_2xx:
  # send() must return true when the server responds 202 (Datadog's typical response).
  let url = startServer(202)
  let ec = newEventsClient(EventsConfig(apiKey: "fakekey", site: SiteUS1), url)
  assert ec.send(DdEvent(title: "t", text: "x", alertType: datInfo)),
    "send() must return true on 2xx"
  assert calls() == 1
  stopServer()

block send_returns_false_on_4xx:
  # send() must return false (not raise) when the server responds 403.
  let url = startServer(403)
  let ec = newEventsClient(EventsConfig(apiKey: "badkey", site: SiteUS1), url)
  assert not ec.send(DdEvent(title: "t", text: "x", alertType: datError)),
    "send() must return false on 4xx"
  assert calls() == 1
  stopServer()

block send_swallows_5xx_no_raise:
  # postJson raises IOError on 5xx; send() must catch it and return false.
  # 500 is not in the retry set, so the responder answers exactly one request.
  let url = startServer(500)
  let ec = newEventsClient(EventsConfig(apiKey: "k", site: SiteUS1), url)
  var raised = false
  var ok = true
  try: ok = ec.send(DdEvent(title: "t", text: "x", alertType: datInfo))
  except CatchableError: raised = true
  assert not raised, "send() must not raise on 5xx"
  assert not ok, "send() must return false on 5xx"
  stopServer()

# ----- postJson transport layer tests -----

block post_json_2xx_succeeds:
  # Verify the HTTP layer accepts a 202 response directly via postJson.
  let url = startServer(202)
  let ev = DdEvent(title: "test", text: "body", alertType: datInfo)
  let resp = postJson(url & "/api/v2/events", ev.toJson(), "fakekey")
  assert resp.code.int == 202, "Expected 202, got " & $resp.code.int
  assert calls() == 1
  stopServer()

block post_json_4xx_returns_response:
  # 4xx responses are returned (not raised) by postJson.
  let url = startServer(403)
  let ev = DdEvent(title: "err", text: "x", alertType: datError)
  let resp = postJson(url & "/api/v2/events", ev.toJson(), "badkey")
  assert resp.code.int == 403
  assert calls() == 1
  stopServer()

when isMainModule:
  echo "Events client tests passed"
