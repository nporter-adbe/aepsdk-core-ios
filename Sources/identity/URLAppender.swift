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

private extension String {
    func indexOf(char: Character) -> Int? {
        return firstIndex(of: char)?.utf16Offset(in: self)
    }
}

struct URLAppender {
    
    static func appendVisitorInfo(baseUrl: String, configSharedState: [String: Any], analyticsSharedState: [String: Any], identityProperties: IdentityProperties) -> String {
        if baseUrl.isEmpty {
            return baseUrl
        }
        
        var modifiedUrl = baseUrl
        if var idString = generateVisitorIdPayload(configSharedState: configSharedState, analyticsSharedState: analyticsSharedState, identityProperties: identityProperties) {
            // add separator based on if url contains query parameters
            let queryIndex = modifiedUrl.indexOf(char: "?")
            var insertIndex = modifiedUrl.count
            
            // account for anchors in url
            let anchorIndex = modifiedUrl.indexOf(char: "#")
            if let anchorIndex = anchorIndex {
                insertIndex = anchorIndex > 0 ? anchorIndex : modifiedUrl.count
            }
            
            // check for case where URL has no query but the fragment (anchor) contains a '?' character
            let hasQueryAndAnchor = anchorIndex != nil && queryIndex != nil
            let isQueryAfterAnchor = hasQueryAndAnchor && (anchorIndex ?? -1) > 0 && (anchorIndex ?? -1) < (queryIndex ?? -1)
            
            // insert query delimiter, account for fragment which contains '?' character
            if let queryIndex = queryIndex, !isQueryAfterAnchor {
                if queryIndex != modifiedUrl.count - 1 {
                    idString.insert("&", at: idString.startIndex)
                }
            } else {
                idString.insert("?", at: idString.startIndex)
            }
            
            modifiedUrl.insert(contentsOf: idString, at: modifiedUrl.index(modifiedUrl.startIndex, offsetBy: insertIndex))
        }
        
        return modifiedUrl
    }
    
    static func generateVisitorIdPayload(configSharedState: [String: Any], analyticsSharedState: [String: Any], identityProperties: IdentityProperties) -> String? {
        // append timestamp
        var theIdString = appendParameterToVisitorIdString(original: "", key: IdentityConstants.VISITOR_TIMESTAMP_KEY, value: String(Date().timeIntervalSince1970))
        // append mid
        if let mid = identityProperties.mid {
            theIdString = appendParameterToVisitorIdString(original: theIdString, key: IdentityConstants.VISITOR_PAYLOAD_MARKETING_CLOUD_ID_KEY, value: mid.midString)
        }
        
        // TODO: Append aid and vid from Analytics
        
        // append org id
        if let orgId = configSharedState[ConfigurationConstants.Keys.EXPERIENCE_CLOUD_ORGID] as? String {
            theIdString = appendParameterToVisitorIdString(original: theIdString, key: IdentityConstants.VISITOR_PAYLOAD_MARKETING_CLOUD_ORG_ID, value: orgId)
        }
        
        // encode adobe_mc string and append to the url
        let urlFragment = "\(IdentityConstants.VISITOR_PAYLOAD_KEY)=\(URLEncoder.encode(value: theIdString))"
        
        // TODO: If vid not empty encode and add to url
        
        return urlFragment
    }
    
    static func appendParameterToVisitorIdString(original: String, key: String, value: String) -> String {
        if key.isEmpty || value.isEmpty {
            return original
        }
        
        let newUrlVar = "\(key)=\(value)"
        if original.isEmpty {
            return newUrlVar
        }
        
        return "\(original)|\(newUrlVar)"
    }
    
}
