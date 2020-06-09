//
//  Event+Identity.swift
//  AEPCore
//
//  Created by Nick Porter on 6/9/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import Foundation

extension Event {
    var optedOutHitSent: Bool? {
        return data?[IdentityConstants.EventDataKeys.Audience.OPTED_OUT_HIT_SENT] as? Bool
    }
}
