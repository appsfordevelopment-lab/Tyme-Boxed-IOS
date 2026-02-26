import SwiftData
import SwiftUI

class NFCBlockingStrategy: BlockingStrategy {
  static var id: String = "NFCBlockingStrategy"

  var name: String = "NFC Tags"
  var description: String =
    "Block and unblock profiles by using the exact same NFC tag"
  var iconType: String = "wave.3.right.circle.fill"
  var color: Color = .yellow

  var usesNFC: Bool = true
  var hidden: Bool = false

  var onSessionCreation: ((SessionStatus) -> Void)?
  var onErrorMessage: ((String) -> Void)?

  private let nfcScanner: NFCScannerUtil = NFCScannerUtil()
  private let appBlocker: AppBlockerUtil = AppBlockerUtil()

  func getIdentifier() -> String {
    return NFCBlockingStrategy.id
  }

  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)? {
    let profileId = profile.id
    let profileName = profile.name
    let forceStartValue = forceStart ?? false

    nfcScanner.onTagScanned = { tag in
      let tagId = tag.url ?? tag.id

      Task {
        let valid = await AuthenticationManager.shared.isNFCTagValidForUnlock(tagId: tagId)
        await MainActor.run {
          guard valid else {
            self.onErrorMessage?(
              "Unregistered device detected. Please switch to a Tyme Box Device."
            )
            return
          }
          guard let context = SharedModelContainer.shared?.mainContext,
                let profile = try? BlockedProfiles.findProfile(byID: profileId, in: context)
          else {
            return
          }
          self.appBlocker.activateRestrictions(for: BlockedProfiles.getSnapshot(for: profile))
          let activeSession =
            BlockedProfileSession
            .createSession(
              in: context,
              withTag: tagId,
              withProfile: profile,
              forceStart: forceStartValue
            )
          self.onSessionCreation?(.started(activeSession))
        }
      }
    }

    nfcScanner.scan(profileName: profileName)

    return nil
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
    let sessionId = session.id
    let profileName = session.blockedProfile.name

    nfcScanner.onTagScanned = { tag in
      let tagId = tag.url ?? tag.id

      Task {
        let valid = await AuthenticationManager.shared.isNFCTagValidForUnlock(tagId: tagId)
        await MainActor.run {
          guard valid else {
            self.onErrorMessage?(
              "Unregistered device detected. Please switch to a Tyme Box Device."
            )
            return
          }
          guard let context = SharedModelContainer.shared?.mainContext,
                let session = try? BlockedProfileSession.findSession(byID: sessionId, in: context)
          else {
            return
          }
          if let physicalUnblockNFCTagId = session.blockedProfile.physicalUnblockNFCTagId {
            if physicalUnblockNFCTagId != tagId {
              self.onErrorMessage?(
                "This NFC tag is not allowed to unblock this profile. Physical unblock setting is on for this profile"
              )
              return
            }
          } else if !session.forceStarted && session.tag != tagId {
            self.onErrorMessage?(
              "You must scan the original tag to stop focus"
            )
            return
          }
          let profile = session.blockedProfile
          session.endSession()
          try? context.save()
          self.appBlocker.deactivateRestrictions()
          self.onSessionCreation?(.ended(profile))
        }
      }
    }

    nfcScanner.scan(profileName: profileName)

    return nil
  }
}
