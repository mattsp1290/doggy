import std/locks, std/monotimes
import doggy/uuid

const
  SessionMaxDurationMs = 4 * 60 * 60 * 1000  # 4 hours
  SessionInactivityMs  = 15 * 60 * 1000       # 15 minutes

type RumSession* = object
  sessionIdField:      string  # private — use sessionId() accessor
  currentViewIdField:  string  # private — use currentViewId() accessor
  sessionStartMs:      int64   # monotonic ms since session began
  lastActivityMs:      int64   # monotonic ms of last activity
  lock:                Lock

proc `=copy`*(dst: var RumSession; src: RumSession) {.error:
  "RumSession owns a Lock and must not be copied; pass by var".}

proc monoMs(): int64 =
  getMonoTime().ticks div 1_000_000  # MonoTime ticks are nanoseconds

proc initRumSession*(session: var RumSession) =
  initLock(session.lock)
  let now = monoMs()
  session.sessionIdField     = newUuid4()
  session.currentViewIdField = newUuid4()
  session.sessionStartMs     = now
  session.lastActivityMs     = now

proc deinitRumSession*(session: var RumSession) =
  deinitLock(session.lock)

# Locked read accessors — safe for cross-thread access
proc sessionId*(session: var RumSession): string =
  withLock(session.lock): result = session.sessionIdField

proc currentViewId*(session: var RumSession): string =
  withLock(session.lock): result = session.currentViewIdField

proc touch*(session: var RumSession) =
  withLock(session.lock):
    session.lastActivityMs = monoMs()

proc isExpired*(session: var RumSession; nowMs: int64 = monoMs()): bool =
  withLock(session.lock):
    let totalAge   = nowMs - session.sessionStartMs
    let inactivity = nowMs - session.lastActivityMs
    result = totalAge >= SessionMaxDurationMs or inactivity >= SessionInactivityMs

proc newView*(session: var RumSession): string =
  withLock(session.lock):
    session.currentViewIdField = newUuid4()
    session.lastActivityMs     = monoMs()
    result = session.currentViewIdField

proc newSession*(session: var RumSession) =
  withLock(session.lock):
    let now = monoMs()
    session.sessionIdField     = newUuid4()
    session.currentViewIdField = newUuid4()
    session.sessionStartMs     = now
    session.lastActivityMs     = now
