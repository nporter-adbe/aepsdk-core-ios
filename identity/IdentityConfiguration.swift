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

struct IdentityConfiguration {
    let orgId: String
    let privacyStatus: PrivacyStatus
    let experienceCloudServer: String
    
    init(configurationSharedState: [String: Any]?) {
        orgId = configurationSharedState?[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String ?? ""
        let privacyString = configurationSharedState?[ConfigurationConstants.Keys.GLOBAL_CONFIG_PRIVACY] as? String
        privacyStatus = PrivacyStatus(rawValue: privacyString ?? PrivacyStatus.unknown.rawValue) ?? .unknown
        experienceCloudServer = configurationSharedState?[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_SERVER] as? String ?? IdentityConstants.DEFAULT_SERVER
    }
    
    func canSyncIdentifiersWithCurrentConfiguration() -> Bool {
        return !orgId.isEmpty && privacyStatus != PrivacyStatus.optedOut
    }
}
