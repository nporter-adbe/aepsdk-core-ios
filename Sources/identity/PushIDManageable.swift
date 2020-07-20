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
import AEPServices
import CommonCrypto

protocol PushIDManageable {
    
    /// Returns true if push is enabled, false otherwise
    var pushEnabled: Bool { get }
    
    init(dataStore: NamedKeyValueStore, eventDispatcher: @escaping (Event) -> ())
    
    func updatePushId(pushId: String?)
    
    func setPushEnabled(enabled: Bool)
    
}

struct PushIDManager: PushIDManageable {
    var pushEnabled: Bool {
        return dataStore.getBool(key: IdentityConstants.DataStoreKeys.PUSH_ENABLED) ?? false
    }
    
    private var dataStore: NamedKeyValueStore
    private var eventDispatcher: (Event) -> ()
    
    init(dataStore: NamedKeyValueStore, eventDispatcher: @escaping (Event) -> ()) {
        self.dataStore = dataStore
        self.eventDispatcher = eventDispatcher
    }
    
    func updatePushId(pushId: String?) {
        if !processPushToken(token: pushId) {
            // Provided push token matches existing push token. Push settings will not be re-sent to Analytics
        }
        
        if pushId?.isEmpty ?? true && pushEnabled {
            updatePushStatusAndSendAnalyticsEvent(enabled: false)
        }
        
        if let pushId = pushId, !pushId.isEmpty, !pushEnabled {
            updatePushStatusAndSendAnalyticsEvent(enabled: true)
        }
        
    }
    
    func setPushEnabled(enabled: Bool) {
        dataStore.set(key: IdentityConstants.DataStoreKeys.PUSH_ENABLED, value: enabled)
    }
    
    private func processPushToken(token: String?) -> Bool {
        var properties = IdentityProperties()
        properties.loadFromPersistence()
        
        let existingPushToken = properties.pushIdentifier
        var newHashedToken: Data? = nil
        
        if let token = token {
            newHashedToken = token.data(using: .utf8)?.sha256()
        }
        
        if (existingPushToken == nil && newHashedToken == nil) ||
                (existingPushToken != nil && existingPushToken == newHashedToken) {
            return false
        }
        
        properties.pushIdentifier = newHashedToken
        properties.saveToPersistence()
        return true
    }
    
    private func updatePushStatusAndSendAnalyticsEvent(enabled: Bool) {
        setPushEnabled(enabled: enabled)
        
        let contextData = [IdentityConstants.EventDataKeys.EVENT_PUSH_STATUS: enabled ? "True": "False"]
        
        let eventData = [IdentityConstants.EventDataKeys.Analytics.TRACK_ACTION: IdentityConstants.EventDataKeys.PUSH_ID_ENABLED_ACTION_NAME,
                         IdentityConstants.EventDataKeys.Analytics.CONTEXT_DATA: contextData] as [String : Any]
        
        let event = Event(name: "AnalyticsForIdentityRequest", type: .analytics, source: .requestContent, data: eventData)
        eventDispatcher(event)
    }
    
}
