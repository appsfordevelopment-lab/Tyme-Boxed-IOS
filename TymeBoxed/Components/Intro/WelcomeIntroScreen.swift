import SwiftUI

struct WelcomeIntroScreen: View {
  @Environment(\.openURL) private var openURL
  @State private var showContent: Bool = false
  let onContinueWithEmail: () -> Void
  let onSkipBrick: () -> Void
  let onContinueAsGuest: () -> Void

  var body: some View {
    ZStack {
      // Background image
      AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1543297088-974cee3f2156?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MjB8fHBob25lJTIwbGFwdG9wfGVufDB8fDB8fHww")) { phase in
        switch phase {
        case .empty:
          Color(uiColor: .systemBackground)
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        case .failure:
          Color(uiColor: .systemBackground)
        @unknown default:
          Color(uiColor: .systemBackground)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
      .ignoresSafeArea(.all)

      // Gradient overlay so content is readable in both light and dark mode
      VStack {
        Spacer()
        LinearGradient(
          colors: [Color.clear, Color.black.opacity(0.75)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 420)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea(.all)

      VStack(spacing: 0) {
        Spacer()

        // Title section
        VStack(alignment: .leading, spacing: 12) {
          Text("Your time is yours.")
            .font(.system(size: 35))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -20)

          Text("Get back to moving.")
            .font(.system(size: 35))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : -20)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 60)

        // Buttons
        VStack(spacing: 16) {
          // Continue with email button
          Button(action: onContinueWithEmail) {
            Text("Continue ")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.black)
              .frame(maxWidth: 350)
              .frame(height: 56)
              .background(
                RoundedRectangle(cornerRadius: 28)
                  .fill(Color.white)
              )
          }
          .opacity(showContent ? 1 : 0)
          .offset(y: showContent ? 0 : 20)

          // I don't have a Tyme Boxed button
          Button {
            openURL(URL(string: "https://www.tymeboxed.app/preorder")!)
          } label: {
            Text("I don't have a Tyme Boxed")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: 350)
              .frame(height: 56)
              .background(
                RoundedRectangle(cornerRadius: 28)
                  .fill(Color.clear)
                  .overlay(
                    RoundedRectangle(cornerRadius: 28)
                      .stroke(Color.white.opacity(0.6), lineWidth: 1)
                  )
              )
          }
          .opacity(showContent ? 1 : 0)
          .offset(y: showContent ? 0 : 20)

          // Continue as guest button
          Button(action: onContinueAsGuest) {
            Text("Continue as guest")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(Color.white.opacity(0.9))
          }
          .opacity(showContent ? 1 : 0)
          .offset(y: showContent ? 0 : 20)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)

        // Legal disclaimer
        VStack(spacing: 4) {
          HStack(spacing: 4) {
            Text("By continuing, you agree to our")
              .font(.system(size: 12))
              .foregroundColor(Color.white.opacity(0.9))

            Link("Terms", destination: URL(string: "https://www.tymeboxed.app/terms")!)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color(red: 1, green: 0.85, blue: 0.6))
              .underline()

            Text("and")
              .font(.system(size: 12))
              .foregroundColor(Color.white.opacity(0.7))

            Link("Privacy Policy", destination: URL(string: "https://www.tymeboxed.app/privacy")!)
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color(red: 1, green: 0.85, blue: 0.6))
              .underline()
          }
        }
        .padding(.bottom, 40)
        .opacity(showContent ? 1 : 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
        showContent = true
      }
    }
  }
}

#Preview {
  WelcomeIntroScreen(
    onContinueWithEmail: { print("Continue with email") },
    onSkipBrick: { print("Skip Brick") },
    onContinueAsGuest: { print("Continue as guest") }
  )
}
