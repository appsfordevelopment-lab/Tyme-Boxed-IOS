import SwiftData
import SwiftUI

enum SessionStatus {
  case started(BlockedProfileSession)
  case ended(BlockedProfiles)
  case paused
}

protocol BlockingStrategy {
  static var id: String { get }
  var name: String { get }
  var description: String { get }
  var iconType: String { get }
  var iconRotation: Angle { get }
  var color: Color { get }

  var usesNFC: Bool { get }
  var hasTimer: Bool { get }
  var hasPauseMode: Bool { get }
  var hasManual: Bool { get }
  var isBeta: Bool { get }
  var hidden: Bool { get }

  // Callback closures session creation
  var onSessionCreation: ((SessionStatus) -> Void)? {
    get set
  }

  var onErrorMessage: ((String) -> Void)? {
    get set
  }

  func getIdentifier() -> String
  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)?
  func stopBlocking(context: ModelContext, session: BlockedProfileSession)
    -> (any View)?
}

enum BlockingStrategyTag: String, Hashable {
  case nfc
  case timer
  case pause
  case manual
  case beta

  var title: String {
    switch self {
    case .nfc:
      return "Device"
    case .timer:
      return "Timer"
    case .pause:
      return "Pause"
    case .manual:
      return "Manual"
    case .beta:
      return "Break"
    }
  }
}

extension BlockingStrategy {
  var iconRotation: Angle { .zero }
  var usesNFC: Bool { false }
  var hasTimer: Bool { false }
  var hasPauseMode: Bool { false }
  var hasManual: Bool { false }
  var isBeta: Bool { false }

  var tags: [BlockingStrategyTag] {
    var result: [BlockingStrategyTag] = []
    if usesNFC { result.append(.nfc) }
    if hasTimer { result.append(.timer) }
    if hasPauseMode { result.append(.pause) }
    if hasManual { result.append(.manual) }
    if isBeta { result.append(.beta) }
    return result
  }
}
