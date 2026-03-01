import BackgroundTasks
import Foundation
import UserNotifications

// MARK: - Notification Constants
extension Notification.Name {
  static let strategyManagerPauseEnded = Notification.Name("StrategyManagerPauseEnded")

  fileprivate static let backgroundTaskExecuted = Notification.Name(
    "BackgroundTaskExecuted"
  )
}

/// Represents the result of a notification request
enum NotificationResult {
  case success
  case failure(Error?)

  var succeeded: Bool {
    if case .success = self {
      return true
    }
    return false
  }
}

class TimersUtil {
  // Constants for background task identifiers
  static let backgroundProcessingTaskIdentifier =
    "com.timeboxed.backgroundprocessing"
  static let pauseEndRecoveryTaskIdentifier = "com.timeboxed.pauseendrecovery"
  static let backgroundTaskUserDefaultsKey = "com.timeboxed.backgroundtasks"
  private static let backgroundTasksSuite = UserDefaults(
    suiteName: "group.dev.ambitionsoftware.tymeboxed"
  ) ?? .standard

  private var backgroundTasks: [String: [String: Any]] {
    get {
      Self.backgroundTasksSuite.dictionary(
        forKey: Self.backgroundTaskUserDefaultsKey
      )
        as? [String: [String: Any]] ?? [:]
    }
    set {
      Self.backgroundTasksSuite.set(
        newValue,
        forKey: Self.backgroundTaskUserDefaultsKey
      )
    }
  }

  // Register background tasks with the system - call this in app launch
  static func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: backgroundProcessingTaskIdentifier,
      using: nil
    ) { task in
      guard let processingTask = task as? BGProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      Self.handleBackgroundProcessingTask(processingTask)
    }

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: pauseEndRecoveryTaskIdentifier,
      using: nil
    ) { task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      Self.handlePauseEndRecoveryTask(refreshTask)
    }
  }

  private static func handlePauseEndRecoveryTask(_ task: BGAppRefreshTask) {
    let timerUtil = TimersUtil()
    let appBlocker = AppBlockerUtil()
    var didReBlock = false
    var needsReschedule = false
    var nextCheckDate: Date?

    for (taskId, taskInfo) in timerUtil.backgroundTasks {
      guard let pauseProfileId = taskInfo["pauseProfileId"] as? String,
        let executionTime = taskInfo["executionTime"] as? Date
      else {
        continue
      }

      if executionTime <= Date() {
        if let profile = SharedData.snapshot(for: pauseProfileId),
          SharedData.getActiveSharedSession()?.pauseEndTime == nil
        {
          SharedData.setPauseEndTime(date: Date())
          appBlocker.activateRestrictions(for: profile)
          DeviceActivityCenterUtil.removePauseTimerActivity(forProfileId: pauseProfileId)
          var tasks = timerUtil.backgroundTasks
          tasks.removeValue(forKey: taskId)
          timerUtil.backgroundTasks = tasks
          NotificationCenter.default.post(name: .strategyManagerPauseEnded, object: nil)
          print("[PauseTimer] BGAppRefresh re-blocked after pause ended for profile \(pauseProfileId)")
          didReBlock = true
          break
        }
      } else {
        needsReschedule = true
        if nextCheckDate == nil || executionTime < nextCheckDate! {
          nextCheckDate = executionTime
        }
      }
    }

    if needsReschedule, let next = nextCheckDate, !didReBlock {
      let oneMinuteFromNow = Date().addingTimeInterval(60)
      let scheduleDate = next < oneMinuteFromNow ? next : oneMinuteFromNow
      let request = BGAppRefreshTaskRequest(identifier: Self.pauseEndRecoveryTaskIdentifier)
      request.earliestBeginDate = scheduleDate
      do {
        try BGTaskScheduler.shared.submit(request)
        print("[PauseTimer] BGAppRefresh rescheduled for \(scheduleDate)")
      } catch {
        print("[PauseTimer] Could not reschedule BGAppRefresh: \(error)")
      }
    }

    task.setTaskCompleted(success: didReBlock)
  }

  static let pauseEndTaskPrefix = "pauseEnd:"

  private static func handleBackgroundProcessingTask(_ task: BGProcessingTask) {
    let timerUtil = TimersUtil()
    let appBlocker = AppBlockerUtil()

    // Get all pending tasks from UserDefaults
    let tasks = timerUtil.backgroundTasks
    var completedTaskIds: [String] = []
    var hasExecutedTasks = false

    for (taskId, taskInfo) in tasks {
      guard let executionTime = taskInfo["executionTime"] as? Date,
        executionTime <= Date()
      else {
        continue
      }

      if let pauseProfileId = taskInfo["pauseProfileId"] as? String {
        if let profile = SharedData.snapshot(for: pauseProfileId),
          SharedData.getActiveSharedSession()?.pauseEndTime == nil
        {
          SharedData.setPauseEndTime(date: Date())
          appBlocker.activateRestrictions(for: profile)
          DeviceActivityCenterUtil.removePauseTimerActivity(forProfileId: pauseProfileId)
          NotificationCenter.default.post(
            name: .strategyManagerPauseEnded,
            object: nil
          )
          print("[PauseTimer] Background task re-blocked after pause ended for profile \(pauseProfileId)")
        }
      } else if let notificationId = taskInfo["notificationId"] as? String {
        timerUtil.cancelNotification(identifier: notificationId)
        NotificationCenter.default.post(
          name: .backgroundTaskExecuted,
          object: nil,
          userInfo: ["taskId": taskId]
        )
      } else {
        NotificationCenter.default.post(
          name: .backgroundTaskExecuted,
          object: nil,
          userInfo: ["taskId": taskId]
        )
      }

      completedTaskIds.append(taskId)
      hasExecutedTasks = true
    }

    // Remove completed tasks
    var updatedTasks = tasks
    for taskId in completedTaskIds {
      updatedTasks.removeValue(forKey: taskId)
    }
    timerUtil.backgroundTasks = updatedTasks

    // Schedule next background task if needed
    if !updatedTasks.isEmpty {
      timerUtil.scheduleBackgroundProcessing()
    }

    task.setTaskCompleted(success: hasExecutedTasks)
  }

  // Schedule a background processing task
  func scheduleBackgroundProcessing() {
    let request = BGProcessingTaskRequest(
      identifier: Self.backgroundProcessingTaskIdentifier
    )
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false

    // Find the earliest task execution time
    var earliestDate: Date?
    for (_, taskInfo) in backgroundTasks {
      if let executionTime = taskInfo["executionTime"] as? Date {
        if earliestDate == nil || executionTime < earliestDate! {
          earliestDate = executionTime
        }
      }
    }

    // Set the earliest start date if there's a pending task
    if let earliestDate = earliestDate {
      request.earliestBeginDate = earliestDate

      do {
        try BGTaskScheduler.shared.submit(request)
      } catch {
        print("Could not schedule background task: \(error)")
      }
    }
  }

  // Cancel a specific background task
  func cancelBackgroundTask(taskId: String) {
    var tasks = backgroundTasks
    tasks.removeValue(forKey: taskId)
    backgroundTasks = tasks
  }

  static let pauseEndNotificationIdentifierPrefix = "pauseEndNotification:"

  /// Schedules a background task and notification to re-block when the pause timer expires.
  /// Uses chained scheduling: first check in 1 min, then reschedule until pause ends.
  /// iOS is more likely to run tasks requested for the near future.
  /// Also schedules a "break over" notification - when user opens the app from it, fallback re-blocks.
  func schedulePauseEndTask(
    profileId: String,
    endDate: Date,
    profileName: String? = nil
  ) {
    let taskId = Self.pauseEndTaskPrefix + profileId
    var tasks = backgroundTasks
    tasks[taskId] = [
      "executionTime": endDate,
      "pauseProfileId": profileId,
    ]
    backgroundTasks = tasks
    scheduleBackgroundProcessing()

    let thirtySecFromNow = Date().addingTimeInterval(30)
    let oneMinFromNow = Date().addingTimeInterval(60)
    let firstCheckDate = endDate < thirtySecFromNow ? endDate : min(thirtySecFromNow, oneMinFromNow)
    let refreshRequest = BGAppRefreshTaskRequest(
      identifier: Self.pauseEndRecoveryTaskIdentifier
    )
    refreshRequest.earliestBeginDate = firstCheckDate
    do {
      try BGTaskScheduler.shared.submit(refreshRequest)
      print("[PauseTimer] Scheduled BGAppRefresh first check at \(firstCheckDate), pause ends \(endDate)")
    } catch {
      print("[PauseTimer] Could not schedule BGAppRefresh: \(error)")
    }

  }

  /// Cancels the pause-end background task and notification. Call when user ends pause early via NFC.
  func cancelPauseEndTask(profileId: String) {
    cancelBackgroundTask(taskId: Self.pauseEndTaskPrefix + profileId)
    cancelNotification(identifier: Self.pauseEndNotificationIdentifierPrefix + profileId)
    BGTaskScheduler.shared.cancel(
      taskRequestWithIdentifier: Self.pauseEndRecoveryTaskIdentifier
    )
  }

  /// Reschedules pause-end BGAppRefresh when app goes to background. Gives iOS another chance.
  /// Schedules for the actual end time when close; otherwise 30s from now for iOS to re-evaluate.
  func reschedulePauseEndWhenEnteringBackground() {
    var earliest: (Date, String)?
    for (_, taskInfo) in backgroundTasks {
      guard let pauseProfileId = taskInfo["pauseProfileId"] as? String,
        let executionTime = taskInfo["executionTime"] as? Date,
        executionTime > Date()
      else { continue }
      if earliest == nil || executionTime < earliest!.0 {
        earliest = (executionTime, pauseProfileId)
      }
    }
    guard let (endDate, _) = earliest else { return }
    let request = BGAppRefreshTaskRequest(identifier: Self.pauseEndRecoveryTaskIdentifier)
    let now = Date()
    let thirtySecFromNow = now.addingTimeInterval(30)
    request.earliestBeginDate = endDate <= thirtySecFromNow ? endDate : thirtySecFromNow
    do {
      try BGTaskScheduler.shared.submit(request)
      print("[PauseTimer] Rescheduled BGAppRefresh when entering background for \(endDate)")
    } catch {
      print("[PauseTimer] Reschedule failed: \(error)")
    }
  }

  // Cancel all background tasks
  func cancelAllBackgroundTasks() {
    backgroundTasks = [:]
    BGTaskScheduler.shared.cancel(
      taskRequestWithIdentifier: Self.backgroundProcessingTaskIdentifier
    )
    BGTaskScheduler.shared.cancel(
      taskRequestWithIdentifier: Self.pauseEndRecoveryTaskIdentifier
    )
  }

  @discardableResult
  func scheduleNotification(
    title: String,
    message: String,
    seconds: TimeInterval,
    identifier: String? = nil,
    completion: @escaping (NotificationResult) -> Void = { _ in }
  ) -> String {
    let notificationId = identifier ?? UUID().uuidString

    // Request authorization before scheduling
    requestNotificationAuthorization { result in
      switch result {
      case .failure(let error):
        completion(.failure(error))
        return
      case .success:
        // Proceed with scheduling the notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
          timeInterval: seconds,
          repeats: false
        )
        let request = UNNotificationRequest(
          identifier: notificationId,
          content: content,
          trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
          if let error = error {
            print(
              "Error scheduling notification: \(error.localizedDescription)"
            )
            completion(.failure(error))
          } else {
            // Also schedule as background task for resilience when app is killed
            let taskId = UUID().uuidString
            self.scheduleBackgroundTask(
              taskId: taskId,
              executionTime: Date().addingTimeInterval(seconds),
              notificationId: notificationId
            )
            completion(.success)
          }
        }
      }
    }

    return notificationId
  }

  func cancelNotification(identifier: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [identifier])
  }

  func cancelAllNotifications() {
    UNUserNotificationCenter.current()
      .removeAllPendingNotificationRequests()
  }

  func cancelAll() {
    cancelAllNotifications()
    cancelAllBackgroundTasks()
  }

  // Schedule a background task
  private func scheduleBackgroundTask(
    taskId: String,
    executionTime: Date,
    notificationId: String? = nil
  ) {
    // Store task information in UserDefaults
    var tasks = backgroundTasks
    var taskInfo: [String: Any] = ["executionTime": executionTime]
    if let notificationId = notificationId {
      taskInfo["notificationId"] = notificationId
    }
    tasks[taskId] = taskInfo
    backgroundTasks = tasks

    // Schedule the background processing task
    scheduleBackgroundProcessing()
  }

  // Request authorization to send notifications
  private func requestNotificationAuthorization(
    completion: @escaping (NotificationResult) -> Void = { _ in }
  ) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) {
      granted,
      error in
      if let error = error {
        print(
          "Error requesting notification authorization: \(error.localizedDescription)"
        )
        completion(.failure(error))
        return
      }

      if granted {
        completion(.success)
      } else {
        completion(.failure(nil))
      }
    }
  }
}
