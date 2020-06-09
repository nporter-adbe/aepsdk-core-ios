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

extension NetworkRequest {
    static func optOutNetworkRequest(orgId: String, mid: String, experienceCloudServer: String) -> NetworkRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = experienceCloudServer
        components.path = IdentityConstants.KEY_PATH_OPTOUT
        components.queryItems = [
            URLQueryItem(name: IdentityConstants.RESPONSE_KEY_ORGID, value: orgId),
            URLQueryItem(name: IdentityConstants.RESPONSE_KEY_MID, value: mid)
        ]
        
        guard let url = components.url else { return nil }
        return NetworkRequest(url: url)
    }
}
