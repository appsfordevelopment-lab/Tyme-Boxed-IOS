import DeviceActivity
import OSLog

private let log = Logger(subsystem: "com.timeboxed.monitor", category: PauseTimerActivity.id)

class PauseTimerActivity: TimerActivity {
  static var id: String = "PauseScheduleActivity"

  private let appBlocker = AppBlockerUtil()

  func getDeviceActivityName(from profileId: String) -> DeviceActivityName {
    return DeviceActivityName(rawValue: "\(PauseTimerActivity.id):\(profileId)")
  }

  func getAllPauseTimerActivities(from activities: [DeviceActivityName]) -> [DeviceActivityName] {
    return activities.filter { $0.rawValue.starts(with: PauseTimerActivity.id) }
  }

  func start(for profile: SharedData.ProfileSnapshot) {
    let profileId = profile.id.uuidString

    guard let activeSession = SharedData.getActiveSharedSession() else {
      log.info("Start pause timer activity for \(profileId), no active session found")
      return
    }

    if activeSession.blockedProfileId != profile.id {
      log.info(
        "Start pause timer activity for \(profileId), active session profile does not match profile to start pause"
      )
      return
    }

    appBlocker.deactivateRestrictions()

    let now = Date()
    SharedData.resetPause()
    SharedData.setPauseStartTime(date: now)

    log.info("Started pause for profile \(profileId)")
  }

  func stop(for profile: SharedData.ProfileSnapshot) {
    let profileId = profile.id.uuidString

    // When intervalDidEnd fires for a Pause activity, the schedule is the source of truth:
    // the pause period has ended. Re-block even if SharedData is stale (e.g. app was
    // force-killed before pauseStartTime was persisted). Only skip if we know the user
    // already ended the pause (pauseEndTime set) or if active session is for a different profile.
    if let activeSession = SharedData.getActiveSharedSession() {
      if activeSession.blockedProfileId != profile.id {
        log.info(
          "Stop pause timer activity for \(profileId), active session profile does not match"
        )
        return
      }
      if activeSession.pauseEndTime != nil {
        log.info("Stop pause timer activity for \(profileId), pause already ended (early NFC scan)")
        return
      }
    }

    appBlocker.activateRestrictions(for: profile)

    // Avoid UserDefaults write here - it can cause extension to terminate early (iOS 17+).
    // Main app reconciles when it opens: syncScheduleSessions + Timer fallback will
    // detect overdue pause and update SharedData/SwiftData.

    log.info("Ended pause for profile \(profileId)")
  }
}
