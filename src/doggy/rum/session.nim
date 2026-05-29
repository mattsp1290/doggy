import std/locks, std/times
import doggy/uuid

const
  SessionMaxDurationMs  = 4 * 60 * 60 * 1000  # 4 hours
  SessionInactivityMs   = 15 * 60 * 1000       # 15 minutes

type RumSession* = object
  sessionId*:      string
  currentViewId*:  string
  sessionStartMs:  int64  # epoch ms when session began
  lastActivityMs:  int64  # epoch ms of last touch
  lock:            Lock

proc epochMs(): int64 =
  int64(epochTime() * 1000)

proc initRumSession*(session: var RumSession) =
  initLock(session.lock)
  let now = epochMs()
  session.sessionId     = newUuid4()
  session.currentViewId = newUuid4()
  session.sessionStartMs = now
  session.lastActivityMs = now

proc deinitRumSession*(session: var RumSession) =
  deinitLock(session.lock)

proc touch*(session: var RumSession) =
  withLock(session.lock):
    session.lastActivityMs = epochMs()

proc isExpired*(session: var RumSession): bool =
  withLock(session.lock):
    let now = epochMs()
    let totalAge  = now - session.sessionStartMs
    let inactivity = now - session.lastActivityMs
    result = totalAge >= SessionMaxDurationMs or inactivity >= SessionInactivityMs

proc newView*(session: var RumSession): string =
  withLock(session.lock):
    session.currentViewId = newUuid4()
    session.lastActivityMs = epochMs()
    result = session.currentViewId

proc newSession*(session: var RumSession) =
  withLock(session.lock):
    let now = epochMs()
    session.sessionId      = newUuid4()
    session.currentViewId  = newUuid4()
    session.sessionStartMs = now
    session.lastActivityMs = now
