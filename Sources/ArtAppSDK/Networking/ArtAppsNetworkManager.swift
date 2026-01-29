
import Combine
import Foundation

enum ArtAppsNetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
}

struct ArtAppsAdResponse: Codable {
    let requestId: String? // Changed to optional
    let finalUrl: String?  // Changed to optional (can be missing if allow=false)
    let ttl: Int? // Changed to optional (can be missing if allow=false)
    let allow: Bool
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

@MainActor
class ArtAppsNetworkManager {
    @MainActor static let shared = ArtAppsNetworkManager()
    private init() {}
    
    var baseURL = "https://api.adw.net/applovin/request"
    
    func fetchAd(partnerId: String, appId: String, placementId: String, completion: @escaping @Sendable (Result<ArtAppsAdResponse, Error>) -> Void) {
        // Construct URL components
        guard var components = URLComponents(string: baseURL) else {
#if DEBUG
            // Fallback for demo purposes if URL is not real yet
            mockResponse(completion: completion)
#else
            completion(.failure(ArtAppsNetworkError.invalidURL))
#endif
            return
        }
        
        components.queryItems = [
            URLQueryItem(name: "partner_id", value: partnerId),
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "placement", value: placementId),
            URLQueryItem(name: "idfa_status", value: idfaStatusString())
        ]
        
        guard let url = components.url else {
            completion(.failure(ArtAppsNetworkError.invalidURL))
            return
        }
        
#if DEBUG
        // For now, if the domain is placeholder, return mock immediately
        if baseURL.contains("your-server-domain.com") {
            mockResponse(completion: completion)
            return
        }
#endif
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5 // Fast timeout as requested
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                
                guard !data.isEmpty else {
                    completion(.failure(ArtAppsNetworkError.noData))
                    return
                }
                
                let adResponse = try JSONDecoder().decode(ArtAppsAdResponse.self, from: data)
                
                completion(.success(adResponse))
                
            } catch let decodingError as DecodingError {
                print("[ArtApps] Decode failed: \(decodingError)")
                completion(.failure(ArtAppsNetworkError.decodingError))
                
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func mockResponse(completion: @escaping @Sendable (Result<ArtAppsAdResponse, Error>) -> Void) {
        // Simulate network delay slightly
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let mock = ArtAppsAdResponse(
                requestId: UUID().uuidString,
                finalUrl: "https://globytrace.com/mdHtMx", // Demo URL
                ttl: 3600,
                allow: true,
                cooldownSec: 60,
                sessionGate: 30,
                fallback: false,
                trackUrl: "https://api.adw.net/applovin/track?request_id=mock_id&event=impression"
            )
            DispatchQueue.main.async {
                completion(.success(mock))
            }
        }
    }
    
    func trackImpression(requestId: String, trackUrl: String?) {
        let urlTarget: URL?
        
        if let trackUrlString = trackUrl, let url = URL(string: trackUrlString) {
            urlTarget = url
        } else {
            // Fallback manual construction if trackUrl is missing
            let trackingURLString = "https://api.adw.net/applovin/track"
            guard var components = URLComponents(string: trackingURLString) else { return }
            components.queryItems = [
                URLQueryItem(name: "request_id", value: requestId),
                URLQueryItem(name: "event", value: "impression")
            ]
            urlTarget = components.url
        }
        
        guard let url = urlTarget else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request).resume()
        print("[ArtApps] Impression tracking sent to: \(url.absoluteString)")
    }
}

import AppTrackingTransparency
import AdSupport

func idfaStatusString() -> String {
    if #available(iOS 14, *) {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "unknown"
        }
    } else {
        return "notDetermined"
    }
}
