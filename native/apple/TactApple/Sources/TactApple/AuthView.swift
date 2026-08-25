import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject private var model: TactAppModel
    @State private var email = ""
    @State private var password = ""
    @State private var host = ""
    @State private var otp = ""
    @State private var mode = 0

    var body: some View {
        ZStack {
            Color.tactBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "bolt.horizontal.circle.fill").font(.system(size: 52)).foregroundStyle(Color.tactCyan)
                    Text("Tact").font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text("Your computer, from anywhere.").foregroundStyle(.secondary)

                    Picker("Sign in", selection: $mode) { Text("Account").tag(0); Text("IP + OTP").tag(1) }.pickerStyle(.segmented)

                    if mode == 0 { accountForm } else { otpForm }
                    Divider().padding(.vertical, 4)
                    socialButtons
                    if let error = model.error { Text(error).foregroundStyle(.red).font(.callout).frame(maxWidth: .infinity, alignment: .leading) }
                }.frame(maxWidth: 430).padding(28)
            }
        }
    }

    private var accountForm: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email).textContentType(.username).textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password).textContentType(.password).textFieldStyle(.roundedBorder)
            Button { Task { await model.signIn(email: email, password: password) } } label: { Text(model.isBusy ? "Signing In…" : "Sign In").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(Color.tactCyan).disabled(model.isBusy)
            Button("Forgot password?") { model.error = "Password reset will be available when the account service is configured." }.buttonStyle(.plain).foregroundStyle(.secondary)
        }.tactGlass().padding(4)
    }

    private var otpForm: some View {
        VStack(spacing: 12) {
            TextField("Host IP address", text: $host).textFieldStyle(.roundedBorder)
            TextField("6-digit OTP", text: $otp).textFieldStyle(.roundedBorder).onChange(of: otp) { _, new in otp = String(new.filter(\.isNumber).prefix(6)) }
            Button { Task { await model.pair(host: host, otp: otp) } } label: { Text(model.isBusy ? "Pairing…" : "Connect") .frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(Color.tactCyan).disabled(host.isEmpty || otp.count != 6 || model.isBusy)
            Text("Approve the pairing request from the Tact Host menu after submitting.").font(.caption).foregroundStyle(.secondary)
        }.tactGlass().padding(4)
    }

    private var socialButtons: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.signIn, onRequest: { request in request.requestedScopes = [.fullName, .email] }, onCompletion: { result in
                switch result { case .success: Task { await model.demoSocialLogin("Apple") }; case .failure(let error): model.error = error.localizedDescription }
            }).frame(height: 48).clipShape(RoundedRectangle(cornerRadius: 14))
            Button { Task { await model.demoSocialLogin("Google") } } label: { Label("Continue with Google", systemImage: "globe").frame(maxWidth: .infinity) }.buttonStyle(.bordered).frame(height: 48)
            Text("Google uses the native OAuth adapter; add your Google client configuration to enable production OAuth.").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}
