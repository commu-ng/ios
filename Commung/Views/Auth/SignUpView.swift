import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var loginName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var policyAgreed = false
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 20) {
            TextField(NSLocalizedString("auth.login_name", comment: ""), text: $loginName)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField(NSLocalizedString("auth.password", comment: ""), text: $password)
                .textFieldStyle(.roundedBorder)

            SecureField(NSLocalizedString("auth.password", comment: ""), text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: $policyAgreed)
                    .labelsHidden()
                    .toggleStyle(CheckboxToggleStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("auth.policy_agreement_prefix", comment: ""))
                        .font(.subheadline)
                    HStack(spacing: 4) {
                        Link(NSLocalizedString("auth.privacy_policy", comment: ""),
                             destination: URL(string: "https://commu.ng/privacy")!)
                            .font(.subheadline)
                        Text(NSLocalizedString("auth.and", comment: ""))
                            .font(.subheadline)
                        Link(NSLocalizedString("auth.community_guidelines", comment: ""),
                             destination: URL(string: "https://commu.ng/policy")!)
                            .font(.subheadline)
                    }
                    Text(NSLocalizedString("auth.policy_agreement_suffix", comment: ""))
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let validationError = validationError {
                Text(validationError)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                validateAndSignup()
            }) {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(NSLocalizedString("auth.sign_up", comment: ""))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authViewModel.isLoading || loginName.isEmpty || password.isEmpty || confirmPassword.isEmpty || !policyAgreed)

            Button(action: {
                dismiss()
            }) {
                HStack {
                    Text(NSLocalizedString("auth.already_have_account", comment: ""))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("auth.sign_in", comment: ""))
                        .foregroundColor(.blue)
                }
                .font(.subheadline)
            }
            .disabled(authViewModel.isLoading)

            Spacer()
        }
        .padding()
    }

    private func validateAndSignup() {
        validationError = nil

        if !policyAgreed {
            validationError = NSLocalizedString("auth.policy_agreement_required", comment: "")
            return
        }

        if password.count < 8 {
            validationError = NSLocalizedString("auth.password_min_length", comment: "")
            return
        }

        if password != confirmPassword {
            validationError = NSLocalizedString("auth.passwords_not_match", comment: "")
            return
        }

        Task {
            await authViewModel.signup(loginName: loginName, password: password)
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.title2)
        }
        .buttonStyle(.plain)
    }
}
