import Foundation
import UIKit

struct RegisterDeviceRequest: Encodable {
    let pushToken: String
    let platform: String = "ios"
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?
}

struct DeviceResponseData: Decodable {
    let pushToken: String
    let registered: Bool
    let registeredAt: String
}

struct DeviceResponse: Decodable {
    let data: DeviceResponseData
}

class DeviceService {
    static let shared = DeviceService()

    private init() {}

    func registerDevice(pushToken: String) async throws {
        let deviceModel = UIDevice.current.model
        let osVersion = "iOS \(UIDevice.current.systemVersion)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        let request = RegisterDeviceRequest(
            pushToken: pushToken,
            deviceModel: deviceModel,
            osVersion: osVersion,
            appVersion: appVersion
        )

        let _: DeviceResponse = try await APIClient.shared.request(
            endpoint: "/console/devices",
            method: "POST",
            body: request,
            requiresAuth: true
        )

        print("✅ Device registered successfully")
    }

    func deleteDevice(pushToken: String) async throws {
        let url = URL(string: "\(APIClient.apiBaseURL)/console/devices/\(pushToken)")!
        try await APIClient.shared.delete(url: url, requiresAuth: false)

        print("✅ Device deleted successfully")
    }
}
