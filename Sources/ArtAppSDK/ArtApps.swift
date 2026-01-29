

import Foundation

@MainActor
public class ArtApps {
    public static let shared = ArtApps()
    
    public private(set) var partnerId: String?
    public private(set) var appId: String?
    public private(set) var isInitialized = false
    
    private let startTime = Date()
    private var lastAdShowTime: Date?
    private var serverRestrictionsUpdatedAt: Date?
    
    // Configurable thresholds (could be remote config in future)
    public var sessionGateSeconds: TimeInterval = 30 
    public var frequencyCapSeconds: TimeInterval = 90
    
    public private(set) var serverCooldownSeconds: TimeInterval?
    public private(set) var serverSessionGateSeconds: TimeInterval?
    public private(set) var serverTtlSeconds: TimeInterval?
    
    private init() {}
    
    /// Initializes the ArtApps SDK.
    /// - Parameters:
    ///   - partnerId: Your Partner ID provided by ArtApps.
    ///   - appId: Your Application ID provided by ArtApps.
    ///   - baseURL: Optional delivery server base URL.
    public func initialize(partnerId: String, appId: String, baseURL: String? = nil) {
         
         self.partnerId = partnerId
         self.appId = appId
         
         if let baseURL = baseURL {
             ArtAppsNetworkManager.shared.baseURL = baseURL
         }
         self.isInitialized = true
         print("[ArtApps] Initialized at \(startTime). PartnerID: \(partnerId)")
     }

     public var baseURL: String {
         get { ArtAppsNetworkManager.shared.baseURL }
         set { ArtAppsNetworkManager.shared.baseURL = newValue }
     }
    
    public func canShowAd() -> Bool {
        let now = Date()
        
        // 1. Session Gate
        let effectiveSessionGate = currentServerSessionGate(at: now) ?? sessionGateSeconds
        if now.timeIntervalSince(startTime) < effectiveSessionGate {
            let source = currentServerSessionGate(at: now) == nil ? "Local" : "Server"
            print("[ArtApps] Blocked by \(source) Session Gate (need \(effectiveSessionGate)s, passed \(Int(now.timeIntervalSince(startTime)))s)")
            return false
        }
        
        // 2. Cooldown (server overrides local frequency cap)
         let effectiveCooldownSeconds = currentServerCooldownSeconds(at: now) ?? frequencyCapSeconds
         if let lastShow = lastAdShowTime, now.timeIntervalSince(lastShow) < effectiveCooldownSeconds {
             let source = currentServerCooldownSeconds(at: now) == nil ? "Freq Cap" : "Server Cooldown"
             print("[ArtApps] Blocked by \(source) (need \(effectiveCooldownSeconds)s, passed \(Int(now.timeIntervalSince(lastShow)))s)")
             return false
         }
         
         return true
     }
    
    public func updateServerRestrictions(cooldownSeconds: Int?, sessionGateSeconds: Int?, ttlSeconds: Int?) {
          serverRestrictionsUpdatedAt = Date()
          serverCooldownSeconds = cooldownSeconds.map { TimeInterval($0) }
          serverSessionGateSeconds = sessionGateSeconds.map { TimeInterval($0) }
          serverTtlSeconds = ttlSeconds.map { TimeInterval($0) }
      }
    
    public func didShowAd() {
        lastAdShowTime = Date()
    }
    
    private func currentServerCooldownSeconds(at now: Date) -> TimeInterval? {
        if checkTtl(at: now) { return nil }
        return serverCooldownSeconds
    }
    
    private func currentServerSessionGate(at now: Date) -> TimeInterval? {
        if checkTtl(at: now) { return nil }
        return serverSessionGateSeconds
    }
    
    /// Returns true if TTL has expired and resets server restrictions.
    private func checkTtl(at now: Date) -> Bool {
        guard let updatedAt = serverRestrictionsUpdatedAt,
              let ttlSeconds = serverTtlSeconds,
              ttlSeconds > 0 else {
            return false
        }
        
        if now.timeIntervalSince(updatedAt) > ttlSeconds {
            print("[ArtApps] Server restrictions expired (TTL: \(ttlSeconds)s)")
            serverCooldownSeconds = nil
            serverSessionGateSeconds = nil
            serverTtlSeconds = nil
            serverRestrictionsUpdatedAt = nil
            return true
        }
        return false
    }
}
