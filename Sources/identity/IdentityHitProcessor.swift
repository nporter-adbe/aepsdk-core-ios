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
import AEPServices

class IdentityHitProcessor: HitProcessable {
    let retryInterval = TimeInterval(30)
    private var networkService: NetworkService {
        return AEPServiceProvider.shared.networkService
    }

    // MARK: HitProcessable
    
    func processHit(entity: DataEntity, completion: @escaping (Bool, Data?) -> ()) {
        guard let data = entity.data, let identityHit = try? JSONDecoder().decode(IdentityHit.self, from: data) else {
            // failed to convert data to hit, unrecoverable error, move to next hit
            completion(true, nil)
            return
        }

        let networkRequest = NetworkRequest(url: identityHit.url)
        networkService.connectAsync(networkRequest: networkRequest) { (connection) in
            self.handleNetworkResponse(connection: connection, completion: completion)
        }

    }

    // MARK: Helpers
    
    private func handleNetworkResponse(connection: HttpConnection, completion: @escaping (Bool, Data?) -> ()) {
        if connection.responseCode == 200 {
            // hit sent successfully
            guard let data = connection.data else {
                // failed to parse identity response
                completion(true, nil)
                return
            }


            // todo: sent response back to update shared state
            completion(true, data)
        } else if NetworkServiceConstants.RECOVERABLE_ERROR_CODES.contains(connection.responseCode ?? -1) {
            // retry this hit later
            // TODO: Add log
            completion(false, nil)
        } else {
            // unrecoverable error. delete the hit from the database and continue
            // update shared state
            // TODO: Add log
            completion(true, nil)
        }
    }

}
