import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var model: TactAppModel

    let initialMode: Int

    @State private var email = ""
    @State private var password = ""
    @State private var host = ""
    @State private var otp = ""
    @State private var mode: Int

    private let blue = Color(
        red: 0.02,
        green: 0.68,
        blue: 0.88
    )

    init(initialMode: Int = 0) {
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            TactBackground()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 45)

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(blue)
                                .frame(width: 72, height: 72)

                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 29, weight: .bold))
                                .foregroundStyle(.black)
                        }

                        Text("Tact")
                            .font(
                                .system(
                                    size: 38,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )

                        Text("Your computer, from anywhere.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 30)

                    VStack(spacing: 18) {
                        Picker("Sign in method", selection: $mode) {
                            Text("Account")
                                .tag(0)

                            Text("IP + OTP")
                                .tag(1)
                        }
                        .pickerStyle(.segmented)
                        .tint(blue)

                        if mode == 0 {
                            accountForm
                        } else {
                            otpForm
                        }

                        if let error = model.error {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                    }
                    .padding(20)
                    .background(
                        Color.white.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 24)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )

                    Spacer(minLength: 22)

                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)

                        Text("OR")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                    }

                    Spacer(minLength: 18)

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await model.demoSocialLogin("Apple")
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(
                                        .system(
                                            size: 19,
                                            weight: .medium
                                        )
                                    )

                                Text("Continue with Apple")
                                    .font(
                                        .system(
                                            size: 16,
                                            weight: .semibold
                                        )
                                    )
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Color.white,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }

                        Button {
                            Task {
                                await model.demoSocialLogin("Google")
                            }
                        } label: {
                            HStack(spacing: 10) {
                                GoogleLogo()

                                Text("Continue with Google")
                                    .font(
                                        .system(
                                            size: 16,
                                            weight: .semibold
                                        )
                                    )
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Color.white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        Color.white.opacity(0.09),
                                        lineWidth: 1
                                    )
                            )
                        }

                        Text("Secure remote control for your computers.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var accountForm: some View {
        VStack(spacing: 11) {
            inputField(
                icon: "envelope",
                placeholder: "Email",
                text: $email
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            secureInputField(
                icon: "lock",
                placeholder: "Password",
                text: $password
            )

            Button {
                Task {
                    await model.signIn(
                        email: email,
                        password: password
                    )
                }
            } label: {
                HStack {
                    if model.isBusy {
                        ProgressView()
                            .tint(.black)
                    }

                    Text(
                        model.isBusy
                        ? "Signing in..."
                        : "Sign In"
                    )
                }
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                blue,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .disabled(
                model.isBusy ||
                email.isEmpty ||
                password.isEmpty
            )
            .opacity(
                email.isEmpty || password.isEmpty
                ? 0.45
                : 1
            )

            Button("Forgot password?") {
                model.error =
                    "Password reset will be available when the account service is configured."
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var otpForm: some View {
        VStack(spacing: 11) {
            inputField(
                icon: "network",
                placeholder: "Host IP address",
                text: $host
            )
            .keyboardType(.numbersAndPunctuation)

            inputField(
                icon: "key",
                placeholder: "6-digit OTP",
                text: $otp
            )
            .keyboardType(.numberPad)
            .onChange(of: otp) { _, value in
                otp = String(
                    value
                        .filter(\.isNumber)
                        .prefix(6)
                )
            }

            Button {
                Task {
                    await model.pair(
                        host: host,
                        otp: otp
                    )
                }
            } label: {
                HStack {
                    if model.isBusy {
                        ProgressView()
                            .tint(.black)
                    }

                    Text(
                        model.isBusy
                        ? "Connecting..."
                        : "Connect"
                    )
                }
            }
            .foregroundStyle(.black)
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                blue,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .disabled(
                model.isBusy ||
                host.isEmpty ||
                otp.count != 6
            )
            .opacity(
                host.isEmpty || otp.count != 6
                ? 0.45
                : 1
            )

            Text("Approve the pairing request from the Tact Host menu after submitting.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(blue)
                .frame(width: 20)

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(.secondary)
            )
            .foregroundStyle(.white)
            .tint(blue)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private func secureInputField(
        icon: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(blue)
                .frame(width: 20)

            SecureField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(.secondary)
            )
            .foregroundStyle(.white)
            .tint(blue)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            Color.white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}
