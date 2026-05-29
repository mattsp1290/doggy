type JsonBuilder* = object
  buf: string
  hasField: bool  # whether current object/array level has any fields written

proc newJsonBuilder*(): JsonBuilder =
  result.buf = "{"
  result.hasField = false

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

proc writeKey(b: var JsonBuilder, key: string) =
  if b.hasField:
    b.buf.add(',')
  b.buf.add(escapeString(key))
  b.buf.add(':')
  b.hasField = true

proc addStr*(b: var JsonBuilder, key, val: string) =
  b.writeKey(key)
  b.buf.add(escapeString(val))

proc addInt*(b: var JsonBuilder, key: string, val: int64) =
  b.writeKey(key)
  b.buf.add($val)

proc addFloat*(b: var JsonBuilder, key: string, val: float64) =
  b.writeKey(key)
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
  b.hasField = false

proc endObj*(b: var JsonBuilder) =
  b.buf.add('}')
  b.hasField = true

proc startArr*(b: var JsonBuilder, key: string) =
  b.writeKey(key)
  b.buf.add('[')
  b.hasField = false

proc endArr*(b: var JsonBuilder) =
  b.buf.add(']')
  b.hasField = true

proc build*(b: JsonBuilder): string =
  b.buf & "}"

proc toNdjson*(lines: seq[string]): string =
  var first = true
  for line in lines:
    if not first:
      result.add('\n')
    result.add(line)
    first = false
