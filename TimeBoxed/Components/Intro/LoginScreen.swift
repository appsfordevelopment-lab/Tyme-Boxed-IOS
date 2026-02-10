import SwiftUI

struct LoginScreen: View {
  @State private var phone: String = ""
  @State private var selectedCountryCode: String = "+91"
  @State private var showingOTPScreen = false
  @StateObject private var authManager = AuthenticationManager.shared
  @State private var errorMessage: String? = nil

  private let countryCodes: [(code: String, name: String, flag: String)] = [
    ("+91", "India", "🇮🇳"),
    ("+1", "USA", "🇺🇸"),
    ("+44", "UK", "🇬🇧"),
    ("+61", "Australia", "🇦🇺"),
    ("+971", "UAE", "🇦🇪"),
    ("+86", "China", "🇨🇳"),
    ("+81", "Japan", "🇯🇵"),
    ("+49", "Germany", "🇩🇪"),
    ("+33", "France", "🇫🇷"),
    ("+7", "Russia", "🇷🇺")
  ]

  private var selectedCountry: (code: String, name: String, flag: String) {
    countryCodes.first { $0.code == selectedCountryCode } ?? countryCodes[0]
  }

  let onLoginSuccess: () -> Void
  let onBack: (() -> Void)?

  init(onLoginSuccess: @escaping () -> Void, onBack: (() -> Void)? = nil) {
    self.onLoginSuccess = onLoginSuccess
    self.onBack = onBack
  }

  var body: some View {
    ZStack {
      Color(uiColor: .systemBackground)
        .ignoresSafeArea()

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

        // Title - center aligned
        Text("Enter your phone number to sign in or get started")
          .font(.system(size: 30,))
          .foregroundColor(.primary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
          .padding(.top, 40)
          .padding(.bottom, 32)

        // Phone input field with country code - center aligned
        HStack(spacing: 12) {
          // Country code selector
          Menu {
            ForEach(countryCodes, id: \.code) { country in
              Button(action: {
                selectedCountryCode = country.code
              }) {
                Text("\(country.flag) \(country.code) \(country.name)")
                  .font(.system(size: 16))
              }
            }
          } label: {
            HStack(spacing: 6) {
              Text(selectedCountry.flag)
                .font(.system(size: 22))
              Text(selectedCountryCode)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(1)
              Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            }
            .frame(minWidth: 110)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .tertiarySystemFill))
            )
            .contentShape(Rectangle())
          }
          .fixedSize(horizontal: true, vertical: false)

          // Phone number input
          TextField("Phone number", text: $phone)
            .textContentType(.telephoneNumber)
            .keyboardType(.phonePad)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .padding(16)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .tertiarySystemFill))
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)

        // Hint text - center aligned
        Text("We'll send you a code to confirm it's you")
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

        Spacer()

        // Get verification code button - center aligned
        Button(action: {
          Task {
            await sendOTP()
          }
        }) {
          HStack {
            if authManager.isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(uiColor: .systemBackground)))
            }
            Text("Get verification code")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(
                isValidPhone(phone) && !authManager.isLoading
                  ? Color(uiColor: .systemBackground) : Color(uiColor: .tertiaryLabel)
              )
          }
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(
                isValidPhone(phone) && !authManager.isLoading
                  ? Color.primary : Color(uiColor: .tertiarySystemFill)
              )
          )
        }
        .disabled(!isValidPhone(phone) || authManager.isLoading)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
      }
    }
    .sheet(isPresented: $showingOTPScreen) {
      OTPScreen(
        identifier: formatPhoneNumber(phone),
        loginType: .phone,
        onVerificationSuccess: {
          showingOTPScreen = false
          onLoginSuccess()
        },
        onDismiss: {
          showingOTPScreen = false
        }
      )
    }
  }

  private func sendOTP() async {
    errorMessage = nil
    let formattedPhone = formatPhoneNumber(phone)
    
    await authManager.sendOTP(phone: formattedPhone)
    
    if authManager.otpSent {
      showingOTPScreen = true
    } else {
      errorMessage = authManager.errorMessage ?? "Failed to send OTP. Please try again."
    }
  }

  private func isValidPhone(_ phone: String) -> Bool {
    let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    return digits.count >= 10
  }

  private func formatPhoneNumber(_ phone: String) -> String {
    let digits = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    // Format as E.164 with selected country code
    if !digits.isEmpty {
      let countryCodeDigits = selectedCountryCode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
      return "+\(countryCodeDigits)\(digits)"
    }
    return selectedCountryCode
  }
}

#Preview {
  LoginScreen(
    onLoginSuccess: {
      print("Login successful")
    },
    onBack: {
      print("Back tapped")
    }
  )
}
