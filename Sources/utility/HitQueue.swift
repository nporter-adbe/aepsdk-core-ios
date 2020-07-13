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

class HitQueue {
    // A closure which is invoked when a `DataEntity` and a `Bool`, the passed boolean value should indicate if the hit should be retried (false), or if processing was successful (true)
    typealias HitProcessor = (DataEntity, (Bool) -> ()) -> ()
    
    let dataQueue: DataQueue
    
    /// A closure to be invoked with the hit and a boolean value indicating failure or success
    let processor: HitProcessor
    private var suspended = true
    private var processingHit = false // modified by two threads, invesitgate
    
    init(dataQueue: DataQueue, processor: @escaping HitProcessor) {
        self.dataQueue = dataQueue
        self.processor = processor
    }
    
    @discardableResult
    func queue(entity: DataEntity, event: Event, configSharedState: [String: Any]) -> Bool {
        return dataQueue.add(dataEntity: entity)
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
        
        self.processor(hit, { result in
            processingHit = false
            if result {
                // successful processing of hit, remove it from the queue, if failed leave in queue to be retried
                let _ = dataQueue.remove()
            }
            processNextHit()
        })
        
    }
}
