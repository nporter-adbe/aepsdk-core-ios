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

extension AEPCore: Lifecycle {
    public static func lifecycleStart(additionalContextData: [String: String]?) {
        let data: [String: Any] = [LifecycleConstants.Keys.ACTION_KEY: LifecycleConstants.START,
                                   LifecycleConstants.Keys.ADDITIONAL_CONTEXT_DATA: additionalContextData ?? [:]]
        let event = Event(name: "Lifecycle Start", type: .genericLifecycle, source: .requestContent, data: data)
        AEPCore.dispatch(event: event)
    }
    
    public static func lifecyclePause() {
        let data = [LifecycleConstants.Keys.ACTION_KEY: LifecycleConstants.PAUSE]
        let event = Event(name: "Lifecycle Pause", type: .genericLifecycle, source: .requestContent, data: data)
        AEPCore.dispatch(event: event)
    }
}
