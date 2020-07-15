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

class AEPCoreLifecycleTests: XCTestCase {
    override func setUp() {
        EventHub.reset()
        MockExtension.reset()
        registerMockExtension(MockExtension.self)
    }

    private func registerMockExtension<T: Extension> (_ type: T.Type) {
        let semaphore = DispatchSemaphore(value: 0)
        EventHub.shared.registerExtension(type) { (error) in
            semaphore.signal()
        }

        semaphore.wait()
    }

    func testLifecycleStart() {
        // setup
        let expectation = XCTestExpectation(description: "Lifecycle Start dispatches generic lifecycle request content")
        expectation.assertForOverFulfill = true
        let expectedContextData = ["testKey": "testVal"]

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: .genericLifecycle, source: .requestContent) { (event) in
            XCTAssertEqual(LifecycleConstants.START, event.data?[LifecycleConstants.EventDataKeys.ACTION_KEY] as! String)
            XCTAssertEqual(expectedContextData, event.data?[LifecycleConstants.EventDataKeys.ADDITIONAL_CONTEXT_DATA] as! [String: String])
            expectation.fulfill()
        }

        EventHub.shared.start()

        // test
        AEPCore.lifecycleStart(additionalContextData: expectedContextData)

        // verify
        wait(for: [expectation], timeout: 0.5)
    }

    func testLifecyclePause() {
        // setup
        let expectation = XCTestExpectation(description: "Lifecycle Pause dispatches generic lifecycle request content")
        expectation.assertForOverFulfill = true

        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: .genericLifecycle, source: .requestContent) { (event) in
            XCTAssertEqual(LifecycleConstants.PAUSE, event.data?[LifecycleConstants.EventDataKeys.ACTION_KEY] as! String)
            expectation.fulfill()
        }

        EventHub.shared.start()

        // test
        AEPCore.lifecyclePause()

        // verify
        wait(for: [expectation], timeout: 0.5)
    }
}
