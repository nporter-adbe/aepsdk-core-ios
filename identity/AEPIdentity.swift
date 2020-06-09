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

class AEPIdentity: Extension {
    let name = "Identity"
    let version = "0.0.1"
    
    private let eventQueue = OperationOrderer<EventHandlerMapping>("Identity")
    
    // MARK: Extension
    required init() {
        eventQueue.setHandler({ return $0.handler($0.event) })
    }
    
    func onRegistered() {
        eventQueue.start()
        registerListener(type: .hub, source: .sharedState, listener: receiveSharedState(event:))
    }
    
    func onUnregistered() {}
    
    private func receiveSharedState(event: Event) {
        guard let stateOwner = event.data?[EventHubConstants.EventDataKeys.Configuration.EVENT_STATE_OWNER] as? String else { return }
        
        if ConfigurationConstants.EXTENSION_NAME == stateOwner {
            eventQueue.start()
        }
    }
}
