//
//  ContentView.swift
//  Commung
//
//  Created by Jihyeok Seo on 11/16/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var communityContext: CommunityContext
    @EnvironmentObject var profileContext: ProfileContext
    @StateObject private var boardsViewModel = BoardsViewModel()
    @State private var isInitialLoadComplete = false

    private var isLoading: Bool {
        authViewModel.isLoading || (authViewModel.isAuthenticated && !isInitialLoadComplete)
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(NSLocalizedString("loading.app", comment: "Loading..."))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MainTabView(boardsViewModel: boardsViewModel)
            }
        }
        .task {
            await loadInitialData()
        }
    }
}

extension ContentView {
    func loadInitialData() async {
        // Wait for auth to finish loading
        while authViewModel.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        guard authViewModel.isAuthenticated else {
            isInitialLoadComplete = true
            return
        }

        // Load all initial data in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await communityContext.loadCommunities()
            }
            group.addTask {
                await boardsViewModel.loadBoards()
            }
            await group.waitForAll()
        }

        // Load profiles for current community if one is selected
        if let currentCommunityId = communityContext.currentCommunityId {
            await profileContext.loadProfiles(for: currentCommunityId)
        }

        isInitialLoadComplete = true
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(CommunityContext())
        .environmentObject(ProfileContext())
        .environmentObject(AppModeContext())
}
