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

class AEPLifecycle: Extension {
    typealias EventHandlerMapping = (event: Event, handler: (Event) -> (Bool)) // TODO: Move to event hub to make public?
    
    let name = LifecycleConstants.EXTENSION_NAME
    let version = LifecycleConstants.EXTENSION_VERSION
    
    private let eventQueue = OperationOrderer<EventHandlerMapping>(LifecycleConstants.EXTENSION_VERSION)
    private var lifecycleState: LifecycleState
    
    // MARK: Extension
    
    /// Invoked when the `EventHub` creates it's instance of the Lifecycle extension
    required init() {
        lifecycleState = LifecycleState(dataStore: NamedKeyValueStore(name: name))
        eventQueue.setHandler({ return $0.handler($0.event) })
    }
    
    /// Invoked when the `EventHub` has successfully registered the Lifecycle extension.
    func onRegistered() {
        registerListener(type: .genericLifecycle, source: .requestContent, listener: receiveLifecycleRequest(event:))
        registerListener(type: .hub, source: .sharedState, listener: receiveSharedState(event:))
        
        let sharedStateData = [LifecycleConstants.Keys.LIFECYCLE_CONTEXT_DATA: lifecycleState.computeBootData().toDictionary()]
        createSharedState(data: sharedStateData as [String : Any], event: nil)
        eventQueue.start()
    }
    
    func onUnregistered() {}
    
    // MARK: Event Listeners
    
    /// Invoked when an event of type generic lifecycle and source request content is dispatched by the `EventHub`
    /// - Parameter event: the generic lifecycle event
    private func receiveLifecycleRequest(event: Event) {
        eventQueue.add((event, handleLifecycleRequest(event:)))
    }
    
    /// Invoked when the `EventHub` dispatches a shared state event. If the shared state owner is Configuration we trigger the internal `eventQueue`.
    /// - Parameter event: The shared state event
    private func receiveSharedState(event: Event) {
        guard let stateOwner = event.data?[EventHubConstants.EventDataKeys.Configuration.EVENT_STATE_OWNER] as? String else { return }

        if stateOwner == ConfigurationConstants.EXTENSION_NAME {
            eventQueue.start()
        }
    }
    
    // MARK: Event Handlers
    
    /// Handles the Lifecycle request event by either invoking the start or pause business logic
    /// - Parameter event: a Lifecycle request event
    /// - Returns: True if the Lifecycle event was processed, false if the configuration shared state is not yet ready
    private func handleLifecycleRequest(event: Event) -> Bool {
        guard let configurationSharedState = getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event) else {
            return false
        }
        
        if configurationSharedState.status == .pending { return false }
        
        if event.isLifecycleStartEvent {
            let (prevStartDate, prevPauseDate) = lifecycleState.start(date: event.timestamp, additionalContextData: event.additionalData, adId: getAdvertisingIdentifier(event: event))
            updateSharedState(event: event)
            if let unwrappedPrevStartDate = prevStartDate, let unwrappedPrevPauseDate = prevPauseDate {
                dispatchSessionStart(date: event.timestamp, contextData: lifecycleState.getContextData(), previousStartDate: unwrappedPrevStartDate, previousPauseDate: unwrappedPrevPauseDate)
            }
        } else if event.isLifecyclePauseEvent {
            lifecycleState.pause(pauseDate: event.timestamp)
        }
        
        return true
    }
    
    // MARK: Helpers
    
    /// Attempts to read the advertising identifier from Identity shared state
    /// - Parameter event: event to version the shared state
    /// - Returns: the advertising identifier, nil if not found or if Identity shared state is not available
    private func getAdvertisingIdentifier(event: Event) -> String? {
        // TODO: Replace with Identity name via constant when Identity extension is merged
        guard let identitySharedState = getSharedState(extensionName: "com.adobe.module.identity", event: event) else {
            return nil
        }
        
        if identitySharedState.status == .pending { return nil }
        
        // TODO: Replace with data key via constant when Identity extension is merged
        return identitySharedState.value?["advertisingidentifier"] as? String
    }
    
    private func updateSharedState(event: Event) {
        let sharedStateData = [LifecycleConstants.Keys.LIFECYCLE_CONTEXT_DATA: lifecycleState.getContextData()?.toDictionary()]
        createSharedState(data: sharedStateData as [String : Any], event: event)
    }
    
    private func dispatchSessionStart(date: Date, contextData: LifecycleContextData?, previousStartDate: Date, previousPauseDate: Date) {
        let eventData: [String: Any] = [
            LifecycleConstants.Keys.LIFECYCLE_CONTEXT_DATA: contextData?.toDictionary() ?? [:],
            LifecycleConstants.Keys.SESSION_EVENT: LifecycleConstants.START,
            LifecycleConstants.Keys.SESSION_START_TIMESTAMP: date.timeIntervalSince1970,
            LifecycleConstants.Keys.MAX_SESSION_LENGTH: LifecycleConstants.MAX_SESSION_LENGTH_SECONDS,
            LifecycleConstants.Keys.PREVIOUS_SESSION_START_TIMESTAMP: previousStartDate.timeIntervalSince1970,
            LifecycleConstants.Keys.PREVIOUS_SESSION_PAUSE_TIMESTAMP: previousPauseDate.timeIntervalSince1970
        ]
        
        dispatch(event: Event(name: "LifecycleStart", type: .lifecycle, source: .responseContent, data: eventData))
    }
}
