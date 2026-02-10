import SwiftUI

struct OTPScreen: View {
  let identifier: String
  let loginType: AuthenticationManager.LoginType
  let onVerificationSuccess: () -> Void
  let onDismiss: () -> Void

  @State private var otpDigits: [String] = Array(repeating: "", count: 6)
  @State private var showContent: Bool = false
  @StateObject private var authManager = AuthenticationManager.shared
  @State private var errorMessage: String? = nil
  @FocusState private var focusedIndex: Int?

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

          // OTP Input Fields
          HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
              otpField(at: index)
            }
          }
          .padding(.horizontal, 20)
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

  private func otpField(at index: Int) -> some View {
    let isFocused = focusedIndex == index
    let shouldShowBorder = isFocused

    return TextField("", text: Binding(
      get: { otpDigits[index] },
      set: { newValue in
        let filtered = newValue.filter { $0.isNumber }
        
        // Prevent unnecessary updates if value hasn't changed
        guard filtered != otpDigits[index] else { return }

        if filtered.isEmpty {
          // Backspace: clear current field and move to previous so user can keep deleting
          otpDigits[index] = ""
          if index > 0 && focusedIndex == index {
            // Use a small delay to prevent rapid focus changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
              focusedIndex = index - 1
            }
          }
        } else if filtered.count == 1 {
          // Single digit: set and move to next
          otpDigits[index] = filtered
          if index < 5 {
            // Use a small delay to prevent rapid focus changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
              if focusedIndex == index {
                focusedIndex = index + 1
              }
            }
          } else if index == 5 {
            // Last field filled, remove focus after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
              focusedIndex = nil
            }
          }
        } else {
          // Paste or autofill: distribute digits across fields
          let digits = Array(filtered.prefix(6)).map { String($0) }
          // Update all fields in a single batch
          for (i, digit) in digits.enumerated() where i < 6 {
            otpDigits[i] = digit
          }
          let nextEmpty = digits.count
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            focusedIndex = nextEmpty < 6 ? nextEmpty : nil
          }
        }
      }
    ))
    .keyboardType(.numberPad)
    .textContentType(.oneTimeCode)
    .multilineTextAlignment(.center)
    .font(.system(size: 24, weight: .bold))
    .foregroundColor(.primary)
    .focused($focusedIndex, equals: index)
    .frame(width: 50, height: 60)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(uiColor: .tertiarySystemFill))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(shouldShowBorder ? Color.primary : Color.clear, lineWidth: 1)
        )
    )
    .onTapGesture {
      focusedIndex = index
    }
  }

  private func handleAppear() {
    withAnimation(.easeOut(duration: 0.3)) {
      showContent = true
    }
    // Focus on first field to open keyboard
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      focusedIndex = 0
    }
  }

  private func isOTPComplete() -> Bool {
    return otpDigits.allSatisfy { !$0.isEmpty }
  }

  private func verifyOTP() async {
    errorMessage = nil
    let otpCode = otpDigits.joined()
    
    let isValid = await authManager.verifyOTP(otpCode)
    
    if isValid {
      onVerificationSuccess()
    } else {
      errorMessage = authManager.errorMessage ?? "Invalid OTP. Please try again."
      // Clear OTP fields on error
      otpDigits = Array(repeating: "", count: 6)
      focusedIndex = 0
    }
  }

  private func resendOTP() async {
    errorMessage = nil
    
    let phone = loginType == .phone ? identifier : nil
    let email = loginType == .email ? identifier : nil
    
    await authManager.sendOTP(email: email, phone: phone)
    
    if authManager.otpSent {
      // Clear OTP fields
      otpDigits = Array(repeating: "", count: 6)
      focusedIndex = 0
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
