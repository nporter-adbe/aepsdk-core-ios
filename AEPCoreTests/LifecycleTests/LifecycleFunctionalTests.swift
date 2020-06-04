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

import XCTest
@testable import AEPCore

/// Functional tests for the Configuration extension
class LifecycleFunctionalTests: XCTestCase {
    var dataStore = NamedKeyValueStore(name: LifecycleConstants.DATA_STORE_NAME)
    var mockSystemInfoService: MockSystemInfoService!
    
    override func setUp() {
        AEPServiceProvider.shared.networkService = MockConfigurationDownloaderNetworkService(shouldReturnValidResponse: true)
        setupMockSystemInfoService()
        dataStore.removeAll()
        MockExtension.reset()
        EventHub.reset()
        registerExtension(MockExtension.self)
        registerExtension(AEPConfiguration.self)
        
        EventHub.shared.start()
        // Wait for first shared state from lifecycle to signal bootup has completed
        registerLifecycleAndWaitForSharedState()
    }
    
    // helpers
    private func registerExtension<T: Extension> (_ type: T.Type) {
        let expectation = XCTestExpectation(description: "Extension should register")
        EventHub.shared.registerExtension(type) { (error) in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
    }
    
    private func setupMockSystemInfoService() {
        mockSystemInfoService = MockSystemInfoService()
        mockSystemInfoService.runMode = "Application"
        mockSystemInfoService.mobileCarrierName = "Test Carrier"
        mockSystemInfoService.applicationName = "Test app name"
        mockSystemInfoService.applicationBuildNumber = "12345"
        mockSystemInfoService.applicationVersionNumber = "1.1.1"
        mockSystemInfoService.deviceName = "Test device name"
        mockSystemInfoService.operatingSystemName = "Test OS"
        mockSystemInfoService.activeLocaleName = "en-US"
        mockSystemInfoService.displayInformation = (100, 100)
       
        
        AEPServiceProvider.shared.systemInfoService = mockSystemInfoService
    }
    
    private func registerLifecycleAndWaitForSharedState() {
        let expectation = XCTestExpectation(description: "Lifecycle should share first shared state")
        
        EventHub.shared.registerListener(parentExtension: MockExtension.self, type: .hub, source: .sharedState) { _ in expectation.fulfill() }
        registerExtension(AEPLifecycle.self)
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: lifecycleStart(...) tests
    
    /// Tests the happy path with for updating the config with a dict
    func testUpdateConfigurationWithDict() {
        // setup
//        let configResponseExpectation = XCTestExpectation(description: "Update config dispatches a configuration response content event")
        let sharedStateExpectation = XCTestExpectation(description: "Update config dispatches configuration shared state")
        
//        EventHub.shared.registerListener(parentExtension: MockExtension.self, type: .configuration, source: .responseContent) { (event) in
//            XCTAssertEqual(event.type, EventType.configuration)
//            XCTAssertEqual(event.source, EventSource.responseContent)
//            XCTAssertNotNil(event.data?[ConfigurationConstants.Keys.UPDATE_CONFIG] as? [String: Any])
//            XCTAssertEqual(configUpdate[ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY]!, PrivacyStatus.optedOut.rawValue)
//            configResponseExpectation.fulfill()
//        }
        
        EventHub.shared.registerListener(parentExtension: MockExtension.self, type: .hub, source: .sharedState) { (event) in
            XCTAssertEqual(event.type, EventType.hub)
            XCTAssertEqual(event.source, EventSource.sharedState)
            XCTAssertEqual(LifecycleConstants.EXTENSION_NAME, event.data?[EventHubConstants.EventDataKeys.Configuration.EVENT_STATE_OWNER] as! String)
            sharedStateExpectation.fulfill()
        }
        
        // test
        AEPCore.lifecycleStart(additionalContextData: nil)
        
        // verify
        wait(for: [sharedStateExpectation], timeout: 2)
    }

}
