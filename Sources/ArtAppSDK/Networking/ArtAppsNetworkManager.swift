
import Combine
import Foundation

@MainActor
class ArtAppsNetworkManager {
    @MainActor static let shared = ArtAppsNetworkManager()
    private init() {}
    
    var baseURL = "https://api.adw.net/applovin/request"
    
    func fetchAd(partnerId: String, appId: String, placementId: String, completion: @escaping @Sendable (Result<ArtAppsAdResponse, Error>) -> Void) {
        
        guard var components = URLComponents(string: baseURL) else {
            completion(.failure(ArtAppsNetworkError.invalidURL))
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
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[ArtApps] Raw Server Response: \(jsonString)")
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
