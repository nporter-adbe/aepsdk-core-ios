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
@testable import AEPIdentity
import AEPServices
import AEPServicesMock

class PushIDManagerTests: XCTestCase {

    var pushIdManager: PushIDManager!
    
    override func setUp() {
        AEPServiceProvider.shared.namedKeyValueService = MockDataStore()
    }
    
    /// Tests that when we do not have a push id saved that we update to a new ID and dispatch analytics events
    func testUpdatePushIdNilExistingIdUpdatesToValid() {
        // setup
        pushIdManager = PushIDManager(dataStore: NamedKeyValueStore(name: "PushIDManagerTests"), eventDispatcher: { (event) in
            
        })
        // test
        pushIdManager.
        
        // verify
    }
}
