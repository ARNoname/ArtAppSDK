

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
        print("[ServerParameters]: \(params)")
        
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
        
        // In newer SDKs, thirdPartyAdPlacementIdentifier might be non-optional.
        // We use 'let' directly. If it happens to be optional in some versions,
        // coalescing it to empty string is safe.
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


