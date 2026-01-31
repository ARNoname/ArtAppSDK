import Foundation
import AppLovinSDK
import UIKit

@MainActor
public class ArtAppsManager: NSObject, ObservableObject {
  
    private var interstitialAd: MAInterstitialAd?
    private let adUnitId: String
    private let sdkKey: String
    
    // Callback for when ad is loaded (optional, helpful for UI updates)
    public var onAdLoaded: (() -> Void)?
    
    public init(adUnitId: String, sdkKey: String) {
        self.adUnitId = adUnitId
        self.sdkKey = sdkKey
        super.init()
        initializeSDK()
    }
    
    private func initializeSDK() {
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
                self.interstitialAd = MAInterstitialAd(adUnitIdentifier: self.adUnitId)
                self.interstitialAd?.delegate = self
                
                // Initial load
                self.load()
            }
        }
    }
    
    public func load() {
        guard let interstitialAd = interstitialAd else {
            print("[ArtAppsManager] Ad not initialized yet")
            return
        }
        print("[ArtAppsManager] Loading ad...")
        interstitialAd.load()
    }
    
    public func show() {
        guard let interstitialAd = interstitialAd else {
            print("[ArtAppsManager] Ad not initialized")
            return
        }
        
        // We can check our own rules locally if needed, but Adapter handles it too.
        // It's safer to let the Adapter reject 'show' if session gate is active, 
        // triggering didFail(toDisplay) -> retry loop.
        
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
        onAdLoaded?()
        
        // Optional: Auto-show behavior if desired, but user asked for explicit .show() calls usually.
        // However, in previous TimerApp logic, strict 'show' was called in didLoad. 
        // We will stick to passively defining it here, user calls show().
    }
    
    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        print("[ArtAppsManager] Ad Failed to Load: \(error.message). Code: \(error.code.rawValue)")
        
        // Retry logic moved here from AppDelegate
        print("[ArtAppsManager] Scheduling retry in 10 seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
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
            print("[ArtAppsManager] Retrying (load -> show cycle via load)...")
            // Note: In strict MAX flows, we often need to call load() again if show fails? 
            // Or just try showing again if it's still "ready"? 
            // In our Adapter logic, "failed to display" might not consume the ad if it was just blocked logic.
            // But MAX might consider it "attempted". safer to Load.
            self.load()
        }
    }
}
