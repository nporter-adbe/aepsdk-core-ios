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

struct LifecycleState {
    let dataStore: NamedKeyValueStore
    private(set) var lifecycleContextData: LifecycleContextData?
    private(set) var previousSessionLifecycleContextData: LifecycleContextData?
    private var lifecycleSession: LifecycleSession
    private var metricsBuilder: LifecycleMetricsBuilder?
    
    init(dataStore: NamedKeyValueStore, lifecycleSession: LifecycleSession) {
        self.dataStore = dataStore
        self.lifecycleSession = lifecycleSession
    }
    
    mutating func start(startDate: Date, data: [String: Any], configurationSharedState: [String: Any], identitySharedState: [String: Any]?) {
        let sessionContainer: LifecyclePersistedContext? = dataStore.getObject(key: LifecycleConstants.DataStoreKeys.PERSISTED_CONTEXT)
        
        // Build LifecycleMetrics
        metricsBuilder = LifecycleMetricsBuilder(dataStore: dataStore, date: startDate)
        metricsBuilder = metricsBuilder?.addDeviceData()
        metricsBuilder = metricsBuilder?.addLaunchData()
        let defaultMetrics = metricsBuilder?.build()
        checkForApplicationUpgrade(appId: defaultMetrics?.appId)
        
        let sessionTimeoutInSeconds = configurationSharedState[ConfigurationConstants.Keys.LIFECYCLE_CONFIG_SESSION_TIMEOUT] as? Int ?? Int(LifecycleConstants.MAX_SESSION_LENGTH_SECONDS)
        
        let previousSessionInfo = lifecycleSession.start(startDate: startDate, sessionTimeoutInSeconds: TimeInterval(sessionTimeoutInSeconds), coreMetrics: defaultMetrics ?? LifecycleMetrics())
        
        guard previousSessionInfo != nil else { return }
        
        var lifecycleData = LifecycleContextData()
        
        if isInstall() {
            metricsBuilder = LifecycleMetricsBuilder(dataStore: dataStore, date: startDate)
            metricsBuilder = metricsBuilder?.addInstallData()
            metricsBuilder = metricsBuilder?.addLaunchData()
            metricsBuilder = metricsBuilder?.addDeviceData()
            
            lifecycleData.lifecycleMetrics = metricsBuilder?.build()
        } else { // upgrade and launch hits
            // use metrics builder
        }
        
        if let additionalContextData = data[LifecycleConstants.Keys.ADDITIONAL_CONTEXT_DATA] as? [String: String] {
            lifecycleData.additionalContextData = additionalContextData
        }
        
//        if let advertisingIdentifier = identitySharedState?[LifecycleConstants.Keys.ADVERTISING_IDENTIFIER] as? String {
//            lifecycleData[LifecycleConstants.Keys.ADVERTISING_IDENTIFIER] = advertisingIdentifier
//        }
        
        // Update lifecycle context data and persist lifecycle info into local storage
        lifecycleContextData = lifecycleData
        persistLifecycleContextData(startDate: startDate)
    }
    
    mutating func pause(pauseDate: Date) {
        lifecycleSession.pause(pauseDate: pauseDate)
    }
    
    // MARK: Private APIs
    private mutating func checkForApplicationUpgrade(appId: String?) {
        // early out if this isn't an upgrade or if it is an install
        guard !isInstall() || isUpgrade() else { return }
        
        // get a map of lifecycle data in shared preferences or memory
        var lifecycleData = getContextData()
        
        // no data to update
        guard lifecycleData != nil else { return }
        
        // update the version in our map
        lifecycleData?.lifecycleMetrics?.appId = appId
        
        if lifecycleContextData == nil {
            // update the previous session's map
            previousSessionLifecycleContextData?.lifecycleMetrics?.appId = appId
            dataStore.setObject(key: LifecycleConstants.DataStoreKeys.LIFECYCLE_DATA, value: lifecycleData)
        } else {
            // if we have the map in memory update it
            lifecycleContextData = lifecycleData?.merging(with: lifecycleData, uniquingKeysWith: { (_, new) in new })
        }
    }
    
    private func isInstall() -> Bool {
        // TODO
        return false
    }
    
    private func isUpgrade() -> Bool {
        // TODO
        return false
    }
    
    private func persistLifecycleContextData(startDate: Date) {
        dataStore.setObject(key: "todo", value: lifecycleContextData)
        dataStore.setObject(key: "todo", value: startDate)
        // TODO: get app version and set in store
    }
    
    private func getPersistedContextData() -> LifecycleContextData? {
        return nil
    }
    
    private mutating func getContextData() -> LifecycleContextData? {
        if let contextData = lifecycleContextData ?? previousSessionLifecycleContextData {
            return contextData
        }
        
        previousSessionLifecycleContextData = getPersistedContextData()
        return previousSessionLifecycleContextData
    }
    
}
