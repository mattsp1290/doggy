## EventsClient unit tests using a thread-based TCP responder.
##
## EventsClient.send() builds its URL from config.site, so we test
## the HTTP transport layer (postJson) directly for mock-server cases,
## and verify EventsClient itself doesn't raise on unreachable endpoints.

import std/[net, os, atomics, json, httpclient]
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
  except: srv.close(); return
  var buf = newString(8192)
  try: discard cl.recv(buf, 8192, timeout = 1000)
  except: discard
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

# ----- tests -----

block post_json_2xx_succeeds:
  # Verify the HTTP layer accepts a 202 (Datadog's typical events response).
  let url = startServer(202)
  let ev = DdEvent(title: "test", text: "body", alertType: datInfo)
  let resp = postJson(url & "/api/v2/events", ev.toJson(), "fakekey")
  assert resp.code.int == 202, "Expected 202, got " & $resp.code.int
  assert calls() == 1
  stopServer()

block post_json_4xx_returns_response:
  # 4xx responses return the code rather than raising.
  let url = startServer(403)
  let ev = DdEvent(title: "err", text: "x", alertType: datError)
  let resp = postJson(url & "/api/v2/events", ev.toJson(), "badkey")
  assert resp.code.int == 403
  assert calls() == 1
  stopServer()

block send_never_raises:
  # EventsClient targeting an unreachable endpoint must not raise.
  let cfg = EventsConfig(apiKey: "k", site: SiteUS1)
  let ec = newEventsClient(cfg)
  var raised = false
  try:
    discard ec.send(DdEvent(title: "x", text: "y", alertType: datInfo))
  except:
    raised = true
  assert not raised, "EventsClient.send must never raise"

block event_json_is_valid:
  # Verify the JSON body is well-formed for a fully-populated event.
  let ev = DdEvent(
    title:          "Deploy",
    text:           "v1 shipped",
    alertType:      datSuccess,
    dateHappened:   1_700_000_000'i64,
    tags:           @["env:prod"],
    sourceTypeName: "ci",
  )
  let parsed = ev.toJson().parseJson()
  assert parsed["title"].getStr()       == "Deploy"
  assert parsed["text"].getStr()        == "v1 shipped"
  assert parsed["alert_type"].getStr()  == "success"
  assert parsed["date_happened"].getInt() == 1_700_000_000
  assert parsed["tags"][0].getStr()     == "env:prod"
  assert parsed["source_type_name"].getStr() == "ci"

when isMainModule:
  echo "Events client tests passed"
