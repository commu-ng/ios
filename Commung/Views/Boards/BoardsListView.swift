import SwiftUI

// Navigation destination for notification-based post navigation
struct NotificationPostDestination: Hashable {
    let board: Board
    let postId: String

    static func == (lhs: NotificationPostDestination, rhs: NotificationPostDestination) -> Bool {
        return lhs.board.id == rhs.board.id && lhs.postId == rhs.postId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(board.id)
        hasher.combine(postId)
    }
}

struct BoardsListView: View {
    @EnvironmentObject var boardsViewModel: BoardsViewModel
    var notificationBoard: Board? = nil
    var notificationPostId: String? = nil
    @Binding var navigationTrigger: String?
    @State private var notificationDestination: NotificationPostDestination? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    let filteredBoards = boardsViewModel.boards

                    if boardsViewModel.isLoadingBoards && filteredBoards.isEmpty {
                        ProgressView(NSLocalizedString("loading.boards", comment: ""))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                    } else if filteredBoards.isEmpty {
                        Text(NSLocalizedString("empty.no_boards", comment: ""))
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                    } else {
                        ForEach(filteredBoards) { board in
                            NavigationLink(destination: BoardDetailView(board: board).environmentObject(boardsViewModel)) {
                                BoardRowView(board: board)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .navigationDestination(isPresented: Binding(
                    get: { notificationDestination != nil },
                    set: { if !$0 { notificationDestination = nil } }
                )) {
                    if let destination = notificationDestination {
                        PostDetailNavigationView(board: destination.board, postId: destination.postId)
                            .environmentObject(boardsViewModel)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.boards", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .task {
                // Only load boards once - loadBoards() has internal guards for safety
                await boardsViewModel.loadBoards()
            }
            .refreshable {
                await boardsViewModel.loadBoards(force: true)
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: navigationTrigger) { oldValue, newValue in
            if let trigger = newValue,
               let board = notificationBoard,
               let postId = notificationPostId,
               trigger == "\(board.slug)_\(postId)" {
                notificationDestination = NotificationPostDestination(board: board, postId: postId)
            }
        }
        .onChange(of: notificationDestination) { oldValue, newValue in
            if newValue == nil {
                navigationTrigger = nil
            }
        }
    }
}

// Provide default initializer for existing usage
extension BoardsListView {
    init() {
        self.init(navigationTrigger: .constant(nil))
    }
}

struct BoardRowView: View {
    let board: Board

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(board.name)
                .font(.headline)

            if let description = board.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
