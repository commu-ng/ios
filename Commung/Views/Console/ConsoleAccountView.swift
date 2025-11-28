import SwiftUI
import Combine

struct ConsoleAccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ConsoleAccountViewModel()

    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingChangePassword = false
    @State private var showingEmailChange = false

    var body: some View {
        NavigationView {
            Form {
                // Account Information Section
                Section(header: Text(NSLocalizedString("account.information", comment: ""))) {
                    if let user = viewModel.currentUser {
                        LabeledContent(NSLocalizedString("account.login_name", comment: ""), value: user.loginName)

                        if let email = user.email {
                            LabeledContent(NSLocalizedString("account.email", comment: ""), value: email)
                            if user.emailVerified {
                                Label(NSLocalizedString("account.verified", comment: ""), systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Label(NSLocalizedString("account.not_verified", comment: ""), systemImage: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        } else {
                            Button(NSLocalizedString("account.add_email", comment: "")) {
                                showingEmailChange = true
                            }
                        }

                        if let signupDate = user.signupDate {
                            LabeledContent(NSLocalizedString("account.member_since", comment: ""), value: signupDate, format: .dateTime.month().day().year())
                        }
                    } else if viewModel.isLoading {
                        ProgressView()
                    }
                }

                // Security Section
                Section(header: Text(NSLocalizedString("account.security", comment: ""))) {
                    Button {
                        showingChangePassword = true
                    } label: {
                        Label(NSLocalizedString("account.change_password", comment: ""), systemImage: "key.fill")
                    }

                    if viewModel.currentUser?.email != nil {
                        Button {
                            showingEmailChange = true
                        } label: {
                            Label(NSLocalizedString("account.change_email", comment: ""), systemImage: "envelope.fill")
                        }
                    }
                }

                // Account Actions Section
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label(NSLocalizedString("account.log_out", comment: ""), systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(NSLocalizedString("account.delete_account", comment: ""), systemImage: "trash.fill")
                    }
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // Success message
                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("account.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .alert(NSLocalizedString("auth.logout_confirm_title", comment: ""), isPresented: $showingLogoutConfirmation) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("auth.logout", comment: ""), role: .destructive) {
                    Task {
                        await authViewModel.logout()
                    }
                }
            } message: {
                Text(NSLocalizedString("auth.logout_confirm_message", comment: ""))
            }
            .alert(NSLocalizedString("account.delete_confirm_title", comment: ""), isPresented: $showingDeleteConfirmation) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("post.delete", comment: ""), role: .destructive) {
                    Task {
                        await viewModel.deleteAccount()
                    }
                }
            } message: {
                Text(NSLocalizedString("account.delete_confirm_message", comment: ""))
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showingEmailChange) {
                ChangeEmailView(currentEmail: viewModel.currentUser?.email)
            }
        }
        .task {
            await viewModel.loadCurrentUser()
        }
    }
}

@MainActor
class ConsoleAccountViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadCurrentUser() async {
        isLoading = true
        errorMessage = nil

        do {
            currentUser = try await AccountService.shared.getCurrentUser()
        } catch {
            errorMessage = "Failed to load user info: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() async {
        do {
            try await AccountService.shared.logout()
        } catch {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
        }
    }

    func deleteAccount() async {
        errorMessage = nil

        do {
            try await AccountService.shared.deleteAccount()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ConsoleAccountView()
        .environmentObject(AuthViewModel())
}
