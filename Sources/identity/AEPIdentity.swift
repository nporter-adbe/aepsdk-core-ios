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

class AEPIdentity: Extension {
    let runtime: ExtensionRuntime
    
    let name = IdentityConstants.EXTENSION_NAME
    let version = IdentityConstants.EXTENSION_VERSION
    var state: IdentityState?
    
    // MARK: Extension
    required init(runtime: ExtensionRuntime) {
        self.runtime = runtime
        
        guard let dataQueue = AEPServiceProvider.shared.dataQueueService.getDataQueue(label: name) else {
            // TODO: Log
            return
        }

        let hitQueue = PersistentHitQueue(dataQueue: dataQueue)
        state = IdentityState(identityProperties: IdentityProperties(), hitQueue: hitQueue, eventDispatcher: dispatch(event:))
    }
    
    func onRegistered() {
        registerListener(type: .identity, source: .requestIdentity, listener: handleIdentityRequest)
    }
    
    func onUnregistered() {}
    
    func readyForEvent(_ event: Event) -> Bool {
        if event.isSyncEvent || event.type == .genericIdentity {
            guard let configSharedState = getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event)?.value else { return false }
            return state?.readyForSyncIdentifiers(event: event, configurationSharedState: configSharedState) ?? false
        }
        
        return getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event)?.status == .set
    }
    
    // MARK: Event Listeners
    
    private func handleIdentityRequest(event: Event) {
        
        if event.isSyncEvent || event.type == .genericIdentity {
            if let eventData = state?.syncIdentifiers(event: event) {
                createSharedState(data: eventData, event: event)
            }
        }
        // TODO: Handle appendUrl, getUrlVariables, IdentifiersRequest
    }
}
