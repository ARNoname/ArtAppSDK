
import Foundation
import UIKit
import AppLovinSDK

@objc(ArtAppsMaxAdapter)
public class ArtAppsMaxAdapter: ALMediationAdapter, MAInterstitialAdapter {

    private var interstitialAd: ArtAppsInterstitial?
    private var adapterDelegate: ArtAppsInterstitialAdapterDelegate?
    
    // MARK: - MAAdapter Methods

    public override func initialize(with parameters: MAAdapterInitializationParameters, completionHandler: @escaping (MAAdapterInitializationStatus, String?) -> Void) {
        
        let serverParameters = parameters.serverParameters
        
        let partnerId = (serverParameters["partner_id"] as? String) ?? "test_partner"
        let appId = (serverParameters["app_id"] as? String) ?? "test_app"
        
        let params = UncheckedSendable(value: (partnerId, appId, completionHandler))
    
        DispatchQueue.main.async {
            ArtApps.shared.initialize(partnerId: params.value.0, appId: params.value.1)
            params.value.2(.initializedSuccess, nil)
        }
    }

    public override var sdkVersion: String {
        return "1.0.0"
    }

    public override var adapterVersion: String {
        return "1.0.0.0"
    }

    public override func destroy() {
        let capturedSelf = UncheckedSendable(value: self)
        DispatchQueue.main.async {
            capturedSelf.value.interstitialAd?.delegate = nil
            capturedSelf.value.interstitialAd = nil
            capturedSelf.value.adapterDelegate = nil
        }
    }

    // MARK: - MAInterstitialAdapter Methods

    public func loadInterstitialAd(for parameters: MAAdapterResponseParameters, andNotify delegate: MAInterstitialAdapterDelegate) {
        print("[ArtAppsMaxAdapter]: loadInterstitialAd 👁️")
        let placementId = parameters.thirdPartyAdPlacementIdentifier
        
        let captured = UncheckedSendable(value: (self, delegate, placementId))
        
        DispatchQueue.main.async {
            let strongSelf = captured.value.0
            let delegate = captured.value.1
            let placementId = captured.value.2
            
            strongSelf.interstitialAd = ArtAppsInterstitial(placementId: placementId)
            
            // Retain the delegate strongly
            let adDelegate = ArtAppsInterstitialAdapterDelegate(parentAdapter: strongSelf, delegate: delegate)
            strongSelf.adapterDelegate = adDelegate
            
            strongSelf.interstitialAd?.delegate = adDelegate
            strongSelf.interstitialAd?.load()
        }
    }

    public func showInterstitialAd(for parameters: MAAdapterResponseParameters, andNotify delegate: MAInterstitialAdapterDelegate) {
        print("[ArtAppsMaxAdapter]: showInterstitialAd 👁️")
        
        let captured = UncheckedSendable(value: (self, delegate))
        
        DispatchQueue.main.async {
            let strongSelf = captured.value.0
            let delegate = captured.value.1
            
            guard let ad = strongSelf.interstitialAd, ad.isReady else {
                delegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.adNotReady)
                return
            }
            
            // ALUtils.topViewControllerFromKeyWindow() is now non-optional in newer SDKs
            let presentingVC = ALUtils.topViewControllerFromKeyWindow()
            
            ad.show(from: presentingVC)
        }
    }
}

// MARK: - Delegate Wrapper

@MainActor
class ArtAppsInterstitialAdapterDelegate: ArtAppsInterstitialDelegate {
    
    private weak var parentAdapter: ArtAppsMaxAdapter?
    private let maxDelegate: MAInterstitialAdapterDelegate
    
    init(parentAdapter: ArtAppsMaxAdapter, delegate: MAInterstitialAdapterDelegate) {
        self.parentAdapter = parentAdapter
        self.maxDelegate = delegate
    }
    
    func artAppsInterstitialDidLoad(_ ad: ArtAppsInterstitial) {
        print("[ArtAppsMaxAdapter] Delegate received: artAppsInterstitialDidLoad 🤡")
        maxDelegate.didLoadInterstitialAd()
    }
    
    func artAppsInterstitial(_ ad: ArtAppsInterstitial, didFailToLoad error: Error) {
        print("[ArtAppsMaxAdapter] Delegate received: didFailToLoad (\(error.localizedDescription)) 🤡")
        // Map error to MAAdapterError if possible, or generic
        maxDelegate.didFailToLoadInterstitialAdWithError(mapError(error))
    }
    
    private func mapError(_ error: Error) -> MAAdapterError {
        if let sdkError = error as NSError?, sdkError.domain == "com.artApps.sdk" {
            switch sdkError.code {
            case 100:
                return MAAdapterError.notInitialized
            case 204, 205:
                return MAAdapterError.noFill
            default:
                break
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                    .notConnectedToInternet,
                    .networkConnectionLost,
                    .cannotFindHost,
                    .cannotConnectToHost,
                    .dnsLookupFailed:
                return MAAdapterError.unspecified
            default:
                break
            }
        }
        
        return MAAdapterError.unspecified
    }
    
    func artAppsInterstitialDidDisplay(_ ad: ArtAppsInterstitial) {
        print("[ArtAppsMaxAdapter] Delegate received: artAppsInterstitialDidDisplay 🤡")
        maxDelegate.didDisplayInterstitialAd()
    }
    
    func artAppsInterstitial(_ ad: ArtAppsInterstitial, didFailToDisplay error: Error) {
        print("[ArtAppsMaxAdapter] Delegate received: didFailToDisplay (\(error.localizedDescription)) 🤡")
        maxDelegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.adNotReady)
    }
    
    func artAppsInterstitialDidHide(_ ad: ArtAppsInterstitial) {
        print("[ArtAppsMaxAdapter] Delegate received: artAppsInterstitialDidHide 🤡")
        maxDelegate.didHideInterstitialAd()
    }
    
    func artAppsInterstitialDidClick(_ ad: ArtAppsInterstitial) {
        print("[ArtAppsMaxAdapter] Delegate received: artAppsInterstitialDidClick 🤡")
        maxDelegate.didClickInterstitialAd()
    }
}

struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
}
