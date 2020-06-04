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

/// Manages the internal state for the `Configuration` extension
class ConfigurationState {
    let dataStore: NamedKeyValueStore
    let appIdManager: LaunchIDManager
    let configDownloader: ConfigurationDownloadable
    private var downloadedAppIds = Set<String>() // a set of appIds, if an appId is present then we have downloaded and applied the config
    
    private(set) var currentConfiguration = [String: Any]()
    private(set) var programmaticConfigInDataStore: [String: AnyCodable] {
        set {
            dataStore.setObject(key: ConfigurationConstants.Keys.PERSISTED_OVERRIDDEN_CONFIG, value: newValue)
        }

        get {
            let storedConfig: [String: AnyCodable]? = dataStore.getObject(key: ConfigurationConstants.Keys.PERSISTED_OVERRIDDEN_CONFIG)
            return storedConfig ?? [:]
        }
    }
    
    /// Creates a new `ConfigurationState` with an empty current configuration
    /// - Parameters:
    ///   - dataStore: The datastore in which configurations are cached
    ///   - configDownloader: A `ConfigurationDownloadable` which will be responsible for loading the configuration from various locations
    init(dataStore: NamedKeyValueStore, configDownloader: ConfigurationDownloadable) {
        self.dataStore = dataStore
        self.configDownloader = configDownloader
        self.appIdManager = LaunchIDManager(dataStore: dataStore)
    }
    
    /// Loads the first configuration at launch
    func loadInitialConfig() {
        var config = [String: Any]()
        
        // Load any existing application ID, either saved in persistence or read from the ADBMobileAppID property in the platform's System Info Service.
        if let appId = appIdManager.loadAppId() {
            config = configDownloader.loadConfigFromCache(appId: appId, dataStore: dataStore)
                        ?? configDownloader.loadDefaultConfigFromManifest()
                        ?? [:]
        } else {
            config = configDownloader.loadDefaultConfigFromManifest() ?? [:]
        }
        
        updateWith(newConfig: config)
    }
    
    /// Merges the current configuration to `newConfig` then applies programmatic configuration on top
    /// - Parameter newConfig: The new configuration
    func updateWith(newConfig: [String: Any]) {
        currentConfiguration.merge(newConfig) { (_, updated) in updated }

        // Apply any programmatic configuration updates
        currentConfiguration.merge(AnyCodable.toAnyDictionary(dictionary: programmaticConfigInDataStore) ?? [:]) { (_, updated) in updated }
    }
    
    /// Updates the programmatic config, then applies these changes to the current configuration
    /// - Parameter programmaticConfig: programmatic configuration to be applied
    func updateWith(programmaticConfig: [String: Any]) {
        // Any existing programmatic configuration updates are retrieved from persistence.
        // New configuration updates are applied over the existing persisted programmatic configurations
        // New programmatic configuration updates are saved to persistence.
        programmaticConfigInDataStore.merge(AnyCodable.from(dictionary: programmaticConfig) ?? [:]) { (_, updated) in updated }
        
        // The current configuration is updated with these new programmatic configuration changes.
        currentConfiguration.merge(AnyCodable.toAnyDictionary(dictionary: programmaticConfigInDataStore) ?? [:]) { (_, updated) in updated }
    }
    
    /// Attempts to download the configuration associated with `appId`, if downloading the remote config fails we check cache for cached config
    /// - Parameter appId: appId associated with the remote config
    /// - Parameter completion: A closure that is invoked with the downloaded config, nil if unable to download config with `appId`
    func updateWith(appId: String, completion: @escaping ([String: Any]?) -> ()) {
        // Save the AppID in persistence for loading configuration on future launches.
        appIdManager.saveAppIdToPersistence(appId: appId)

        // Try to download config from network, if fails try to load from cache
        configDownloader.loadConfigFromUrl(appId: appId, dataStore: dataStore, completion: { [weak self] (config) in
            if let loadedConfig = config {
                self?.downloadedAppIds.insert(appId)
                self?.replaceConfigurationWith(newConfig: loadedConfig)
            }
            
            completion(config)
        })
    }
    
    /// Attempts to load the configuration stored at `filePath`
    /// - Parameter filePath: Path to a configuration file
    /// - Returns: True if the configuration was loaded, false otherwise
    func updateWith(filePath: String) -> Bool {
         guard let bundledConfig = configDownloader.loadConfigFrom(filePath: filePath) else {
            return false
        }
        
        replaceConfigurationWith(newConfig: bundledConfig)
        return true
    }
    
    /// Determines if we have already downloaded the configuration associated with `appId`
    /// - Parameter appId: A valid appId
    func hasDownloadedConfig(appId: String) -> Bool {
        return downloadedAppIds.contains(appId)
    }
    
    /// Replaces `currentConfiguration` with `newConfig` and then applies the existing programmatic configuration on-top
    /// - Parameter newConfig: A configuration to replace the current configuration
    private func replaceConfigurationWith(newConfig: [String: Any]) {
        currentConfiguration = newConfig
        // Apply any programmatic configuration updates
        currentConfiguration.merge(AnyCodable.toAnyDictionary(dictionary: programmaticConfigInDataStore) ?? [:]) { (_, updated) in updated }
    }
}
