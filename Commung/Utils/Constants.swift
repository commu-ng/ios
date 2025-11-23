import Foundation

enum Constants {
    static let apiBaseURL = "https://api.commu.ng"

    static let COMMUNITY_TYPE_LABELS: [String: String] = [
        "twitter": "트위터",
        "band": "밴드",
        "mastodon": "마스토돈",
        "discord": "디스코드",
        "oeee_cafe": "오이카페",
        "commung": "커뮹"
    ]

    enum Keychain {
        static let sessionTokenKey = "sessionToken"
        static let service = "ng.commu"
    }
}
