//
//  IdentityConfiguration.swift
//  AEPCore
//
//  Created by Nick Porter on 6/9/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

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
