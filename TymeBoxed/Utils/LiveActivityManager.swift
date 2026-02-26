import ActivityKit
import Foundation
import SwiftUI

class LiveActivityManager: ObservableObject {
  // Published property for live activity reference
  @Published var currentActivity: Activity<TymeBoxedWidgetAttributes>?

  // Use AppStorage for persisting the activity ID across app launches
  @AppStorage("com.timeboxed.currentActivityId") private var storedActivityId: String = ""

  static let shared = LiveActivityManager()

  private init() {
    // Try to restore existing activity on initialization
    restoreExistingActivity()
  }

  private var isSupported: Bool {
    if #available(iOS 16.1, *) {
      return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    return false
  }

  // Save activity ID using AppStorage
  private func saveActivityId(_ id: String) {
    storedActivityId = id
  }

  // Remove activity ID from AppStorage
  private func removeActivityId() {
    storedActivityId = ""
  }

  // Restore existing activity from system if available
  private func restoreExistingActivity() {
    guard isSupported else { return }

    // Check if we have a saved activity ID
    if !storedActivityId.isEmpty {
      if let existingActivity = Activity<TymeBoxedWidgetAttributes>.activities.first(where: {
        $0.id == storedActivityId
      }) {
        // Found the existing activity
        self.currentActivity = existingActivity
        print("Restored existing Live Activity with ID: \(existingActivity.id)")
      } else {
        // The activity no longer exists, clean up the stored ID
        print("No existing activity found with saved ID, removing reference")
        removeActivityId()
      }
    }
  }

  func startSessionActivity(session: BlockedProfileSession) {
    // Check if Live Activities are supported
    guard isSupported else {
      print("Live Activities are not supported on this device")
      return
    }

    // Check if we can restore an existing activity first
    if currentActivity == nil {
      restoreExistingActivity()
    }

    // Check if we already have an activity running
    if currentActivity != nil {
      print("Live Activity is already running, will update instead")
      updateSessionActivity(session: session)
      return
    }

    if session.blockedProfile.enableLiveActivity == false {
      print("Activity is disabled for profile")
      return
    }

    // Create and start the activity
    let profileName = session.blockedProfile.name
    let message = FocusMessages.getRandomMessage()
    let attributes = TymeBoxedWidgetAttributes(name: profileName, message: message)
    let contentState = TymeBoxedWidgetAttributes.ContentState(
      startTime: session.startTime,
      isBreakActive: session.isBreakActive,
      breakStartTime: session.breakStartTime,
      breakEndTime: session.breakEndTime,
      isPauseActive: session.isPauseActive,
      pauseStartTime: session.pauseStartTime,
      pauseDurationInMinutes: getPauseDuration(from: session)
    )

    do {
      let content = ActivityContent(state: contentState, staleDate: nil)
      let activity = try Activity.request(
        attributes: attributes,
        content: content
      )
      currentActivity = activity

      saveActivityId(activity.id)
      print("Started Live Activity with ID: \(activity.id) for profile: \(profileName)")
      return
    } catch {
      print("Error starting Live Activity: \(error.localizedDescription)")
      return
    }
  }

  func updateSessionActivity(session: BlockedProfileSession) {
    guard let activity = currentActivity else {
      print("No Live Activity to update")
      return
    }

    let updatedState = TymeBoxedWidgetAttributes.ContentState(
      startTime: session.startTime,
      isBreakActive: session.isBreakActive,
      breakStartTime: session.breakStartTime,
      breakEndTime: session.breakEndTime,
      isPauseActive: session.isPauseActive,
      pauseStartTime: session.pauseStartTime,
      pauseDurationInMinutes: getPauseDuration(from: session)
    )

    Task {
      let content = ActivityContent(state: updatedState, staleDate: nil)
      await activity.update(content)
      print("Updated Live Activity with ID: \(activity.id)")
    }
  }

  func updatePauseState(session: BlockedProfileSession) {
    guard let activity = currentActivity else {
      print("No Live Activity to update for pause state")
      return
    }

    let updatedState = TymeBoxedWidgetAttributes.ContentState(
      startTime: session.startTime,
      isBreakActive: session.isBreakActive,
      breakStartTime: session.breakStartTime,
      breakEndTime: session.breakEndTime,
      isPauseActive: session.isPauseActive,
      pauseStartTime: session.pauseStartTime,
      pauseDurationInMinutes: getPauseDuration(from: session)
    )

    Task {
      let content = ActivityContent(state: updatedState, staleDate: nil)
      await activity.update(content)
      print("Updated Live Activity pause state: \(session.isPauseActive)")
    }
  }

  private func getPauseDuration(from session: BlockedProfileSession) -> Int? {
    guard let data = session.blockedProfile.strategyData else { return nil }
    let pauseData = StrategyPauseTimerData.toStrategyPauseTimerData(from: data)
    return pauseData.pauseDurationInMinutes
  }

  func updateBreakState(session: BlockedProfileSession) {
    guard let activity = currentActivity else {
      print("No Live Activity to update for break state")
      return
    }

    let updatedState = TymeBoxedWidgetAttributes.ContentState(
      startTime: session.startTime,
      isBreakActive: session.isBreakActive,
      breakStartTime: session.breakStartTime,
      breakEndTime: session.breakEndTime,
      isPauseActive: session.isPauseActive,
      pauseStartTime: session.pauseStartTime,
      pauseDurationInMinutes: getPauseDuration(from: session)
    )

    Task {
      let content = ActivityContent(state: updatedState, staleDate: nil)
      await activity.update(content)
      print("Updated Live Activity break state: \(session.isBreakActive)")
    }
  }

  func endSessionActivity() {
    guard let activity = currentActivity else {
      print("No Live Activity to end")
      return
    }

    // End the activity
    let completedState = TymeBoxedWidgetAttributes.ContentState(
      startTime: Date.now
    )
    let content = ActivityContent(state: completedState, staleDate: nil)

    Task {
      await activity.end(content, dismissalPolicy: .immediate)
      print("Ended Live Activity")
    }

    // Remove the stored activity ID when ending the activity
    removeActivityId()
    currentActivity = nil
  }
}
