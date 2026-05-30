## Helpers to populate RumDeviceInfo and RumOsInfo from the host system.
## Each proc uses osproc to query system tools — call once at startup.

import std/[osproc, strutils]
import doggy/rum/types

proc getMacOsInfo*(): RumOsInfo =
  ## Returns RumOsInfo populated from sw_vers on macOS.
  let version = execCmdEx("sw_vers -productVersion").output.strip()
  let build   = execCmdEx("sw_vers -buildVersion").output.strip()
  let major   = if '.' in version: version.split('.')[0] else: version
  RumOsInfo(
    osType:       "macos",
    name:         "macOS",
    version:      version,
    versionMajor: major,
    build:        build,
  )

proc getMacDeviceInfo*(): RumDeviceInfo =
  ## Returns RumDeviceInfo from system_profiler on macOS.
  let info = execCmdEx(
    "system_profiler SPHardwareDataType").output
  var name  = "Mac"
  var model = ""
  for line in info.splitLines():
    let stripped = line.strip()
    if stripped.startsWith("Model Name:"):
      name  = stripped[11..^1].strip()
    elif stripped.startsWith("Model Identifier:"):
      model = stripped[17..^1].strip()
  RumDeviceInfo(
    deviceType:   "desktop",
    name:         name,
    model:        model,
    brand:        "Apple",
    architecture: "arm64",
  )
