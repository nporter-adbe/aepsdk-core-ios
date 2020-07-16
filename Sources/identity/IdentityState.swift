/*
Copyright 2020 Adobe. All rights reserved.
This file is licensed to you under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License. You may obtain a copy
of the License at http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under
the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
OF ANY KIND, either express or implied. See the License for the specific language
governing permissions and limitations under the License.
*/

import Foundation

/// Manages the business logic of the Identity extension
class IdentityState {
    private var identityProperties: IdentityProperties
    private var hitQueue: PersistentHitQueue
    private var eventDispatcher: (Event) -> ()
    #if DEBUG
    var lastValidConfig: [String: Any] = [:]
    #else
    private var lastValidConfig: [String: Any] = [:]
    #endif
    
    /// Creates a new `IdentityState` with the given identity properties
    /// - Parameter identityProperties: identity
    init(identityProperties: IdentityProperties, hitQueue: PersistentHitQueue, eventDispatcher: @escaping (Event) -> ()) {
        self.identityProperties = identityProperties
        self.identityProperties.loadFromPersistence()
        self.hitQueue = hitQueue
        self.eventDispatcher = eventDispatcher
        self.hitQueue.delegate = self
    }
    
    /// Determines if we have all the required pieces of information, such as configuration to process a sync identifiers call
    /// - Parameters:
    ///   - event: event corresponding to sync identifiers call or containing a new ADID value.
    ///   - configurationSharedState: config shared state corresponding to the event to be processed
    func readyForSyncIdentifiers(event: Event, configurationSharedState: [String: Any]) -> Bool {
        // org id is a requirement.
        // Use what's in current config shared state. if that's missing, check latest config.
        // if latest config doesn't have org id either, Identity can't proceed.
        if let orgId = configurationSharedState[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String, !orgId.isEmpty {
            lastValidConfig = configurationSharedState
        } else if lastValidConfig.isEmpty {
            // can't process this event, wait for a valid config and retry later
            return false
        }
        
        return true
    }
    
    /// Will queue a sync identifiers hit if there are any new valid identifiers to be synced (non null/empty id_type and id values),
    /// Updates the persistence values for the identifiers and ad id
    /// Assumes a valid config is in `lastValidConfig` from calling `readyForSyncIdentifiers`
    /// - Parameters:
    ///   - event: event corresponding to sync identifiers call or containing a new ADID value.
    /// - Returns: The data to be used for Identity shared state
    func syncIdentifiers(event: Event) -> [String: Any]? {
        // sanity check, config should never be empty
        if lastValidConfig.isEmpty {
            // TODO: Add log
            return nil
        }
        
        // Early exit if privacy is opt-out
        if lastValidConfig[ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY] as? PrivacyStatus ?? .unknown == .optedOut {
            // TODO: Add log
            return nil
        }
        
        // TODO: Save push ID AMSDK-10262
        
        // generate customer ids
        let authState = event.authenticationState
        var customerIds = event.identifiers?.map({CustomIdentity(origin: IdentityConstants.VISITOR_ID_PARAMETER_KEY_CUSTOMER, type: $0.key, identifier: $0.value, authenticationState: authState)}) ?? []
        
        // update adid if changed and extract the new adid value as VisitorId to be synced
        if let adId = event.adId, shouldUpdateAdId(newAdID: adId.identifier ?? "") {
            // check if changed, update
            identityProperties.advertisingIdentifier = adId.identifier
            customerIds.append(adId)
        }
        
        // merge new identifiers with the existing ones and remove any VisitorIds with empty id values
        // empty adid is also removed from the customer_ids_ list by merging with the new ids then filtering out any empty ids
        identityProperties.mergeAndCleanCustomerIds(customerIds)
        customerIds.removeAll(where: {$0.identifier?.isEmpty ?? true}) // clean all identifiers by removing all that have a nil or empty identifier
        
        // valid config: check if there's a need to sync. Don't if we're already up to date.
        if shouldSync(customerIds: customerIds, dpids: event.dpids, forceSync: event.forceSync, currentEventValidConfig: lastValidConfig) {
            queueHit(identityProperties: identityProperties, configSharedState: lastValidConfig, event: event)
        } else {
            // TODO: Log error
        }
        
        // save properties
        identityProperties.saveToPersistence()
        
        // return event data to be used in identity shared state
        return identityProperties.toEventData()
    }
    
    private func queueHit(identityProperties: IdentityProperties, configSharedState: [String: Any], event: Event) {
        guard let server = configSharedState[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_SERVER] as? String else {
            // TODO: Add log
            return
        }
        
        guard let orgId = configSharedState[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String else {
            // TODO: Add log
            return
        }
        
        guard let url = URL.buildIdentityHitURL(experienceCloudServer: server, orgId: orgId, identityProperties: identityProperties, dpids: event.dpids ?? [:]) else {
            // TODO: Add log
            return
        }
        
        guard let hitData = try? JSONEncoder().encode(IdentityHit(url: url, event: event)) else {
            // TODO: Add log
            return
        }
        
        hitQueue.queue(entity: DataEntity(uniqueIdentifier: UUID().uuidString, timestamp: Date(), data: hitData))
    }
    
    /// Verifies if a sync network call is required. This method returns true if there is at least one identifier to be synced,
    /// at least one dpid, if force sync is true (bootup identity sync call) or if the
    /// last sync was more than `ttl_` seconds ago. Also, in order for a sync call to happen, the provided configuration should be
    /// valid: org id is valid and privacy status is opted in.
    /// - Parameters:
    ///   - customerIds: current customer ids that need to be synced
    ///   - dpids: current dpids that need to be synced
    ///   - forceSync: indicates if this is a force sync call
    ///   - currentEventValidConfig: the current configuration for the event
    /// - Returns: True if a sync should be made, false otherwise
    private func shouldSync(customerIds: [CustomIdentity]?, dpids: [String: String]?, forceSync: Bool, currentEventValidConfig: [String: Any]) -> Bool {
        var syncForProps = true
        var syncForIds = true
        
        // check config
        if !canSyncForCurrentConfiguration(config: currentEventValidConfig) {
            // TOOD: Add log
            syncForProps = false
        }
        
        let needResync = Date().timeIntervalSince1970 - (identityProperties.lastSync?.timeIntervalSince1970 ?? 0) > identityProperties.ttl || forceSync
        let hasIds = !(customerIds?.isEmpty ?? true)
        let hasDpids = !(dpids?.isEmpty ?? true)
        
        if identityProperties.mid != nil && !hasIds && !hasDpids && !needResync {
            syncForIds = false
        } else if identityProperties.mid == nil {
            identityProperties.mid = MID()
        }
        
        return syncForIds && syncForProps
    }
    
    /// Inspects the current configuration to determine if a sync can be made, this is determined by if a valid org id is present and if the privacy is not set to opted-out
    /// - Parameter config: The current configuration
    /// - Returns: True if a sync can be made with the current configuration, false otherwise
    private func canSyncForCurrentConfiguration(config: [String: Any]) -> Bool {
        let orgId = config[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String ?? ""
        let privacyStatus = config[ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY] as? PrivacyStatus ?? .unknown
        return !orgId.isEmpty && privacyStatus != .optedOut
    }
    
    /// Determines if we should update the ad id with `newAdID`
    /// - Parameter newAdID: the new ad id
    /// - Returns: True if we should update the ad id, false otherwise
    private func shouldUpdateAdId(newAdID: String) -> Bool {
        let existingAdId = identityProperties.advertisingIdentifier ?? ""
        return (!newAdID.isEmpty && newAdID != existingAdId) || (newAdID.isEmpty && !existingAdId.isEmpty)
    }
}

extension IdentityState: HitQueueDelegate {

    // MARK: HitQueueDelegate
    func didProcess(hit: DataEntity) {
        guard let data = hit.data, let hit = try? JSONDecoder().decode(IdentityHit.self, from: data) else {
            // TODO: Log
            return
        }
        
        // regardless of response, update last sync time
        identityProperties.lastSync = Date()
        
        // check privacy here in case the status changed while response was in-flight
        if identityProperties.privacyStatus != .optedOut {
            // TODO: update properties
            
            // save
            identityProperties.saveToPersistence()
        }
        
        // dispatch events
        let eventData = identityProperties.toEventData()
        let updatedIdentityEvent = Event(name: "Updated Identity Response", type: .identity, source: .responseIdentity, data: eventData)
        let identityResponse = hit.event.createResponseEvent(name: "Updated Identity Response", type: .identity, source: .responseIdentity, data: eventData)
        eventDispatcher(updatedIdentityEvent)
        eventDispatcher(identityResponse)
        
    }
}

