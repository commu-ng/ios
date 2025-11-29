import Foundation

// MARK: - API Response Wrappers

struct ApiResponse<T: Decodable>: Decodable {
    let data: T
}

struct ApiPaginatedResponse<T: Decodable>: Decodable {
    let data: T
    let pagination: ApiPagination
}

struct ApiPagination: Codable {
    let nextCursor: String?
    let hasMore: Bool
    let totalCount: Int?
}

class APIClient {
    static let shared = APIClient()
    static let apiBaseURL = Constants.apiBaseURL
    static let consoleDomain = "commu.ng"

    private init() {}

    private var sessionToken: String? {
        KeychainService.shared.load(forKey: Constants.Keychain.sessionTokenKey)
    }

    // Community context for mobile app - set this before making app API calls
    var currentCommunity: Community?

    // MARK: - Generic Request (deprecated - use specific methods below)

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: Constants.apiBaseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        print("📡 API Request: \(method) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        if httpResponse.statusCode >= 500 {
            print("❌ Server Error (5XX): \(httpResponse.statusCode) - \(url.absoluteString)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
        }

        if httpResponse.statusCode >= 400 {
            print("❌ API Error: \(httpResponse.statusCode) - \(url.absoluteString)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error.message)
            }
            throw NetworkError.serverError("Client error: \(httpResponse.statusCode)")
        }

        // Handle 204 No Content
        if httpResponse.statusCode == 204 || data.isEmpty {
            if T.self == EmptyResponse.self {
                print("✅ API Success (No Content): \(url.absoluteString)")
                return EmptyResponse() as! T
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(T.self, from: data)
            print("✅ API Success: \(url.absoluteString)")
            return result
        } catch {
            print("❌ Decoding error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw NetworkError.decodingError
        }
    }

    // MARK: - Convenience Methods

    func get<T: Decodable>(url: URL, requiresAuth: Bool = true) async throws -> T {
        return try await performRequest(url: url, method: "GET", body: nil as String?, requiresAuth: requiresAuth)
    }

    func post<T: Decodable, B: Encodable>(url: URL, body: B, requiresAuth: Bool = true) async throws -> T {
        return try await performRequest(url: url, method: "POST", body: body, requiresAuth: requiresAuth)
    }

    func patch<T: Decodable, B: Encodable>(url: URL, body: B, requiresAuth: Bool = true) async throws -> T {
        return try await performRequest(url: url, method: "PATCH", body: body, requiresAuth: requiresAuth)
    }

    func put<T: Decodable, B: Encodable>(url: URL, body: B, requiresAuth: Bool = true) async throws -> T {
        return try await performRequest(url: url, method: "PUT", body: body, requiresAuth: requiresAuth)
    }

    func delete(url: URL, requiresAuth: Bool = true) async throws {
        let _: EmptyResponse = try await performRequest(url: url, method: "DELETE", body: nil as String?, requiresAuth: requiresAuth)
    }

    // MARK: - Core Request Method

    private func performRequest<T: Decodable, B: Encodable>(
        url: URL,
        method: String,
        body: B?,
        requiresAuth: Bool
    ) async throws -> T {
        print("📡 API Request: \(method) \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add Origin header for community context (mobile app requirement)
        if let community = currentCommunity {
            let origin = buildOriginHeader(for: community)
            request.setValue(origin, forHTTPHeaderField: "Origin")
            print("🌐 Origin: \(origin)")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        if httpResponse.statusCode >= 500 {
            print("❌ Server Error (5XX): \(httpResponse.statusCode) - \(url.absoluteString)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
        }

        if httpResponse.statusCode >= 400 {
            print("❌ API Error: \(httpResponse.statusCode) - \(url.absoluteString)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorResponse.error.message)
            }
            throw NetworkError.serverError("Client error: \(httpResponse.statusCode)")
        }

        // Handle 204 No Content
        if httpResponse.statusCode == 204 || data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(T.self, from: data)
            print("✅ API Success: \(url.absoluteString)")
            return result
        } catch {
            print("❌ Decoding error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw NetworkError.decodingError
        }
    }

    // MARK: - File Upload

    func uploadFile<T: Decodable>(
        url: URL,
        fileData: Data,
        filename: String,
        fieldName: String,
        requiresAuth: Bool = true
    ) async throws -> T {
        print("📡 File Upload: POST \(url.absoluteString)")

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add Origin header for community context (mobile app requirement)
        if let community = currentCommunity {
            let origin = buildOriginHeader(for: community)
            request.setValue(origin, forHTTPHeaderField: "Origin")
            print("🌐 Origin: \(origin)")
        }

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        if httpResponse.statusCode >= 500 {
            print("❌ Server Error (5XX): \(httpResponse.statusCode)")
            throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
        }

        if httpResponse.statusCode >= 400 {
            print("❌ Upload Error: \(httpResponse.statusCode)")
            throw NetworkError.serverError("Upload error: \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(T.self, from: data)
            print("✅ Upload Success")
            return result
        } catch {
            print("❌ Decoding error: \(error)")
            throw NetworkError.decodingError
        }
    }

    // MARK: - Session Management

    func clearSession() async {
        _ = KeychainService.shared.delete(forKey: Constants.Keychain.sessionTokenKey)
    }

    // MARK: - Helper Methods

    private func buildOriginHeader(for community: Community) -> String {
        // Prefer custom domain if available and verified
        if let customDomain = community.customDomain,
           let verified = community.domainVerified,
           !verified.isEmpty {
            return "https://\(customDomain)"
        }

        // Otherwise use subdomain format
        return "https://\(community.slug).\(Self.consoleDomain)"
    }
}

// MARK: - Helper Types

struct EmptyResponse: Codable {}
