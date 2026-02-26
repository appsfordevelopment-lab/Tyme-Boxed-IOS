import ActivityKit
import SwiftUI
import WidgetKit

@ViewBuilder
private func appLogoView(size: CGFloat = 24) -> some View {
  Image("AppLogo")
    .resizable()
    .renderingMode(.original)
    .scaledToFit()
    .frame(width: size, height: size)
}

struct TymeBoxedWidgetAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var startTime: Date
    var isBreakActive: Bool = false
    var breakStartTime: Date?
    var breakEndTime: Date?

    var isPauseActive: Bool = false
    var pauseStartTime: Date?
    var pauseDurationInMinutes: Int?

    init(
      startTime: Date,
      isBreakActive: Bool = false,
      breakStartTime: Date? = nil,
      breakEndTime: Date? = nil,
      isPauseActive: Bool = false,
      pauseStartTime: Date? = nil,
      pauseDurationInMinutes: Int? = nil
    ) {
      self.startTime = startTime
      self.isBreakActive = isBreakActive
      self.breakStartTime = breakStartTime
      self.breakEndTime = breakEndTime
      self.isPauseActive = isPauseActive
      self.pauseStartTime = pauseStartTime
      self.pauseDurationInMinutes = pauseDurationInMinutes
    }

    func getTimeIntervalSinceNow() -> Double {
      // Calculate the break duration to subtract from elapsed time
      let breakDuration = calculateBreakDuration()

      // Calculate elapsed time minus break duration
      let adjustedStartTime = startTime.addingTimeInterval(breakDuration)

      return adjustedStartTime.timeIntervalSince1970
        - Date().timeIntervalSince1970
    }

    private func calculateBreakDuration() -> TimeInterval {
      guard let breakStart = breakStartTime else {
        return 0
      }

      if let breakEnd = breakEndTime {
        // Break is complete, return the full duration
        return breakEnd.timeIntervalSince(breakStart)
      }

      // Break is not yet ended, don't count it
      return 0
    }
  }

  var name: String
  var message: String
}

struct TymeBoxedWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TymeBoxedWidgetAttributes.self) { context in
      // Lock screen/banner UI goes here
      HStack(alignment: .center, spacing: 16) {
        // Left side - App info
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Text("Tyme Boxed")
              .font(.headline)
              .fontWeight(.bold)
              .foregroundColor(.primary)
            appLogoView(size: 24)
          }

          Text(context.attributes.name)
            .font(.subheadline)
            .foregroundColor(.primary)

          Text(context.attributes.message)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        // Right side - Timer or break indicator
        VStack(alignment: .trailing, spacing: 4) {
          if context.state.isPauseActive {
            HStack(spacing: 6) {
              Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundColor(.orange)
              Text("Paused")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            }
          } else if context.state.isBreakActive {
            HStack(spacing: 6) {
              Image(systemName: "cup.and.heat.waves.fill")
                .font(.title2)
                .foregroundColor(.orange)
              Text("On a Break")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            }
          } else {
            Text(
              Date(
                timeIntervalSinceNow: context.state
                  .getTimeIntervalSinceNow()
              ),
              style: .timer
            )
            .font(.title)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.trailing)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 8) {
            HStack(spacing: 6) {
              appLogoView(size: 24)
              Text(context.attributes.name)
                .font(.headline)
                .fontWeight(.medium)
            }

            Text(context.attributes.message)
              .font(.subheadline)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)

            if context.state.isPauseActive {
              VStack(spacing: 2) {
                Image(systemName: "pause.circle.fill")
                  .font(.title2)
                  .foregroundColor(.orange)
                Text("Paused")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.orange)
              }
            } else if context.state.isBreakActive {
              VStack(spacing: 2) {
                Image(systemName: "cup.and.heat.waves.fill")
                  .font(.title2)
                  .foregroundColor(.orange)
                Text("On a Break")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.orange)
              }
            } else {
              Text(
                Date(
                  timeIntervalSinceNow: context.state
                    .getTimeIntervalSinceNow()
                ),
                style: .timer
              )
              .font(.title2)
              .fontWeight(.semibold)
              .multilineTextAlignment(.center)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 4)
        }
      } compactLeading: {
        appLogoView(size: 20)
      } compactTrailing: {
        // Compact trailing state
        Text(
          context.attributes.name
        )
        .font(.caption)
        .fontWeight(.semibold)
      } minimal: {
        appLogoView(size: 16)
      }
      .widgetURL(URL(string: "http://www.timeboxed.app"))
      .keylineTint(Color.purple)
    }
  }
}

extension TymeBoxedWidgetAttributes {
  fileprivate static var preview: TymeBoxedWidgetAttributes {
    TymeBoxedWidgetAttributes(
      name: "Focus Session",
      message: "Stay focused and avoid distractions")
  }
}

extension TymeBoxedWidgetAttributes.ContentState {
  fileprivate static var shortTime: TymeBoxedWidgetAttributes.ContentState {
    TymeBoxedWidgetAttributes
      .ContentState(
        startTime: Date(timeInterval: 60, since: Date.now),
        isBreakActive: false,
        breakStartTime: nil,
        breakEndTime: nil
      )
  }

  fileprivate static var longTime: TymeBoxedWidgetAttributes.ContentState {
    TymeBoxedWidgetAttributes.ContentState(
      startTime: Date(timeInterval: 60, since: Date.now),
      isBreakActive: false,
      breakStartTime: nil,
      breakEndTime: nil
    )
  }

  fileprivate static var breakActive: TymeBoxedWidgetAttributes.ContentState {
    TymeBoxedWidgetAttributes.ContentState(
      startTime: Date(timeInterval: 60, since: Date.now),
      isBreakActive: true,
      breakStartTime: Date.now,
      breakEndTime: nil
    )
  }
}

#Preview("Notification", as: .content, using: TymeBoxedWidgetAttributes.preview) {
  TymeBoxedWidgetLiveActivity()
} contentStates: {
  TymeBoxedWidgetAttributes.ContentState.shortTime
  TymeBoxedWidgetAttributes.ContentState.longTime
  TymeBoxedWidgetAttributes.ContentState.breakActive
}
