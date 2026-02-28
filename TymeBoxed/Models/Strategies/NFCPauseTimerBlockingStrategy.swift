import SwiftData
import SwiftUI

class NFCPauseTimerBlockingStrategy: BlockingStrategy {
  static var id: String = "NFCPauseTimerBlockingStrategy"

  var name: String = "Focus session with Break"
  var description: String =
    "Set a break duration, scan once for break, and scan again to fully stop."
  var iconType: String = "pause"
  var iconRotation: Angle = .zero
  var color: Color = .orange

  var usesNFC: Bool = true
  var hasTimer: Bool = true
  var hasPauseMode: Bool = false
  var isBeta: Bool = true
  var hidden: Bool = false

  var onSessionCreation: ((SessionStatus) -> Void)?
  var onErrorMessage: ((String) -> Void)?  

  private let nfcScanner: NFCScannerUtil = NFCScannerUtil()
  private let appBlocker: AppBlockerUtil = AppBlockerUtil()
  private let timersUtil: TimersUtil = TimersUtil()

  func getIdentifier() -> String {
    return NFCPauseTimerBlockingStrategy.id
  }

  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)? {
    return PauseDurationView(
      profileName: profile.name,
      onDurationSelected: { pauseDurationMinutes in
        let pauseTimerData = StrategyPauseTimerData(
          pauseDurationInMinutes: pauseDurationMinutes
        )
        if let data = StrategyPauseTimerData.toData(from: pauseTimerData) {
          profile.strategyData = data
          profile.updatedAt = Date()
          BlockedProfiles.updateSnapshot(for: profile)
          try? context.save()
        }

        self.appBlocker.activateRestrictions(for: BlockedProfiles.getSnapshot(for: profile))

        let activeSession = BlockedProfileSession.createSession(
          in: context,
          withTag: NFCPauseTimerBlockingStrategy.id,
          withProfile: profile,
          forceStart: forceStart ?? false
        )

        self.onSessionCreation?(.started(activeSession))
      }
    )
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
    let isPauseActive = session.isPauseActive

    nfcScanner.onTagScanned = { tag in
      let tagId = (tag.url ?? tag.id).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !tagId.isEmpty else { return }

      Task { @MainActor in
        let valid = await AuthenticationManager.shared.isNFCTagValidForUnlock(tagId: tagId)
        guard valid else {
          self.onErrorMessage?(
            "Unregistered device detected. Please switch to a Tyme Box Device."
          )
          return
        }
        if let physicalUnblockNFCTagId = session.blockedProfile.physicalUnblockNFCTagId,
          physicalUnblockNFCTagId != tagId
        {
          self.onErrorMessage?(
            "This NFC tag is not allowed to unblock this profile. Physical unblock setting is on for this profile"
          )
          return
        }

        if isPauseActive {
          self.timersUtil.cancelPauseEndTask(profileId: session.blockedProfile.id.uuidString)
          DeviceActivityCenterUtil.removePauseTimerActivity(for: session.blockedProfile)
          session.endSession()
          try? context.save()
          self.appBlocker.deactivateRestrictions()
          self.onSessionCreation?(.ended(session.blockedProfile))
        } else {
          // First scan: pause and unblock. Timer runs; when it ends, extension re-blocks.
          let pauseStartTime = Date()
          BlockedProfiles.updateSnapshot(for: session.blockedProfile)
          SharedData.resetPause()
          SharedData.setPauseStartTime(date: pauseStartTime)
          session.pauseStartTime = pauseStartTime
          session.pauseEndTime = nil
          try? context.save()
          self.appBlocker.deactivateRestrictions()
          DeviceActivityCenterUtil.startPauseTimerActivity(for: session.blockedProfile)
          let pauseData = session.blockedProfile.strategyData.map {
            StrategyPauseTimerData.toStrategyPauseTimerData(from: $0)
          } ?? StrategyPauseTimerData(pauseDurationInMinutes: 5)
          let endDate = Calendar.current.date(
            byAdding: .minute,
            value: pauseData.pauseDurationInMinutes,
            to: pauseStartTime
          ) ?? pauseStartTime
          self.timersUtil.schedulePauseEndTask(
            profileId: session.blockedProfile.id.uuidString,
            endDate: endDate
          )
          self.onSessionCreation?(.paused)
        }
      }
    }

    if isPauseActive {
      nfcScanner.scan(profileName: session.blockedProfile.name)
    } else {
      nfcScanner.scan(profileName: "\(session.blockedProfile.name) - Pause")
    }

    return nil
  }
}
