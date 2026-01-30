 import UIKit

@MainActor
public protocol ArtAppsInterstitialDelegate: AnyObject {
    func artAppsInterstitialDidLoad(_ ad: ArtAppsInterstitial)
    func artAppsInterstitial(_ ad: ArtAppsInterstitial, didFailToLoad error: Error)
    func artAppsInterstitialDidDisplay(_ ad: ArtAppsInterstitial)
    func artAppsInterstitialDidHide(_ ad: ArtAppsInterstitial)
    func artAppsInterstitialDidClick(_ ad: ArtAppsInterstitial) // Optional depending on WebView interaction
}

@MainActor
public class ArtAppsInterstitial: NSObject {
    
    public weak var delegate: ArtAppsInterstitialDelegate?
    public private(set) var isReady: Bool = false
    
    private let placementId: String
    private var adResponse: ArtAppsAdResponse?
    private var presenter: ArtAppsWebViewController?
    private var adDisplayStartTime: Date?
    
    public init(placementId: String) {
        self.placementId = placementId
        super.init()
    }
    
    public func load() {
        guard let partnerId = ArtApps.shared.partnerId, let appId = ArtApps.shared.appId else {
            print("[ArtApps] Error: SDK not initialized. Call ArtApps.initialize() first.")
            let error = NSError(domain: "com.artApps.sdk", code: 100, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized"])
            delegate?.artAppsInterstitial(self, didFailToLoad: error)
            return
        }
        
        // Check Pilot Rules (Session Gate / Frequency Cap)
        if !ArtApps.shared.canShowAd() {
            let error = NSError(domain: "com.artApps.sdk", code: 205, userInfo: [NSLocalizedDescriptionKey: "Frequency/Session Cap"])
            delegate?.artAppsInterstitial(self, didFailToLoad: error)
            return
        }
        
        isReady = false
        ArtAppsNetworkManager.shared.fetchAd(partnerId: partnerId, appId: appId, placementId: placementId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    ArtApps.shared.updateServerRestrictions(
                        cooldownSeconds: response.cooldownSec,
                        sessionGateSeconds: response.sessionGate,
                        ttlSeconds: response.ttl
                    )
                    
                    if response.allow == true {
                        self.adResponse = response
                        
                        self.isReady = true
                        print("[ArtApps] Interstitial loaded for placement: \(self.placementId)")
                        self.delegate?.artAppsInterstitialDidLoad(self)
                    } else {
                        let error = NSError(domain: "com.artApps.sdk", code: 204, userInfo: [NSLocalizedDescriptionKey: "No Fill"])
                        print("[ArtApps] No fill for placement: \(self.placementId)")
                        self.delegate?.artAppsInterstitial(self, didFailToLoad: error)
                    }
                case .failure(let error):
                    print("[ArtApps] Load failed: \(error.localizedDescription)")
                    self.delegate?.artAppsInterstitial(self, didFailToLoad: error)
                }
            }
        }
    }
    
    public func show(from viewController: UIViewController) {
        guard isReady else {
            let error = NSError(domain: "com.artApps.sdk", code: 301, userInfo: [NSLocalizedDescriptionKey: "Ad not ready"])
            print("[ArtApps] Error: Ad not ready.")
            delegate?.artAppsInterstitial(self, didFailToLoad: error)
            return
        }
        
        guard let finalUrlString = adResponse?.finalUrl, !finalUrlString.isEmpty else {
            let error = NSError(domain: "com.artApps.sdk", code: 302, userInfo: [NSLocalizedDescriptionKey: "Missing ad URL"])
            print("[ArtApps] Error: Missing ad URL.")
            delegate?.artAppsInterstitial(self, didFailToLoad: error)
            return
        }
        
        guard let url = URL(string: finalUrlString) else {
            let error = NSError(domain: "com.artApps.sdk", code: 303, userInfo: [NSLocalizedDescriptionKey: "Invalid ad URL"])
            print("[ArtApps] Error: Invalid ad URL.")
            delegate?.artAppsInterstitial(self, didFailToLoad: error)
            return
        }
        
        presenter = ArtAppsWebViewController(url: url)
        presenter?.delegate = self
        
        presenter?.modalPresentationStyle = .fullScreen
        viewController.present(presenter!, animated: true)
    }
}

// MARK: - ArtAppsWebViewControllerDelegate
extension ArtAppsInterstitial: ArtAppsWebViewControllerDelegate {
    
    func webViewControllerDidLoad(_ controller: ArtAppsWebViewController) {
        adDisplayStartTime = Date()
        ArtApps.shared.didShowAd() // Record impression timestamp for freq cap
        delegate?.artAppsInterstitialDidDisplay(self)
        
        // Tracking impression logic: send to your server
        if let requestId = adResponse?.requestId {
            ArtAppsNetworkManager.shared.trackImpression(requestId: requestId, trackUrl: adResponse?.trackUrl)
        }
    }
    
    func webViewControllerDidFinish(_ controller: ArtAppsWebViewController) {
        if let startTime = adDisplayStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("[ArtApps] Ad was visible for \(Int(duration)) seconds")
        }
        
        delegate?.artAppsInterstitialDidHide(self)
        isReady = false // Reset readiness
        self.presenter = nil
    }
    
    func webViewController(_ controller: ArtAppsWebViewController, didFailWithError error: Error) {
        // Handle load error during presentation if needed
        print("[ArtApps] WebView failed: \(error.localizedDescription)")
    }
}
