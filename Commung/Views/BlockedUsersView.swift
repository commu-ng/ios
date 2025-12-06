import SwiftUI
import Combine

struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.blockedUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("block.empty", comment: ""))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("block.empty_description", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.blockedUsers) { user in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.loginName)
                                        .font(.headline)
                                    Text(formatDate(user.blockedAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task {
                                        await viewModel.unblockUser(userId: user.id)
                                    }
                                } label: {
                                    Text(NSLocalizedString("block.unblock", comment: ""))
                                        .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isUnblocking)
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("block.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadBlockedUsers()
        }
        .alert(NSLocalizedString("error.title", comment: ""), isPresented: $viewModel.showError) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.locale = Locale(identifier: "ko_KR")
            return String(format: NSLocalizedString("block.blocked_at", comment: ""), displayFormatter.string(from: date))
        }
        return dateString
    }
}

@MainActor
class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [BlockedUser] = []
    @Published var isLoading = false
    @Published var isUnblocking = false
    @Published var errorMessage: String?
    @Published var showError = false

    func loadBlockedUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            blockedUsers = try await BlockService.shared.getBlockedUsers()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func unblockUser(userId: String) async {
        isUnblocking = true
        errorMessage = nil

        do {
            try await BlockService.shared.unblockUser(userId: userId)
            blockedUsers.removeAll { $0.id == userId }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isUnblocking = false
    }
}

#Preview {
    BlockedUsersView()
}
