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
        
        let hitQueue = PersistentHitQueue(dataQueue: dataQueue, processor: IdentityHitProcessor(responseHandler: handleNetworkResponse(entity:responseData:)))
        state = IdentityState(identityProperties: IdentityProperties(), hitQueue: hitQueue)
    }
    
    func onRegistered() {
        registerListener(type: .identity, source: .requestIdentity, listener: handleIdentityRequest)
        registerListener(type: .configuration, source: .responseContent, listener: handleIdentityRequest)
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
        } else if let baseUrl = event.baseUrl {
            processAppendToUrl(baseUrl: baseUrl, event: event)
        } else if event.urlVariables {
            processGetUrlVariables(event: event)
        } else {
            processIdentifiersRequest(event: event)
        }
    }
    
    private func handleConfigurationResponse(event: Event) {
        if let privacyStatus = event.data?[ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY] as? PrivacyStatus {
            if privacyStatus == .optedOut {
                // send opt-out hit
                handleOptOut(event: event)
            }
            // if config contains new global privacy status, process the request
            state?.processPrivacyChange(event: event, eventDispatcher: dispatch(event:), createSharedState: createSharedState(data:event:))
        }
        
        // if config contains org id, update the latest configuration
        if let orgId = event.data?[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String, !orgId.isEmpty {
            // update to new config
            state?.updateLastValidConfig(newConfig: event.data ?? [:])
        }
    }
    
    // MARK: Event Handlers
    private func processAppendToUrl(baseUrl: String, event: Event) {
        guard let configurationSharedState = getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event)?.value else { return }
        guard let properties = state?.identityProperties else { return }
        let analyticsSharedState = getSharedState(extensionName: "com.adobe.module.analytics", event: event)?.value ?? [:]
        let updatedUrl = URLAppender.appendVisitorInfo(baseUrl: baseUrl, configSharedState: configurationSharedState, analyticsSharedState: analyticsSharedState, identityProperties: properties)

        // dispatch identity response event with updated url
        let responseEvent = event.createResponseEvent(name: "Identity Appended URL", type: .identity, source: .responseIdentity, data: [IdentityConstants.EventDataKeys.UPDATED_URL: updatedUrl])
        dispatch(event: responseEvent)
    }

    private func processGetUrlVariables(event: Event) {
        guard let configurationSharedState = getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event)?.value else { return }
        guard let properties = state?.identityProperties else { return }
        let analyticsSharedState = getSharedState(extensionName: "com.adobe.module.analytics", event: event)?.value ?? [:]
        let urlVariables = URLAppender.generateVisitorIdPayload(configSharedState: configurationSharedState, analyticsSharedState: analyticsSharedState, identityProperties: properties)

        // dispatch identity response event with url variables
        let responseEvent = event.createResponseEvent(name: "Identity URL Variables", type: .identity, source: .responseIdentity, data: [IdentityConstants.EventDataKeys.URL_VARIABLES: urlVariables])
        dispatch(event: responseEvent)
    }

    private func processIdentifiersRequest(event: Event) {
        guard let properties = state?.identityProperties else { return }
        let eventData = properties.toEventData()
        let responseEvent = event.createResponseEvent(name: "Identity Response Content", type: .identity, source: .responseIdentity, data: eventData)

        // dispatch identity response event with shared state data
        dispatch(event: responseEvent)
    }
    
    // MARK: Network Response Handler
    
    /// Invoked by the `IdentityHitProcessor` each time we receive a network response
    /// - Parameters:
    ///   - entity: The `DataEntity` that was processed by the hit processor
    ///   - responseData: the network response data if any
    private func handleNetworkResponse(entity: DataEntity, responseData: Data?) {
        state?.handleHitResponse(hit: entity, response: responseData, eventDispatcher: dispatch(event:))
    }
    
    // MARK: Private Helpers
    
    /// Sends an opt-out network request if the current privacy status is opt-out
    /// - Parameter event: the event responsible for sending this opt-out hit
    private func handleOptOut(event: Event) {
        // TODO: AMSDK-10267 Check if AAM will handle the opt-out hit
        guard let configSharedState = getSharedState(extensionName: ConfigurationConstants.EXTENSION_NAME, event: event)?.value else { return }
        let privacyStatus = configSharedState[ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY] as? PrivacyStatus ?? PrivacyStatus.unknown
        
        if privacyStatus == .optedOut {
            guard let orgId = configSharedState[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String else { return }
            guard let mid = state?.identityProperties.mid else { return }
            guard let server = configSharedState[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_SERVER] as? String else { return }
            AEPServiceProvider.shared.networkService.sendOptOutRequest(orgId: orgId, mid: mid, experienceCloudServer: server)
        }
    }
}
