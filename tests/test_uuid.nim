import std/sets
import doggy/uuid

block uniqueness:
  var seen: HashSet[string]
  for _ in 0 ..< 10_000:
    let id = newUuid4()
    assert id notin seen, "UUID collision: " & id
    seen.incl(id)

block format:
  let id = newUuid4()
  assert id.len == 36, "expected 36 chars, got " & $id.len
  assert id[8]  == '-'
  assert id[13] == '-'
  assert id[18] == '-'
  assert id[23] == '-'

block version:
  for _ in 0 ..< 100:
    let id = newUuid4()
    assert id[14] == '4', "version digit must be 4, got " & $id[14]

block variant:
  for _ in 0 ..< 100:
    let id = newUuid4()
    assert id[19] in {'8', '9', 'a', 'b'},
      "variant nibble must be 8/9/a/b, got " & $id[19]

when isMainModule:
  echo "UUID tests passed"
