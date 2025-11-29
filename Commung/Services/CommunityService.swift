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

    func getRecruitingCommunities() async throws -> [Community] {
        let response: DataResponse<[Community]> = try await APIClient.shared.request(
            endpoint: "/console/communities/recruiting",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func getOngoingCommunities() async throws -> [Community] {
        let response: DataResponse<[Community]> = try await APIClient.shared.request(
            endpoint: "/console/communities/ongoing",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func getCommunityDetails(slug: String) async throws -> CommunityDetails {
        let response: DataResponse<CommunityDetails> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func getCommunityLinks(slug: String) async throws -> [CommunityLink] {
        let response: DataResponse<[CommunityLink]> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)/links",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func applyToCommunity(slug: String, profileName: String, profileUsername: String, message: String?) async throws -> CommunityApplication {
        struct ApplyRequest: Encodable {
            let profileName: String
            let profileUsername: String
            let message: String?

            enum CodingKeys: String, CodingKey {
                case profileName = "profile_name"
                case profileUsername = "profile_username"
                case message
            }
        }

        let request = ApplyRequest(
            profileName: profileName,
            profileUsername: profileUsername,
            message: message
        )

        let response: DataResponse<CommunityApplication> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)/apply",
            method: "POST",
            body: request,
            requiresAuth: true
        )
        return response.data
    }

    func getMyApplications(slug: String) async throws -> [CommunityApplication] {
        let response: DataResponse<[CommunityApplication]> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)/my-applications",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func getCommunityApplications(slug: String) async throws -> [CommunityApplicationDetail] {
        let response: DataResponse<[CommunityApplicationDetail]> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)/applications",
            method: "GET",
            requiresAuth: true
        )
        return response.data
    }

    func approveApplication(slug: String, applicationId: String) async throws -> ApplicationReviewResponse {
        struct ReviewRequest: Encodable {
            let status: String
        }

        let request = ReviewRequest(status: "approved")

        let response: DataResponse<ApplicationReviewResponse> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)/applications/\(applicationId)/review",
            method: "PUT",
            body: request,
            requiresAuth: true
        )
        return response.data
    }

    func rejectApplication(slug: String, applicationId: String, reason: String?) async throws -> ApplicationReviewResponse {
        struct ReviewRequest: Encodable {
            let status: String
            let rejectionReason: String?

            enum CodingKeys: String, CodingKey {
                case status
                case rejectionReason = "rejection_reason"
            }
        }

        let request = ReviewRequest(status: "rejected", rejectionReason: reason)

        let response: DataResponse<ApplicationReviewResponse> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(slug)/applications/\(applicationId)/review",
            method: "PUT",
            body: request,
            requiresAuth: true
        )
        return response.data
    }

    func createCommunity(request: CommunityCreateRequest) async throws -> CommunityCreateResponse {
        let response: DataResponse<CommunityCreateResponse> = try await APIClient.shared.request(
            endpoint: "/console/communities",
            method: "POST",
            body: request,
            requiresAuth: true
        )
        return response.data
    }

    func updateCommunity(communityId: String, request: CommunityUpdateRequest) async throws -> CommunityUpdateResponse {
        let response: DataResponse<CommunityUpdateResponse> = try await APIClient.shared.request(
            endpoint: "/console/communities/\(communityId)",
            method: "PUT",
            body: request,
            requiresAuth: true
        )
        return response.data
    }

    func deleteCommunity(communityId: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: "/console/communities/\(communityId)",
            method: "DELETE",
            requiresAuth: true
        )
    }

    func uploadImage(imageData: Data, fileName: String) async throws -> ImageUploadResponse {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(Constants.apiBaseURL)/console/upload/file")!)
        request.httpMethod = "POST"

        if let sessionToken = KeychainService.shared.load(forKey: Constants.Keychain.sessionTokenKey) {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let wrappedResponse = try decoder.decode(DataResponse<ImageUploadResponse>.self, from: data)
        return wrappedResponse.data
    }
}
