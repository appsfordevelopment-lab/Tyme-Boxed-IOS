import SwiftUI

struct PermissionsScreen: View {
  let onRequestAuthorization: () -> Void
  let onBack: (() -> Void)?

  init(onRequestAuthorization: @escaping () -> Void, onBack: (() -> Void)? = nil) {
    self.onRequestAuthorization = onRequestAuthorization
    self.onBack = onBack
  }

  var body: some View {
    ZStack {
      Color(uiColor: .systemBackground)
        .ignoresSafeArea()

      GeometryReader { geometry in
        VStack(spacing: 0) {
          // Back button
          HStack {
            if let onBack = onBack {
              Button(action: onBack) {
                Image(systemName: "chevron.left")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(
                  Circle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                )
              }
              .padding(.leading, 20)
              .padding(.top, 8)
            }
            Spacer()
          }
          .padding(.top, 8)

          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              // Title
              Text("Connect Time Boxed to Apple Screen Time")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 40)

              // Permission sections
              VStack(alignment: .leading, spacing: 32) {
                // How you'll use this
                permissionSection(
                  icon: "gearshape.fill",
                  title: "How you'll use this",
                  description: "Granting access lets you choose which apps to block in your modes. Screen Time securely pauses them when you're Time Boxed."
                )

                // How we'll use this
                HStack(alignment: .top, spacing: 16) {
                  // Icon
                  Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)

                  // Text content
                  VStack(alignment: .leading, spacing: 8) {
                    Text("How we'll use this")
                      .font(.system(size: 16, weight: .bold))
                      .foregroundColor(.primary)

                    (Text("We never see which apps you block or your browsing history. Your information stays private and stored only on your device. ")
                      + Text("Learn more in our privacy policy.")
                      .foregroundColor(.accentColor)
                      .underline())
                      .font(.system(size: 14))
                      .foregroundColor(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                      .onTapGesture {
                        if let url = URL(string: "https://timeboxed.app/privacy") {
                          UIApplication.shared.open(url)
                        }
                      }
                  }
                }

                // Why it matters
                permissionSection(
                  icon: "star.fill",
                  title: "Why it matters",
                  description: "This is how Time Boxed helps you create focused, intentional time, without deleting apps."
                )
              }
              .padding(.horizontal, 20)
              .padding(.bottom, 40)
            }
          }

          Spacer()

          // Allow access button - pinned to bottom
          VStack(spacing: 12) {
            Button(action: {
              onRequestAuthorization()
            }) {
              Text("Allow access")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary)
                )
            }
            .padding(.horizontal, 20)

            // Instructional text
            Text("On the next screen, tap Continue to connect to Screen Time. Can't connect?")
              .font(.system(size: 12))
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
              .padding(.bottom, 40)
          }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
  }

  private func permissionSection(icon: String, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      // Icon
      Image(systemName: icon)
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(.primary)
        .frame(width: 24, height: 24)

      // Text content
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.primary)

        Text(description)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

#Preview {
  PermissionsScreen(
    onRequestAuthorization: {
      print("Request authorization")
    },
    onBack: {
      print("Back tapped")
    }
  )
}
