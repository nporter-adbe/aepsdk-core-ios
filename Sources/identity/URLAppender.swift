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

/// Provides functions to append visitor information to a URL
struct URLAppender {
    
    /// Appends identity payload to base url, present in the event data of the event param.
    /// - Parameters:
    ///   - baseUrl: url to which the identity payload needs to be appended onto
    ///   - configSharedState: config shared state corresponding to the event to be processed
    ///   - analyticsSharedState: analytics shared state corresponding to the event to be processed
    ///   - identityProperties: the current identity properties
    /// - Returns: `baseUrl` with the identity payload appended
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
    
    /// Generates the string for the identity visitor payload
    /// - Parameters:
    ///   - configSharedState: config shared state corresponding to the event to be processed
    ///   - analyticsSharedState: analytics shared state corresponding to the event to be processed
    ///   - identityProperties: the current identity properties
    /// - Returns a string formatted with the visitor id payload
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
    
    /// Appends the parameter to the original string
    /// - Parameters:
    ///   - original: the base url to have the parameter appended to
    ///   - key: key to be appended to the url, expected to be non-empty
    ///   - value: value to be appended to the url, expected to be non-empty
    /// - Returns: `original` with `key` and `value` properly appended
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
