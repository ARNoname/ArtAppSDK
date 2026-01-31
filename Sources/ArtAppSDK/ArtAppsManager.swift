import Foundation
import AppLovinSDK
import UIKit

@MainActor
public class ArtAppsManager: NSObject {
    
    public static let shared = ArtAppsManager()
    
    private var interstitialAd: MAInterstitialAd?
    private var adUnitId: String?
    private var sdkKey: String?
    
    private var retryAttempt = 0.0
    private var isLoading = false
    
    // Callback for when ad is loaded (optional, helpful for UI updates)
    public var onAdLoaded: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    public func initialize(adUnitId: String, sdkKey: String) {
        self.adUnitId = adUnitId
        self.sdkKey = sdkKey
        
        initializeSDK()
    }
    
    private func initializeSDK() {
        guard let sdkKey = sdkKey else { return }
        
        // Create the initialization configuration
        let initConfig = ALSdkInitializationConfiguration(sdkKey: sdkKey) { builder in
            builder.mediationProvider = ALMediationProviderMAX
        }
        
        // Initialize the SDK
        ALSdk.shared().initialize(with: initConfig) { [weak self] _ in
            guard let self = self else { return }
            print("[ArtAppsManager] AppLovin SDK Initialized")
            
            DispatchQueue.main.async {
                // Initialize interstitial
                if let adUnitId = self.adUnitId {
                    self.interstitialAd = MAInterstitialAd(adUnitIdentifier: adUnitId)
                    self.interstitialAd?.delegate = self
                    
                    // Initial load
                    self.load()
                }
            }
        }
    }
    
    public func load() {
        guard let interstitialAd = interstitialAd else {
            print("[ArtAppsManager] Ad not initialized yet")
            return
        }
        
        if isLoading {
            print("[ArtAppsManager] Load skipped: Ad is already loading.")
            return
        }
        
        print("[ArtAppsManager] Loading ad...")
        isLoading = true
        interstitialAd.load()
    }
    
    public func show() {
        guard let interstitialAd = interstitialAd else {
            print("[ArtAppsManager] Ad not initialized")
            return
        }
        
        // Check Session Gate / Freq Cap locally first!
        // This prevents notifying AppLovin of a "failure" and keeps the ad ready.
        if !ArtApps.shared.canShowAd() {
            print("[ArtAppsManager] Show blocked by Session Gate/Freq Cap. Waiting 10s to retry...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.show()
            }
            return
        }
        
        if interstitialAd.isReady {
            interstitialAd.show()
        } else {
            print("[ArtAppsManager] Ad not ready to show")
            // Optionally trigger a load if strictly not ready (though auto-retries handle most cases)
            load()
        }
    }
    
    public var isReady: Bool {
        return interstitialAd?.isReady ?? false
    }
}

// MARK: - MAAdDelegate
extension ArtAppsManager: @MainActor MAAdDelegate {
    
    public func didLoad(_ ad: MAAd) {
        print("[ArtAppsManager] Ad Loaded")
        
        isLoading = false
        // Reset retry attempt on success
        retryAttempt = 0.0
        
        onAdLoaded?()
        
        // Optional: Auto-show behavior if desired, but user asked for explicit .show() calls usually.
        // However, in previous TimerApp logic, strict 'show' was called in didLoad. 
        // We will stick to passively defining it here, user calls show().
    }
    
    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        print("[ArtAppsManager] Ad Failed to Load: \(error.message). Code: \(error.code.rawValue)")
        
        isLoading = false
        
        // Exponential retry logic (AppLovin recommendation)
        retryAttempt += 1
        let delaySec = pow(2.0, min(6.0, retryAttempt))
        
        print("[ArtAppsManager] Scheduling retry in \(delaySec) seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySec) {
            print("[ArtAppsManager] Retrying load now...")
            self.load()
        }
    }
    
    public func didDisplay(_ ad: MAAd) {
        print("[ArtAppsManager] Ad Displayed")
    }
    
    public func didHide(_ ad: MAAd) {
        print("[ArtAppsManager] Ad Hidden. Reloading...")
        load()
    }
    
    public func didClick(_ ad: MAAd) {
        print("[ArtAppsManager] Ad Clicked")
    }
    
    public func didFail(toDisplay ad: MAAd, withError error: MAError) {
        print("[ArtAppsManager] Failed to Display Ad: \(error.message). Retry in 10s...")
        
        // Retry logic for display failure (Session Gate block)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            print("[ArtAppsManager] Retrying...")
            
            if self.isReady {
                print("[ArtAppsManager] Ad is still ready. Retrying show()...")
                self.show()
            } else {
                print("[ArtAppsManager] Ad not ready. Retrying load()...")
                self.load()
            }
        }
    }
}
