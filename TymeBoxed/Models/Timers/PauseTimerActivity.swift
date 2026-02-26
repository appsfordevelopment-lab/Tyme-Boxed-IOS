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

    guard let activeSession = SharedData.getActiveSharedSession() else {
      log.info("Stop pause timer activity for \(profileId), no active session found")
      return
    }

    if activeSession.blockedProfileId != profile.id {
      log.info(
        "Stop pause timer activity for \(profileId), active session profile does not match profile to start pause"
      )
      return
    }

    if activeSession.pauseStartTime != nil && activeSession.pauseEndTime == nil {
      appBlocker.activateRestrictions(for: profile)

      let now = Date()
      SharedData.setPauseEndTime(date: now)
    }

    log.info("Ended pause for profile \(profileId)")
  }
}
