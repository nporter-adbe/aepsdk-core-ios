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
@testable import AEPCore

class TestableExtensionRuntime: ExtensionRuntime {
    var listeners:[String:EventListener] = [:]
    var dispatchedEvents: [Event] = []
    var createdSharedStates: [[String : Any]?] = []
    var otherSharedStates: [String: (value: [String : Any]?, status: SharedStateStatus)] = [:]
    
    func getListener(type: EventType, source: EventSource) -> EventListener?{
        return listeners["\(type)-\(source)"]
    }
    
    func simulateComingEvent(event:Event){
        listeners["\(event.type)-\(event.source)"]?(event)
        listeners["\(EventType.wildcard)-\(EventSource.wildcard)"]?(event)
    }
    
    func registerListener(type: EventType, source: EventSource, listener: @escaping EventListener) {
        listeners["\(type)-\(source)"] = listener
    }
    
    
    func dispatch(event: Event) {
        dispatchedEvents += [event]
    }
    
    func createSharedState(data: [String : Any], event: Event?) {
        self.createdSharedStates += [data]
    }
    
    func createPendingSharedState(event: Event?) -> SharedStateResolver {
        return { data in
            self.createdSharedStates += [data]
        }
    }
    
    func getSharedState(extensionName: String, event: Event?) -> SharedStateResult? {
        guard let result = otherSharedStates["\(extensionName)-\(String(describing: event?.id))"] else { return nil }
        return SharedStateResult(status: result.status, value: result.value)
    }
    
    func simulateSharedState(extensionName: String, event: Event?, data: (value: [String : Any]?, status: SharedStateStatus)) {
        otherSharedStates["\(extensionName)-\(String(describing: event?.id))"] = data
    }
    
    func startEvents() {
    }
    
    func stopEvents() {
    }
    
    
}
