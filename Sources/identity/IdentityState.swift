//
//  IdentityState.swift
//  AEPCore
//
//  Created by Nick Porter on 7/6/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import Foundation

struct IdentityState {
    
    private var identityProperties: IdentityProperties
    private var lastValidConfig: [String: Any]
    private var db = AEPServiceProvider.shared.dataQueueService.getDataQueue(label: IdentityConstants.EXTENSION_NAME)
    
    mutating func syncIdentifiers(event: Event, configurationSharedState: [String: Any]) -> [String: Any] {
        // do not even extract any data if the config is opt-out.
        
        // If privacy status is opt-out return
        
        // If orgId is not empty set this to the current valid config, else fallback to prev valid config
        
        // Check privacy status again from the valid config object, return if opt-out
        

        // Save push ID if changed
        
        
        let authState = event.authenticationState
        let forceSync = event.forceSync
        
        // generate customer ids
        var customerIds = event.identifiers?.map({CustomIdentity(origin: IdentityConstants.VISITOR_ID_PARAMETER_KEY_CUSTOMER, type: $0.key, identifier: $0.value, authenticationState: authState)})
        
        // read and update adid
        if let adId = event.adId {
            // check if changed, update
        }
        
        
        // merge new identifiers with the existing ones and remove any VisitorIds with empty id values
        // empty adid is also removed from the customer_ids_ list by merging with the new ids then filtering out any empty ids
        identityProperties.customerIds = toIdDict(ids: identityProperties.customerIds).merging(toIdDict(ids: customerIds), uniquingKeysWith: { (_, new) in new }).map {$0.value}
        identityProperties.customerIds?.removeAll(where: {$0.identifier?.isEmpty ?? true}) // clean all identifiers by removing all that have a nil or empty identifier
        customerIds?.removeAll(where: {$0.identifier?.isEmpty ?? true}) // clean all identifiers by removing all that have a nil or empty identifier
        
        
        // valid config: check if there's a need to sync. Don't if we're already up to date.
        
        if shouldSync() {
            let hitUrl = URL.buildIdentityHitURL(experienceCloudServer: "", orgId: "", identityProperties: identityProperties, dpids: event.dpids ?? [:])
            // queue in DB
        } else {
            // TODO: Log error
        }
        
        // save properties
        // extension should share state after with identity properties to event data
        return identityProperties.toEventData()
    }
    
    private func shouldSync() -> Bool {
        return false
    }
    
    /// Returns a dict where the key is the `identifier` of the identity and the value is the `CustomIdentity`
    /// - Parameter ids: a list of identities
    func toIdDict(ids: [CustomIdentity]?) -> [String?: CustomIdentity] {
        guard let ids = ids else { return [:] }
        return Dictionary(uniqueKeysWithValues: ids.map{ ($0.identifier, $0) })
    }
}
