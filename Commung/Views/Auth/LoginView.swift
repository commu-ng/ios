import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var loginName = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        VStack(spacing: 20) {
            TextField(NSLocalizedString("auth.login_name", comment: ""), text: $loginName)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField(NSLocalizedString("auth.password", comment: ""), text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await authViewModel.login(loginName: loginName, password: password)
                }
            }) {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(NSLocalizedString("auth.login", comment: ""))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authViewModel.isLoading || loginName.isEmpty || password.isEmpty)

            Button(action: {
                showSignUp = true
            }) {
                HStack {
                    Text(NSLocalizedString("auth.no_account", comment: ""))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("auth.sign_up", comment: ""))
                        .foregroundColor(.blue)
                }
                .font(.subheadline)
            }
            .disabled(authViewModel.isLoading)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authViewModel)
        }
    }
}
