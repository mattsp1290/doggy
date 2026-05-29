import std/math, std/strutils

type
  ContainerKind = enum ckObj, ckArr
  JsonBuilder* = object
    buf: string
    stack: seq[ContainerKind]  # stack[^1] is the current container level
    hasField: bool             # whether current level has any elements/fields written

proc newJsonObject*(): JsonBuilder =
  result.buf = "{"
  result.stack = @[ckObj]
  result.hasField = false

proc newJsonArray*(): JsonBuilder =
  result.buf = "["
  result.stack = @[ckArr]
  result.hasField = false

proc newJsonBuilder*(): JsonBuilder = newJsonObject()

# input must be valid UTF-8; bytes >= 0x80 are passed through as raw UTF-8 bytes
proc escapeString(s: string): string =
  result = "\""
  for c in s:
    case c
    of '"':  result.add("\\\"")
    of '\\': result.add("\\\\")
    of '\b': result.add("\\b")
    of '\f': result.add("\\f")
    of '\n': result.add("\\n")
    of '\r': result.add("\\r")
    of '\t': result.add("\\t")
    else:
      if ord(c) < 0x20:
        result.add("\\u00")
        result.add("0123456789abcdef"[ord(c) shr 4])
        result.add("0123456789abcdef"[ord(c) and 0x0f])
      else:
        result.add(c)
  result.add('"')

proc sep(b: var JsonBuilder) =
  if b.hasField:
    b.buf.add(',')
  b.hasField = true

proc writeKey(b: var JsonBuilder, key: string) =
  b.sep()
  b.buf.add(escapeString(key))
  b.buf.add(':')

# --- Object (keyed) adders ---

proc addStr*(b: var JsonBuilder, key, val: string) =
  b.writeKey(key)
  b.buf.add(escapeString(val))

proc addInt*(b: var JsonBuilder, key: string, val: int64) =
  b.writeKey(key)
  b.buf.add($val)

proc addFloat*(b: var JsonBuilder, key: string, val: float64) =
  b.writeKey(key)
  # Non-finite floats are not valid JSON; emit null (JSON has no NaN/Inf)
  if classify(val) in {fcNan, fcInf, fcNegInf}:
    b.buf.add("null")
  else:
    b.buf.add($val)

proc addBool*(b: var JsonBuilder, key: string, val: bool) =
  b.writeKey(key)
  b.buf.add(if val: "true" else: "false")

proc addNull*(b: var JsonBuilder, key: string) =
  b.writeKey(key)
  b.buf.add("null")

proc startObj*(b: var JsonBuilder, key: string) =
  b.writeKey(key)
  b.buf.add('{')
  b.stack.add(ckObj)
  b.hasField = false

proc startArr*(b: var JsonBuilder, key: string) =
  b.writeKey(key)
  b.buf.add('[')
  b.stack.add(ckArr)
  b.hasField = false

# --- Array (bare element) adders ---

proc addRawElem*(b: var JsonBuilder, raw: string) =
  b.sep()
  b.buf.add(raw)

proc addStrElem*(b: var JsonBuilder, val: string) =
  b.sep()
  b.buf.add(escapeString(val))

proc addIntElem*(b: var JsonBuilder, val: int64) =
  b.sep()
  b.buf.add($val)

proc addFloatElem*(b: var JsonBuilder, val: float64) =
  b.sep()
  if classify(val) in {fcNan, fcInf, fcNegInf}:
    b.buf.add("null")
  else:
    b.buf.add($val)

proc addBoolElem*(b: var JsonBuilder, val: bool) =
  b.sep()
  b.buf.add(if val: "true" else: "false")

proc addNullElem*(b: var JsonBuilder) =
  b.sep()
  b.buf.add("null")

proc startObjElem*(b: var JsonBuilder) =
  b.sep()
  b.buf.add('{')
  b.stack.add(ckObj)
  b.hasField = false

proc startArrElem*(b: var JsonBuilder) =
  b.sep()
  b.buf.add('[')
  b.stack.add(ckArr)
  b.hasField = false

# --- Container closers ---

proc endObj*(b: var JsonBuilder) =
  doAssert b.stack.len > 1 and b.stack[^1] == ckObj,
    "endObj called without matching startObj/startObjElem (stack depth=" & $b.stack.len & ")"
  b.buf.add('}')
  discard b.stack.pop()
  b.hasField = true

proc endArr*(b: var JsonBuilder) =
  doAssert b.stack.len > 1 and b.stack[^1] == ckArr,
    "endArr called without matching startArr/startArrElem (stack depth=" & $b.stack.len & ")"
  b.buf.add(']')
  discard b.stack.pop()
  b.hasField = true

proc build*(b: JsonBuilder): string =
  doAssert b.stack.len == 1,
    "build called with unbalanced containers (depth=" & $b.stack.len & ", expected 1)"
  result = b.buf
  result.add(if b.stack[0] == ckArr: ']' else: '}')

proc toNdjson*(lines: seq[string]): string =
  lines.join("\n")
