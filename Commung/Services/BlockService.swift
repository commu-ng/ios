import Foundation

struct BlockedUser: Codable, Identifiable {
    let id: String
    let loginName: String
    let blockedAt: String
}

struct BlockedUsersResponse: Codable {
    let data: [BlockedUser]
}

struct BlockResponse: Codable {
    let data: BlockResponseData
}

struct BlockResponseData: Codable {
    let blocked: Bool?
    let unblocked: Bool?
}

private struct EmptyBody: Codable {}

class BlockService {
    static let shared = BlockService()

    private init() {}

    // MARK: - Get Blocked Users

    func getBlockedUsers() async throws -> [BlockedUser] {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/blocks")!
        let response: BlockedUsersResponse = try await APIClient.shared.get(url: url)
        return response.data
    }

    // MARK: - Block User

    func blockUser(userId: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/blocks/\(userId)")!
        let _: BlockResponse = try await APIClient.shared.post(url: url, body: EmptyBody())
    }

    // MARK: - Unblock User

    func unblockUser(userId: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/blocks/\(userId)")!
        try await APIClient.shared.delete(url: url)
    }
}
