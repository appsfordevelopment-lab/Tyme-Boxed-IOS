import SwiftUI

struct OTPScreen: View {
  let identifier: String
  let loginType: AuthenticationManager.LoginType
  let onVerificationSuccess: () -> Void
  let onDismiss: () -> Void

  @State private var otpCode: String = ""
  @State private var showContent: Bool = false
  @StateObject private var authManager = AuthenticationManager.shared
  @State private var errorMessage: String? = nil
  @FocusState private var isFocused: Bool

  var body: some View {
    ZStack {
      Color(uiColor: .systemBackground)
        .ignoresSafeArea()

      GeometryReader { geometry in
        VStack(spacing: 0) {
          // Back button
          HStack {
            Button(action: onDismiss) {
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
            Spacer()
          }
          .padding(.top, 8)

          // Title
          Text("We sent you a verification code")
            .font(.system(size: 34, weight: .bold))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)

          // OTP Input - single TextField for native backspace support
          ZStack(alignment: .leading) {
            HStack(spacing: 12) {
              ForEach(0..<6, id: \.self) { index in
                otpDigitBox(at: index)
              }
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
              isFocused = true
            }

            TextField("", text: Binding(
              get: { otpCode },
              set: { newValue in
                let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                otpCode = filtered
              }
            ))
              .keyboardType(.numberPad)
              .textContentType(.oneTimeCode)
              .multilineTextAlignment(.center)
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.clear)
              .focused($isFocused)
              .frame(maxWidth: .infinity)
              .frame(height: 60)
              .padding(.horizontal, 20)
          }
          .padding(.bottom, 16)

          // Instruction text
          Text("Enter the 6-digit code sent to \(identifier)")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

          // Error message
          if let errorMessage = errorMessage {
            Text(errorMessage)
              .font(.system(size: 14))
              .foregroundColor(.red)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
              .padding(.bottom, 8)
          }

          // Resend button
          Button(action: {
            Task {
              await resendOTP()
            }
          }) {
            HStack {
              if authManager.isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle())
              }
              Text("Resend code")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
            }
          }
          .disabled(authManager.isLoading)
          .padding(.bottom, 32)

          Spacer()

          // Verify button - pinned to bottom
          Button(action: {
            Task {
              await verifyOTP()
            }
          }) {
            HStack {
              if authManager.isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: Color(uiColor: .systemBackground)))
              }
              Text("Verify")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(
                  isOTPComplete() && !authManager.isLoading
                    ? Color(uiColor: .systemBackground) : Color(uiColor: .tertiaryLabel)
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(
                  isOTPComplete() && !authManager.isLoading
                    ? Color.primary : Color(uiColor: .tertiarySystemFill)
                )
            )
          }
          .disabled(!isOTPComplete() || authManager.isLoading)
          .padding(.horizontal, 20)
          .padding(.bottom, 40)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
    .onAppear {
      handleAppear()
    }
  }

  private func otpDigitBox(at index: Int) -> some View {
    let digit = index < otpCode.count ? String(otpCode[otpCode.index(otpCode.startIndex, offsetBy: index)]) : ""
    let currentBoxIndex = min(otpCode.count, 5)
    let shouldShowBorder = isFocused && index == currentBoxIndex

    return Text(digit)
      .font(.system(size: 24, weight: .bold))
      .foregroundColor(.primary)
      .frame(width: 50, height: 60)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(uiColor: .tertiarySystemFill))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(shouldShowBorder ? Color.primary : Color.clear, lineWidth: 1)
          )
      )
  }

  private func handleAppear() {
    withAnimation(.easeOut(duration: 0.3)) {
      showContent = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      isFocused = true
    }
  }

  private func isOTPComplete() -> Bool {
    return otpCode.count == 6
  }

  private func verifyOTP() async {
    errorMessage = nil
    
    let isValid = await authManager.verifyOTP(otpCode)
    
    if isValid {
      onVerificationSuccess()
    } else {
      errorMessage = authManager.errorMessage ?? "Invalid OTP. Please try again."
      otpCode = ""
      isFocused = true
    }
  }

  private func resendOTP() async {
    errorMessage = nil
    
    let phone = loginType == .phone ? identifier : nil
    let email = loginType == .email ? identifier : nil
    
    await authManager.sendOTP(email: email, phone: phone)
    
    if authManager.otpSent {
      otpCode = ""
      isFocused = true
    } else {
      errorMessage = authManager.errorMessage ?? "Failed to resend OTP. Please try again."
    }
  }
}

#Preview {
  OTPScreen(
    identifier: "boidianiruddh@gmail.com",
    loginType: .email,
    onVerificationSuccess: {
      print("Verification successful")
    },
    onDismiss: {
      print("Dismissed")
    }
  )
}
