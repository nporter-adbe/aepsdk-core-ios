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

class LifecycleExtension: Extension {
    typealias EventHandlerMapping = (event: Event, handler: (Event) -> (Bool)) // TODO: Move to event hub to make public?
    
    let name = LifecycleConstants.EXTENSION_NAME
    let version = LifecycleConstants.EXTENSION_VERSION
    
    private let eventQueue = OperationOrderer<EventHandlerMapping>(LifecycleConstants.EXTENSION_VERSION)
    private var lifecycleState: LifecycleState
    
    // MARK: Extension
    required init() {
        lifecycleState = LifecycleState(dataStore: NamedKeyValueStore(name: name))
        eventQueue.setHandler({ return $0.handler($0.event) })
    }
    
    func onRegistered() {
        registerListener(type: .genericLifecycle, source: .requestContent, listener: receiveLifecycleRequest(event:))
        registerListener(type: .hub, source: .sharedState, listener: receiveSharedState(event:))
        createSharedState(data: lifecycleState.computeBootData().toDictionary() ?? [:], event: nil)
        eventQueue.start()
    }
    
    func onUnregistered() {}
    
    // MARK: Event Listeners
    private func receiveLifecycleRequest(event: Event) {
        eventQueue.add((event, handleLifecycleRequest(event:)))
    }
    
    private func receiveSharedState(event: Event) {
        guard let stateOwner = event.data?[EventHubConstants.EventDataKeys.Configuration.EVENT_STATE_OWNER] as? String else { return }

        if stateOwner == ConfigurationConstants.EXTENSION_NAME {
            eventQueue.start()
        }
    }
    
    // MARK: Event Handlers
    private func handleLifecycleRequest(event: Event) -> Bool {
        guard let configurationSharedState = getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event) else {
            return false
        }
        
        if configurationSharedState.status == .pending { return true }
        
        if event.isLifecycleStartEvent {
            lifecycleState.start(date: event.timestamp, additionalContextData: event.additionalData, adId: getAdvertisingIdentifier(event: event))
        } else if event.isLifecyclePauseEvent {
            lifecycleState.pause(pauseDate: event.timestamp)
        }
        
        return true
    }
    
    // MARK: Helpers
    private func getAdvertisingIdentifier(event: Event) -> String? {
        // TODO: Replace with Identity name via constant when Identity extension is merged
        guard let identitySharedState = getSharedState(extensionName: "com.adobe.module.identity", event: event) else {
            return nil
        }
        
        if identitySharedState.status == .pending { return nil }
        
        // TODO: Replace with data key via constant when Identity extension is merged
        return identitySharedState.value?["advertisingidentifier"] as? String
    }
}
