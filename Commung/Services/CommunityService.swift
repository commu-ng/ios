import Foundation

class CommunityService {
    static let shared = CommunityService()

    private init() {}

    func getUserCommunities() async throws -> [Community] {
        let response: DataResponse<[Community]> = try await APIClient.shared.request(
            endpoint: "/console/communities/mine",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }
}
