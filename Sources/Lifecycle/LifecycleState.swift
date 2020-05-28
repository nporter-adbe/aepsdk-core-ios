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
    
    #if DEBUG
    var lifecycleContextData: LifecycleContextData?
    var previousSessionLifecycleContextData: LifecycleContextData?
    #else
    private(set) var lifecycleContextData: LifecycleContextData?
    private(set) var previousSessionLifecycleContextData: LifecycleContextData?
    #endif
    
    private var lifecycleSession: LifecycleSession
    private var metricsBuilder: LifecycleMetricsBuilder?
    
    init(dataStore: NamedKeyValueStore) {
        self.dataStore = dataStore
        self.lifecycleSession = LifecycleSession(dataStore: dataStore)
    }
    
    mutating func start(startDate: Date, data: [String: Any], configurationSharedState: [String: Any], identitySharedState: [String: Any]?) {
        let sessionContainer: LifecyclePersistedContext? = dataStore.getObject(key: LifecycleConstants.DataStoreKeys.PERSISTED_CONTEXT)
        
        // Build default LifecycleMetrics
        metricsBuilder = LifecycleMetricsBuilder(dataStore: dataStore, date: startDate)
        metricsBuilder = metricsBuilder?.addDeviceData()
        let defaultMetrics = metricsBuilder?.build()
        checkForApplicationUpgrade(appId: defaultMetrics?.appId)
        
        let sessionTimeout = TimeInterval(configurationSharedState[ConfigurationConstants.Keys.LIFECYCLE_CONFIG_SESSION_TIMEOUT] as? Int ?? Int(LifecycleConstants.DEFAULT_LIFECYCLE_TIMEOUT))
        
        guard let previousSessionInfo = lifecycleSession.start(startDate: startDate, sessionTimeoutInSeconds: sessionTimeout, coreMetrics: defaultMetrics ?? LifecycleMetrics()) else { return }
        
        var lifecycleData = LifecycleContextData()
        
        if isInstall() {
            metricsBuilder = metricsBuilder?.addInstallData()
            metricsBuilder = metricsBuilder?.addLaunchEventData()
        } else {
            // upgrade and launch hits
            metricsBuilder = metricsBuilder?.addLaunchEventData()
            metricsBuilder = metricsBuilder?.addLaunchData()
            let upgrade = isUpgrade()
            metricsBuilder = metricsBuilder?.addUpgradeData(upgrade: upgrade)
            metricsBuilder = metricsBuilder?.addCrashData(previousSessionCrash: previousSessionInfo.isCrash,
                                                          osVersion: sessionContainer?.osVersion ?? "unavailable",
                                                          appId: sessionContainer?.appId ?? "unavailable")
            
            let sessionContextData = lifecycleSession.getSessionData(startDate: startDate, sessionTimeoutInSeconds: sessionTimeout, previousSessionInfo: previousSessionInfo)
            lifecycleData.sessionContextData = sessionContextData
        }
        
        lifecycleData.lifecycleMetrics = metricsBuilder?.build()
        
        if let additionalContextData = data[LifecycleConstants.Keys.ADDITIONAL_CONTEXT_DATA] as? [String: String] {
            lifecycleData.additionalContextData = additionalContextData
        }
        
        if let advertisingIdentifier = identitySharedState?[LifecycleConstants.Keys.ADVERTISING_IDENTIFIER] as? String {
            lifecycleData.advertisingIdentifier = advertisingIdentifier
        }
        
        // Update lifecycle context data and persist lifecycle info into local storage
        lifecycleContextData = lifecycleContextData?.merging(with: lifecycleData, uniquingKeysWith: { (_, new) in new } ) ?? lifecycleData
        persistLifecycleContextData(startDate: startDate)
    }
    
    mutating func pause(pauseDate: Date) {
        lifecycleSession.pause(pauseDate: pauseDate)
    }
    
    mutating func getContextData() -> LifecycleContextData? {
        if let contextData = lifecycleContextData ?? previousSessionLifecycleContextData {
            return contextData
        }
        
        previousSessionLifecycleContextData = getPersistedContextData()
        return previousSessionLifecycleContextData
    }
    
    mutating func checkForApplicationUpgrade(appId: String?) {
        // early out if this isn't an upgrade or if it is an install
        if isInstall() || !isUpgrade() { return }
        
        // get a map of lifecycle data in shared preferences or memory
        guard var lifecycleData = getContextData() else { return }
        
        // update the version in our map
        lifecycleData.lifecycleMetrics?.appId = appId
        
        if lifecycleContextData == nil {
            // update the previous session's map
            previousSessionLifecycleContextData?.lifecycleMetrics?.appId = appId
            dataStore.setObject(key: LifecycleConstants.DataStoreKeys.LIFECYCLE_DATA, value: lifecycleData)
        } else {
            // if we have the map in memory update it
            lifecycleContextData = lifecycleData.merging(with: lifecycleData, uniquingKeysWith: { (_, new) in new } )
        }
    }
    
    // MARK: Private APIs
    
    /// Returns true if there is not install date stored in the data store
    private func isInstall() -> Bool {
        return !dataStore.contains(key: LifecycleConstants.Keys.INSTALL_DATE)
    }
    
    /// Returns true if the current app version does not equal the app version stored in the data store
    private func isUpgrade() -> Bool {
        let appVersion = AEPServiceProvider.shared.systemInfoService.getApplicationVersionNumber()
        return dataStore.getString(key: LifecycleConstants.DataStoreKeys.LAST_VERSION) != appVersion
    }
    
    private func persistLifecycleContextData(startDate: Date) {
        dataStore.setObject(key: LifecycleConstants.DataStoreKeys.LIFECYCLE_DATA, value: lifecycleContextData)
        dataStore.setObject(key: LifecycleConstants.Keys.LAST_LAUNCH_DATE, value: startDate)
        let appVersion = AEPServiceProvider.shared.systemInfoService.getApplicationVersionNumber()
        dataStore.set(key: LifecycleConstants.DataStoreKeys.LAST_VERSION, value: appVersion)
    }
    
    private func getPersistedContextData() -> LifecycleContextData? {
        let contextData: LifecycleContextData? = dataStore.getObject(key: LifecycleConstants.DataStoreKeys.LIFECYCLE_DATA)
        return contextData
    }
    
}
