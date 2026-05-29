import std/monotimes
import doggy/rum/session

proc nowMs(): int64 = getMonoTime().ticks div 1_000_000

block init_generates_distinct_ids:
  var s: RumSession
  initRumSession(s)
  let sid = s.sessionId()
  let vid = s.currentViewId()
  assert sid.len == 36, "sessionId must be UUID format"
  assert vid.len == 36, "viewId must be UUID format"
  assert sid != vid, "sessionId and viewId must differ"
  deinitRumSession(s)

block new_view_changes_view_id_not_session_id:
  var s: RumSession
  initRumSession(s)
  let origSession = s.sessionId()
  let origView    = s.currentViewId()
  let newVid      = s.newView()
  assert s.sessionId() == origSession, "sessionId must not change on newView"
  assert s.currentViewId() != origView, "currentViewId must change on newView"
  assert s.currentViewId() == newVid, "newView return value must match stored viewId"
  deinitRumSession(s)

block fresh_session_not_expired:
  var s: RumSession
  initRumSession(s)
  # pass nowMs = slightly in the future but well within limits
  assert not s.isExpired(nowMs() + 60_000), "session 1 min old must not be expired"
  deinitRumSession(s)

block inactivity_expiry:
  var s: RumSession
  initRumSession(s)
  # inject nowMs 16 minutes after init (> 15 min inactivity threshold)
  let simNow = nowMs() + 16 * 60 * 1000
  assert s.isExpired(simNow), "session 16 min idle must be expired"
  deinitRumSession(s)

block max_duration_expiry:
  var s: RumSession
  initRumSession(s)
  # inject nowMs 4h+1ms after init (> 4h max duration)
  let simNow = nowMs() + 4 * 60 * 60 * 1000 + 1
  assert s.isExpired(simNow), "session older than 4h must be expired"
  deinitRumSession(s)

block not_expired_within_limits:
  var s: RumSession
  initRumSession(s)
  let simNow = nowMs() + 10 * 60 * 1000  # 10 min — within both limits
  assert not s.isExpired(simNow), "session 10 min old must not be expired"
  deinitRumSession(s)

block new_session_resets_both_ids:
  var s: RumSession
  initRumSession(s)
  let origSession = s.sessionId()
  let origView    = s.currentViewId()
  s.newSession()
  assert s.sessionId() != origSession, "sessionId must change on newSession"
  assert s.currentViewId() != origView, "currentViewId must change on newSession"
  deinitRumSession(s)

when isMainModule:
  echo "RUM session tests passed"
