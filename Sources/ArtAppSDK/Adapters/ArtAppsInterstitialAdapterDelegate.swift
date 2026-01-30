import Foundation
import UIKit
import AppLovinSDK

@MainActor
class ArtAppsInterstitialAdapterDelegate: ArtAppsInterstitialDelegate {
    private weak var parentAdapter: ArtAppsMaxAdapter?
    private let maxDelegate: MAInterstitialAdapterDelegate
    
    init(parentAdapter: ArtAppsMaxAdapter, delegate: MAInterstitialAdapterDelegate) {
        self.parentAdapter = parentAdapter
        self.maxDelegate = delegate
    }
    
    func artAppsInterstitialDidLoad(_ ad: ArtAppsInterstitial) {
        maxDelegate.didLoadInterstitialAd()
    }
    
    func artAppsInterstitial(_ ad: ArtAppsInterstitial, didFailToLoad error: Error) {
        // Map error to MAAdapterError if possible, or generic
        maxDelegate.didFailToLoadInterstitialAdWithError(mapError(error))
    }
    
    private func mapError(_ error: Error) -> MAAdapterError {
        if let sdkError = error as NSError?, sdkError.domain == "com.artApps.sdk" {
            switch sdkError.code {
            case 100:
                return MAAdapterError.notInitialized
            case 204:
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
        
        if error is ArtAppsNetworkError {
            return MAAdapterError.unspecified
        }
        
        return MAAdapterError.unspecified
    }
    
    func artAppsInterstitialDidDisplay(_ ad: ArtAppsInterstitial) {
        maxDelegate.didDisplayInterstitialAd()
        print("[ArtApps] didDisplay_InterstitialAd")
    }
    
    func artAppsInterstitialDidHide(_ ad: ArtAppsInterstitial) {
        maxDelegate.didHideInterstitialAd()
        print("[ArtApps] didHide_InterstitialAd")
    }
    
    func artAppsInterstitialDidClick(_ ad: ArtAppsInterstitial) {
        maxDelegate.didClickInterstitialAd()
        print("[ArtApps] didClick_InterstitialAd")
    }
}

struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
}

