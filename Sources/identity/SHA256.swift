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
import CommonCrypto

// Ref: https://stackoverflow.com/questions/25388747/sha256-in-swift
extension Data {
    /// Hashes this data with shag 256
    /// - Returns: This data hashed with sha256
    func sha256() -> Data? {
        guard let res = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH)) else { return nil }
        CC_SHA256((self as NSData).bytes, CC_LONG(count), res.mutableBytes.assumingMemoryBound(to: UInt8.self))
        return res as Data
    }
}

extension String {
    /// Hashes this data with shah 256
    /// - Returns: This string hashed with sha256
    func sha256() -> String? {
        guard
            let data = self.data(using: String.Encoding.utf8),
            let shaData = data.sha256()
            else { return nil }
        let rc = shaData.base64EncodedString(options: [])
        return rc
    }
}
