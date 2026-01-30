import Foundation

enum ArtAppsNetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
}

struct ArtAppsAdResponse: Codable {
    let requestId: String?
    let finalUrl: String?
    let ttl: Int?
    let allow: Bool?
    let cooldownSec: Int?
    let sessionGate: Int?
    let fallback: Bool?
    let trackUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case finalUrl = "final_url"
        case ttl
        case allow
        case cooldownSec = "cooldown_sec"
        case sessionGate = "session_gate"
        case fallback
        case trackUrl = "track_url"
    }
}
