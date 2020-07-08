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

class URLAppenderTests: XCTestCase {
    // MARK: appendVisitorInfo(...) tests
    
    // MARK: generateVisitorIdPayload(...) tests
    
    func testGenerateVisitorIdPayloadHappy() {
        // setup
        let expected = "MCMID%3D83056071767212492011535942034357093219%7CMCAID%3Dtest_aid%7CMCORGID%3D29849020983%40adobeOrg"
        let configSharedState = [ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID: "test-org-id", ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn] as [String : Any]
        var props = IdentityProperties()
        props.mid = MID()
        
        // test
        let result = URLAppender.generateVisitorIdPayload(configSharedState: configSharedState, analyticsSharedState: [:], identityProperties: props)
        
        // verify
        
        // verify that the url starts with Visitor Payload key
        XCTAssertTrue(result?.hasPrefix(IdentityConstants.VISITOR_PAYLOAD_KEY) ?? false)
        
        // verify timestamp parameter
        
        
    }
    
    // MARK: appendParameterToVisitorIdString(...) tests
    
    func testAppendParameterToVisitorIdStringShouldHandleEmpty() {
        // test
        let result = URLAppender.appendParameterToVisitorIdString(original: "", key: "key1", value: "val1")
        
        // verify
        XCTAssertEqual("key1=val1", result)
    }
    
    func testAppendParameterToVisitorIdStringReturnsOriginalIfKeyIsEmpty() {
        // test
        let result = URLAppender.appendParameterToVisitorIdString(original: "testOriginal", key: "", value: "val1")
        
        // verify
        XCTAssertEqual("testOriginal", result)
    }
    
    func testAppendParameterToVisitorIdStringReturnsOriginalIfValueIsEmpty() {
        // test
        let result = URLAppender.appendParameterToVisitorIdString(original: "testOriginal", key: "key1", value: "")
        
        // verify
        XCTAssertEqual("testOriginal", result)
    }
    
    func testAppendParameterToVisitorIdStringHappy() {
        // test
        let result = URLAppender.appendParameterToVisitorIdString(original: "hello=world", key: "key1", value: "val1")
        
        // verify
        XCTAssertEqual("hello=world|key1=val1", result)
    }
}
