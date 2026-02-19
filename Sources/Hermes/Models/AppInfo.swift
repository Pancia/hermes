import Foundation

struct AppInfo: Codable {
    let name: String
    let path: String
    var icon: String?
    var lastUsed: Double?
}
