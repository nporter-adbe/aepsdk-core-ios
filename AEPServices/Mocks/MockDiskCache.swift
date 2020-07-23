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

class MockDiskCache: CacheService {
    
    var mockCache: [String: CacheEntry] = [:]
    
    enum MockDiskCacheError: Error {
        case setFailure
    }
    
    var shouldThrow: Bool = false
    var setCalled = false
    func set(cacheName: String, key: String, entry: CacheEntry) throws {
        setCalled = true
        if shouldThrow {
            throw MockDiskCacheError.setFailure
        }
        mockCache[key] = entry
    }
    
    var getCalled = false
    func get(cacheName: String, key: String) -> CacheEntry? {
        getCalled = true
        return mockCache[key]
    }
    
    func remove(cacheName: String, key: String) throws {
        
    }
}
