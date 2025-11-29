import Foundation
import SwiftUI
import Combine

@MainActor
class ProfileContext: ObservableObject {
    @Published var currentProfileId: String?
    @Published var currentProfile: AppProfile?
    @Published var availableProfiles: [AppProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var communityId: String?
    private let userDefaultsKeyPrefix = "currentProfileId_"
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for community changes
        NotificationCenter.default.publisher(for: .communityDidChange)
            .sink { [weak self] notification in
                if let communityId = notification.object as? String {
                    Task { @MainActor in
                        await self?.handleCommunityChange(communityId: communityId)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Profiles for Community

    func loadProfiles(for communityId: String) async {
        self.communityId = communityId
        isLoading = true
        errorMessage = nil

        do {
            let profiles = try await ProfileService.shared.getUserProfiles()
            availableProfiles = profiles

            // Restore saved profile for this community, or select primary (default) profile
            let savedProfileId = UserDefaults.standard.string(forKey: userDefaultsKey(for: communityId))
            let savedProfile = savedProfileId.flatMap { id in profiles.first { $0.id == id } }
            let primaryProfile = profiles.first { $0.isPrimary }
            let profile = savedProfile ?? primaryProfile ?? profiles.first

            if let profile = profile {
                await switchProfile(to: profile)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load profiles: \(error)")
        }

        isLoading = false
    }

    // MARK: - Switch Profile

    func switchProfile(to profile: AppProfile) async {
        guard let communityId = communityId else {
            print("Cannot switch profile: no community context")
            return
        }

        currentProfileId = profile.id
        currentProfile = profile

        // Persist selection per community
        UserDefaults.standard.set(profile.id, forKey: userDefaultsKey(for: communityId))

        print("Switched to profile: \(profile.name) (@\(profile.username)) in community \(communityId)")
    }

    // MARK: - Create Profile

    func createProfile(name: String, username: String, bio: String?, profilePictureId: String?) async throws {
        let request = ProfileCreateRequest(
            name: name,
            username: username,
            bio: bio,
            isPrimary: availableProfiles.isEmpty, // First profile is primary
            profilePictureId: profilePictureId
        )

        let newProfile = try await ProfileService.shared.createProfile(request: request)
        availableProfiles.append(newProfile)

        // Auto-select if it's the first profile
        if availableProfiles.count == 1 {
            await switchProfile(to: newProfile)
        }
    }

    // MARK: - Update Profile

    func updateProfile(profileId: String, name: String, username: String, bio: String?, profilePictureId: String?) async throws {
        let request = ProfileUpdateRequest(
            name: name,
            username: username,
            bio: bio,
            profilePictureId: profilePictureId
        )

        let updatedProfile = try await ProfileService.shared.updateProfile(profileId: profileId, request: request)

        // Update in list
        if let index = availableProfiles.firstIndex(where: { $0.id == profileId }) {
            availableProfiles[index] = updatedProfile
        }

        // Update current if it's the selected one
        if currentProfileId == profileId {
            currentProfile = updatedProfile
        }
    }

    // MARK: - Delete Profile

    func deleteProfile(profileId: String) async throws {
        try await ProfileService.shared.deleteProfile(profileId: profileId)

        // Remove from list
        availableProfiles.removeAll { $0.id == profileId }

        // If we deleted the current profile, switch to another
        if currentProfileId == profileId {
            if let firstProfile = availableProfiles.first {
                await switchProfile(to: firstProfile)
            } else {
                currentProfile = nil
                currentProfileId = nil
            }
        }
    }

    // MARK: - Set Primary Profile

    func setPrimaryProfile(profileId: String) async throws {
        try await ProfileService.shared.setPrimaryProfile(profileId: profileId)

        // Update local state
        for i in 0..<availableProfiles.count {
            availableProfiles[i] = AppProfile(
                id: availableProfiles[i].id,
                name: availableProfiles[i].name,
                username: availableProfiles[i].username,
                bio: availableProfiles[i].bio,
                profilePictureUrl: availableProfiles[i].profilePictureUrl,
                isPrimary: availableProfiles[i].id == profileId,
                createdAt: availableProfiles[i].createdAt,
                updatedAt: availableProfiles[i].updatedAt,
                activatedAt: availableProfiles[i].activatedAt,
                role: availableProfiles[i].role
            )
        }

        if currentProfileId == profileId {
            currentProfile = availableProfiles.first { $0.id == profileId }
        }
    }

    // MARK: - Upload Profile Picture

    func uploadProfilePicture(imageData: Data, filename: String) async throws -> String {
        let picture = try await ProfileService.shared.uploadProfilePicture(imageData: imageData, filename: filename)
        return picture.id
    }

    // MARK: - Clear on Logout

    func clear() {
        currentProfileId = nil
        currentProfile = nil
        availableProfiles = []
        communityId = nil
    }

    // MARK: - Private Helpers

    private func userDefaultsKey(for communityId: String) -> String {
        return "\(userDefaultsKeyPrefix)\(communityId)"
    }

    private func handleCommunityChange(communityId: String) async {
        // Clear current state
        currentProfile = nil
        currentProfileId = nil
        availableProfiles = []

        // Load profiles for new community
        await loadProfiles(for: communityId)
    }
}
