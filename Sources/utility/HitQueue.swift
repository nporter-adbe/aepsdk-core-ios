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

protocol HitProcessor: class {
    func processHit(entity: DataEntity, completion: (Bool) -> ())
}

class HitQueue {
    let dataQueue: DataQueue
    weak var delegate: HitProcessor?
    
    private var suspended = true
    private var processingHit = false // modified by two threads, invesitgate
    
    init(dataQueue: DataQueue) {
        self.dataQueue = dataQueue
    }
    
    @discardableResult
    func queue(entity: DataEntity, event: Event, configSharedState: [String: Any]) -> Bool {
        let result = dataQueue.add(dataEntity: entity)
        if !suspended {
            processNextHit()
        }
        
        return result
    }
    
    func bringOnline() {
        suspended = false
        processNextHit()
    }
    
    func suspend() {
        suspended = true
    }
    
    func clear() {
        let _ = dataQueue.clear()
    }
    
    private func processNextHit() {
        guard suspended else { return  }
        guard !processingHit else { return } // ensure we are not currently processing a hit
        guard let hit = dataQueue.peek() else { return } // nothing let in the queue, stop processing
        processingHit = true
        
        delegate?.processHit(entity: hit, completion: { (success) in
            processingHit = false
            if success {
                // successful processing of hit, remove it from the queue, if failed leave in queue to be retried
                let _ = dataQueue.remove()
            }
            
            processNextHit()
        })
    }
}
