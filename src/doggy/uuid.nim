import std/sysrand

proc newUuid4*(): string =
  var bytes: array[16, byte]
  if not urandom(bytes):
    raise newException(OSError, "urandom failed to provide entropy for UUID generation")

  # Set version 4 bits: top nibble of byte 6 = 0100
  bytes[6] = (bytes[6] and 0x0f'u8) or 0x40'u8
  # Set variant bits: top two bits of byte 8 = 10
  bytes[8] = (bytes[8] and 0x3f'u8) or 0x80'u8

  result = newStringOfCap(36)
  for i, b in bytes:
    if i in [4, 6, 8, 10]:
      result.add('-')
    result.add("0123456789abcdef"[b shr 4])
    result.add("0123456789abcdef"[b and 0x0f])
