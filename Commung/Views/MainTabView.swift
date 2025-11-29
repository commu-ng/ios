import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @EnvironmentObject var appModeContext: AppModeContext
    @ObservedObject var boardsViewModel: BoardsViewModel
    @StateObject private var notificationViewModel = NotificationViewModel()
    @State private var notificationData: [AnyHashable: Any]?

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if appModeContext.currentMode == .app {
                    appModeTabView
                        .id("app")
                        .transition(.opacity)
                } else {
                    consoleModeTabView
                        .id("console")
                        .transition(.opacity)
                }
            } else {
                unauthenticatedTabView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appModeContext.currentMode)
        .task {
            // Load notification count if authenticated
            if authViewModel.isAuthenticated, let profileId = profileContext.currentProfileId {
                await notificationViewModel.loadUnreadCount(profileId: profileId)
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PushNotificationTapped"),
                object: nil,
                queue: .main
            ) { notification in
                handlePushNotification(notification.userInfo)
            }
        }
    }

    private func handlePushNotification(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo else {
            print("handlePushNotification: userInfo is nil")
            return
        }
        guard let type = userInfo["type"] as? String else {
            print("handlePushNotification: type is nil")
            return
        }

        print("handlePushNotification: type=\(type)")

        switch type {
        case "board_post_comment", "board_post_reply":
            // Navigate to board post detail
            print("\(type): boardSlug=\(userInfo["board_slug"] ?? "nil"), boardPostId=\(userInfo["board_post_id"] ?? "nil")")
            notificationData = userInfo

        case "reaction", "reply", "mention", "direct_message":
            // Open community URL in Safari
            if let communityUrl = userInfo["community_url"] as? String,
               let url = URL(string: communityUrl) {
                UIApplication.shared.open(url)
            }

        default:
            print("Unknown notification type: \(type)")
        }
    }

    // MARK: - App Mode Tab View
    private var appModeTabView: some View {
        TabView {
            Tab(NSLocalizedString("nav.home", comment: ""), systemImage: "house.fill") {
                HomeFeedView()
                    .environmentObject(appModeContext)
            }

            Tab(NSLocalizedString("nav.messages", comment: ""), systemImage: "message.fill") {
                MessagesView()
            }

            Tab(NSLocalizedString("nav.notifications", comment: ""), systemImage: "bell.fill") {
                NotificationsView()
                    .environmentObject(notificationViewModel)
            }
            .badge(notificationViewModel.unreadCount > 0 ? notificationViewModel.unreadCount : 0)

            Tab(NSLocalizedString("nav.profile", comment: ""), systemImage: "person.circle.fill") {
                AppProfileView()
            }

            Tab(NSLocalizedString("search.title", comment: ""), systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }
        }
    }

    // MARK: - Console Mode Tab View
    private var consoleModeTabView: some View {
        TabView {
            // Boards
            BoardsNavigationView(notificationData: $notificationData)
                .environmentObject(boardsViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Label(NSLocalizedString("nav.boards", comment: ""), systemImage: "list.bullet")
                }

            // Communities (merged browse + my communities)
            CommunitiesTabView()
                .environmentObject(communityContext)
                .environmentObject(appModeContext)
                .tabItem {
                    Label(NSLocalizedString("nav.communities", comment: ""), systemImage: "person.3.fill")
                }

            // Account
            ConsoleAccountView()
                .tabItem {
                    Label(NSLocalizedString("nav.account", comment: ""), systemImage: "person.crop.circle")
                }
        }
    }

    // MARK: - Unauthenticated Tab View
    private var unauthenticatedTabView: some View {
        TabView {
            // Boards (public access)
            BoardsNavigationView(notificationData: $notificationData)
                .environmentObject(boardsViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Label(NSLocalizedString("nav.boards", comment: ""), systemImage: "list.bullet")
                }

            // Sign In
            SignInTabView()
                .tabItem {
                    Label(NSLocalizedString("auth.sign_in", comment: ""), systemImage: "person.circle")
                }
        }
    }
}

struct BoardsNavigationView: View {
    @EnvironmentObject var boardsViewModel: BoardsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var notificationData: [AnyHashable: Any]?
    @State private var targetBoard: Board?
    @State private var targetPostId: String?
    @State private var navigationTrigger: String?

    var body: some View {
        BoardsListView(
            notificationBoard: targetBoard,
            notificationPostId: targetPostId,
            navigationTrigger: $navigationTrigger
        )
        .environmentObject(boardsViewModel)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushNotificationTapped"))) { notification in
            print("BoardsNavigationView: Received PushNotificationTapped")
            print("BoardsNavigationView: userInfo = \(notification.userInfo ?? [:])")

            if let userInfo = notification.userInfo,
               let type = userInfo["type"] as? String,
               (type == "board_post_comment" || type == "board_post_reply"),
               let boardSlug = userInfo["board_slug"] as? String,
               let postId = userInfo["board_post_id"] as? String {
                print("BoardsNavigationView: Found type=\(type), board_slug=\(boardSlug), board_post_id=\(postId)")
                Task {
                    await loadBoardAndNavigate(boardSlug: boardSlug, postId: postId)
                }
            } else {
                print("BoardsNavigationView: Not a board post notification or missing data")
            }
        }
        .onChange(of: navigationTrigger) { oldValue, newValue in
            if newValue == nil {
                // Navigation was dismissed
                targetBoard = nil
                targetPostId = nil
                notificationData = nil
            }
        }
    }

    private func loadBoardAndNavigate(boardSlug: String, postId: String) async {
        print("loadBoardAndNavigate: boardSlug=\(boardSlug), postId=\(postId)")
        print("loadBoardAndNavigate: boards count=\(boardsViewModel.boards.count)")

        // Load boards if not already loaded
        if boardsViewModel.boards.isEmpty {
            print("loadBoardAndNavigate: Loading boards...")
            await boardsViewModel.loadBoards()
            print("loadBoardAndNavigate: Boards loaded, count=\(boardsViewModel.boards.count)")
        }

        // Find the board
        if let board = boardsViewModel.boards.first(where: { $0.slug == boardSlug }) {
            print("loadBoardAndNavigate: Found board: \(board.name)")

            // Set state on main thread
            await MainActor.run {
                targetBoard = board
                targetPostId = postId
                let dataKey = "\(boardSlug)_\(postId)"
                navigationTrigger = dataKey
                print("loadBoardAndNavigate: Set navigationTrigger=\(dataKey)")
            }
        } else {
            print("loadBoardAndNavigate: Board not found with slug: \(boardSlug)")
            print("loadBoardAndNavigate: Available slugs: \(boardsViewModel.boards.map { $0.slug })")
        }
    }
}

struct PostDetailNavigationView: View {
    let board: Board
    let postId: String
    @EnvironmentObject var boardsViewModel: BoardsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var post: Post?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(NSLocalizedString("loading.post", comment: ""))
            } else if let error = error {
                VStack {
                    Text(NSLocalizedString("error.loading_post", comment: ""))
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let post = post {
                PostDetailView(post: post, board: board)
                    .environmentObject(boardsViewModel)
                    .environmentObject(authViewModel)
            }
        }
        .task {
            await loadPost()
        }
    }

    private func loadPost() async {
        // Load posts for this board
        await boardsViewModel.loadPosts(boardSlug: board.slug, refresh: true)

        // Find the specific post
        if let foundPost = boardsViewModel.posts.first(where: { $0.id == postId }) {
            post = foundPost
        } else {
            error = NSLocalizedString("error.post_not_found", comment: "")
        }
        isLoading = false
    }
}

struct SignInTabView: View {
    var body: some View {
        NavigationView {
            LoginView()
                .navigationTitle(NSLocalizedString("auth.sign_in", comment: ""))
        }
    }
}

struct ProfileAndCommunitiesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Info
                    if let user = authViewModel.currentUser {
                        VStack(spacing: 10) {
                            CachedCircularImage(
                                url: user.avatarImageURL,
                                size: 80
                            )
                            .onTapGesture {
                                showLogoutConfirmation = true
                            }

                            Text(user.loginName)
                                .font(.title)
                                .fontWeight(.bold)

                            if let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            if user.isAdmin {
                                Label(NSLocalizedString("status.admin", comment: ""), systemImage: "star.fill")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.yellow)
                                    .foregroundColor(.black)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }

                    // Current Community & Profile
                    if let community = communityContext.currentCommunity {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("Current Community", comment: ""))
                                .font(.headline)
                                .padding(.horizontal)

                            CommunityCardView(community: community)
                                .padding(.horizontal)

                            if let profile = profileContext.currentProfile {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("Active Profile", comment: ""))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)

                                    HStack(spacing: 12) {
                                        CachedCircularImage(url: profile.avatarURL, size: 40)

                                        VStack(alignment: .leading) {
                                            Text(profile.name)
                                                .font(.headline)
                                            Text("@\(profile.username)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    Divider()

                    // Quick Actions
                    if profileContext.currentProfile != nil {
                        VStack(spacing: 0) {
                            NavigationLink(destination: BookmarksView().environmentObject(profileContext)) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text(NSLocalizedString("profile.bookmarks", comment: ""))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider()
                                .padding(.leading, 44)

                            NavigationLink(destination: SearchView().environmentObject(profileContext)) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text(NSLocalizedString("profile.search_posts", comment: ""))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Divider()
                            .padding(.vertical)
                    }

                    // Communities section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("profile.my_communities", comment: "My Communities"))
                                .font(.headline)

                            Spacer()

                            CommunitySwitcher()
                        }
                        .padding(.horizontal)

                        if communityContext.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let error = communityContext.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .padding()
                        } else if communityContext.availableCommunities.isEmpty {
                            Text(NSLocalizedString("profile.no_communities", comment: "No communities"))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(communityContext.availableCommunities) { community in
                                    CommunityCardView(community: community)
                                        .onTapGesture {
                                            Task {
                                                await communityContext.switchCommunity(to: community)
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle(NSLocalizedString("nav.profile", comment: ""))
            .alert(NSLocalizedString("auth.logout_confirm_title", comment: ""), isPresented: $showLogoutConfirmation) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
                Button(NSLocalizedString("auth.logout", comment: ""), role: .destructive) {
                    Task {
                        await authViewModel.logout()
                    }
                }
            } message: {
                Text(NSLocalizedString("auth.logout_confirm_message", comment: ""))
            }
            .refreshable {
                await communityContext.refreshCurrentCommunity()
            }
        }
    }
}
