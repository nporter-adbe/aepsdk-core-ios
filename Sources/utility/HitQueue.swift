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

/// Defines a type which can process a hit
protocol Processable: class {
    
    /// Function that is invoked with a `DataEntity` and provides functionality for processing the hit
    /// - Parameters:
    ///   - entity: The `DataEntity` to be processed
    ///   - completion: a closure to be invoked with `true` if processing was successful and should not be retried, false if processing the hit should be retried
    func processHit(entity: DataEntity, completion: (Bool) -> ())
}

protocol HitQueuing {
    /// Queues a `DataEntity` to be processed
    /// - Parameters:
    ///   - entity: the entity to be processed
    @discardableResult
    func queue(entity: DataEntity) -> Bool
    
    /// Puts the queue in non-suspended state and begins processing hits
    func beginProcessing()
    
    /// Puts the queue in a suspended state and discontinues hit processing
    func suspend()
    
    /// Removes all the persisted hits from the queue
    func clear()
}

/// Provides functionality for asynchronous processing of hits in a synchronous manner while providing the ability to retry hits
class HitQueue: HitQueuing {
    let dataQueue: DataQueue
    weak var delegate: Processable?
    
    private var suspended = true
    private let queue = DispatchQueue(label: "com.adobe.mobile.hitqueue")
    
    /// Creates a new `HitQueue` with the underlying `DataQueue` which is used to persist hits
    /// - Parameter dataQueue: a `DataQueue` used to persist hits
    init(dataQueue: DataQueue) {
        self.dataQueue = dataQueue
    }
    
    @discardableResult
    func queue(entity: DataEntity) -> Bool {
        let result = dataQueue.add(dataEntity: entity)
        if !suspended {
            processNextHit()
        }
        
        return result
    }

    func beginProcessing() {
        suspended = false
        processNextHit()
    }

    func suspend() {
        suspended = true
    }

    func clear() {
        let _ = dataQueue.clear()
    }
    
    /// A recursive function for processing hits, it will continue processing all the hits
    private func processNextHit() {
        guard suspended else { return  }
        guard let hit = dataQueue.peek() else { return } // nothing let in the queue, stop processing
        
        // Use a dispatch queue so we can wait for the hit to finish processing asynchronous before moving to the next hit
        let group = DispatchGroup()
        group.enter()
        
        delegate?.processHit(entity: hit, completion: { [weak self] (success) in
            if success {
                // successful processing of hit, remove it from the queue, if failed leave in queue to be retried
                let _ = self?.dataQueue.remove()
            }
            
            group.leave()
        })
        
        group.notify(queue: queue) {
            self.processNextHit()
        }
    }
}
