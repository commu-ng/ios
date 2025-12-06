import SwiftUI
import Combine

struct ConsoleAccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ConsoleAccountViewModel()

    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingChangePassword = false
    @State private var showingEmailChange = false
    @State private var showingBlockedUsers = false

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

                // Blocked Users Section
                Section(header: Text(NSLocalizedString("block.section", comment: ""))) {
                    Button {
                        showingBlockedUsers = true
                    } label: {
                        Label(NSLocalizedString("block.manage", comment: ""), systemImage: "person.slash")
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
            .sheet(isPresented: $showingBlockedUsers) {
                BlockedUsersView()
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

    func deleteAccount() async {
        errorMessage = nil

        do {
            try await AccountService.shared.deleteAccount()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChangePasswordViewModel()

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var canSave: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        !viewModel.isSaving
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("account.current_password", comment: ""))) {
                    SecureField(NSLocalizedString("account.current_password", comment: ""), text: $currentPassword)
                        .textContentType(.password)
                        .autocapitalization(.none)
                }

                Section(header: Text(NSLocalizedString("account.new_password", comment: ""))) {
                    SecureField(NSLocalizedString("account.new_password", comment: ""), text: $newPassword)
                        .textContentType(.newPassword)
                        .autocapitalization(.none)

                    SecureField(NSLocalizedString("account.confirm_password", comment: ""), text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocapitalization(.none)

                    if !newPassword.isEmpty && newPassword.count < 8 {
                        Text(NSLocalizedString("account.password_hint", comment: ""))
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    if !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text(NSLocalizedString("account.passwords_mismatch", comment: ""))
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("account.change_password", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            let success = await viewModel.changePassword(
                                current: currentPassword,
                                new: newPassword
                            )
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("action.save", comment: ""))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

struct ChangeEmailView: View {
    let currentEmail: String?
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChangeEmailViewModel()

    @State private var newEmail = ""

    var canSave: Bool {
        !newEmail.isEmpty &&
        newEmail.contains("@") &&
        newEmail != currentEmail &&
        !viewModel.isSaving
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("account.email", comment: ""))) {
                    if let current = currentEmail {
                        LabeledContent(NSLocalizedString("account.current_email", comment: ""), value: current)
                    }

                    TextField(NSLocalizedString("account.new_email", comment: ""), text: $newEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section {
                    Text(NSLocalizedString("account.verification_hint", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("account.change_email", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            let success = await viewModel.changeEmail(newEmail: newEmail)
                            if success {
                                // Don't dismiss - show success message
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("account.send_verification", comment: ""))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

@MainActor
class ChangePasswordViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?

    func changePassword(current: String, new: String) async -> Bool {
        isSaving = true
        errorMessage = nil

        do {
            try await AccountService.shared.changePassword(currentPassword: current, newPassword: new)
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to change password: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }
}

@MainActor
class ChangeEmailViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func changeEmail(newEmail: String) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            try await AccountService.shared.changeEmail(newEmail: newEmail)
            successMessage = NSLocalizedString("account.verification_sent", comment: "")
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to change email: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }
}

#Preview {
    ConsoleAccountView()
        .environmentObject(AuthViewModel())
}
