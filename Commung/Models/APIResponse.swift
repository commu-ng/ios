import Foundation

struct APIErrorDetail: Codable {
    let code: String
    let message: String
    let details: [String: String]?
}

struct APIError: Codable {
    let error: APIErrorDetail
}

struct ErrorResponse: Codable {
    let error: APIErrorDetail
}
