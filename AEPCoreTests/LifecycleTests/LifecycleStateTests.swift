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

class LifecycleStateTests: XCTestCase {
    
    var lifecycleState: LifecycleState!
    var dataStore = NamedKeyValueStore(name: "LifecycleStateTests")
    
    var currentDate: Date!
    var currentDateMinusOneSecond: Date!
    var currentDateMinusTenMin: Date!
    var currentDateMinusOneHour: Date!
    var currentDateMinusOneDay: Date!
    
    override func setUp() {
        setupDates()
        dataStore.removeAll()
        lifecycleState = LifecycleState(dataStore: dataStore)
        AEPServiceProvider.shared.systemInfoService = MockSystemInfoService()
    }
    
    private func setupDates() {
        currentDate = Date()
        
        currentDateMinusOneSecond = Calendar.current.date(byAdding: .second, value: -1, to: currentDate)
        currentDateMinusTenMin = Calendar.current.date(byAdding: .minute, value: -10, to: currentDate)
        currentDateMinusOneHour = Calendar.current.date(byAdding: .hour, value: -1, to: currentDate)
        currentDateMinusOneDay = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)
    }
    
    /// Happy path testing start
    func testStartSimple() {
        // setup
        var persistedContext = LifecyclePersistedContext()
        persistedContext.pauseDate = currentDateMinusOneSecond
        persistedContext.startDate = currentDateMinusTenMin
        dataStore.setObject(key: LifecycleConstants.DataStoreKeys.PERSISTED_CONTEXT, value: persistedContext)
        let mockAppVersion = "1.1.1"
        dataStore.set(key: LifecycleConstants.DataStoreKeys.LAST_VERSION, value: mockAppVersion)
        
        // test
        lifecycleState.start(startDate: currentDate, data: [:], configurationSharedState: [:], identitySharedState: [:])
        
        // verify
        let actualContext: LifecyclePersistedContext = dataStore.getObject(key: LifecycleConstants.DataStoreKeys.PERSISTED_CONTEXT)!
        XCTAssertEqual(currentDateMinusTenMin.timeIntervalSince1970 + 1, actualContext.startDate?.timeIntervalSince1970)
        XCTAssertFalse(actualContext.successfulClose!)
        XCTAssertNil(actualContext.pauseDate)
        XCTAssertEqual(mockAppVersion, dataStore.getString(key: LifecycleConstants.DataStoreKeys.LAST_VERSION))
    }


}
