import SwiftData
import SwiftUI

class NFCTimerBlockingStrategy: BlockingStrategy {
  static var id: String = "NFCTimerBlockingStrategy"

  var name: String = "Focus Session"
  var description: String = "Set a focus duration, then scan the device to end early."
  var iconType: String = "timer"
  var iconRotation: Angle = .zero
  var color: Color = .mint

  var usesNFC: Bool = true
  var hasTimer: Bool = true
  var isBeta: Bool = false
  var hidden: Bool = false

  var onSessionCreation: ((SessionStatus) -> Void)?
  var onErrorMessage: ((String) -> Void)?

  private let nfcScanner: NFCScannerUtil = NFCScannerUtil()
  private let appBlocker: AppBlockerUtil = AppBlockerUtil()

  func getIdentifier() -> String {
    return NFCTimerBlockingStrategy.id
  }

  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)? {
    return TimerDurationView(
      profileName: profile.name,
      onDurationSelected: { duration in
        if let strategyTimerData = StrategyTimerData.toData(from: duration) {
          // Store the timer data so that its selected for the next time the profile is started
          // This is also useful if the profile is started from the background like a shortcut or intent
          profile.strategyData = strategyTimerData
          profile.updatedAt = Date()
          BlockedProfiles.updateSnapshot(for: profile)
          try? context.save()
        }

        self.appBlocker.activateRestrictions(for: BlockedProfiles.getSnapshot(for: profile))

        let activeSession = BlockedProfileSession.createSession(
          in: context,
          withTag: NFCTimerBlockingStrategy.id,
          withProfile: profile,
          forceStart: forceStart ?? false
        )

        DeviceActivityCenterUtil.startStrategyTimerActivity(for: profile)

        self.onSessionCreation?(.started(activeSession))
      }
    )
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
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
        session.endSession()
        try? context.save()
        self.appBlocker.deactivateRestrictions()
        self.onSessionCreation?(.ended(session.blockedProfile))
      }
    }

    nfcScanner.scan(profileName: session.blockedProfile.name)

    return nil
  }
}
