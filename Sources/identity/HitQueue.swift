//
//  HitQueue.swift
//  AEPCoreTests
//
//  Created by Nick Porter on 7/9/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import Foundation

struct IdentityHit: Codable {
    let url: URL
}

class HitQueue {
    typealias HitProcessor = (DataEntity, (Bool) -> ()) -> ()
    
    let dataQueue: DataQueue
    let processor: HitProcessor
    var operationOrderer = OperationOrderer<DataEntity>("HitQueue")
    private var suspended = true
    private var networkService: NetworkService {
        return AEPServiceProvider.shared.networkService
    }
    
    init(dataQueue: DataQueue, processor: @escaping HitProcessor) {
        self.dataQueue = dataQueue
        self.processor = processor
        operationOrderer.setHandler(processNext)
        operationOrderer.stop()
    }
    
    func bringOnline() {
        suspended = false
        if let firstHit = dataQueue.peek() {
            operationOrderer.add(firstHit)
        }
    }
    
    func suspend() {
        suspended = true
        operationOrderer.stop()
    }
    
    func clear() {
        let _ = dataQueue.clear()
        operationOrderer = OperationOrderer<DataEntity>("HitQueue")
    }
    
    func queue(entity: DataEntity, event: Event, configSharedState: [String: Any]) -> Bool {
        return dataQueue.add(dataEntity: entity)
    }
    
    private func processNext(_ hitId: DataEntity) -> Bool {
        guard suspended else { return false }
        
        guard let dataEntity = dataQueue.peek() else { return true }
        
        // TODO: process hit
        
        self.processor(dataEntity, { result in
            
        })
        
//        let networkRequest = NetworkRequest(url: hit.url)
//        networkService.connectAsync(networkRequest: networkRequest) { (connection) in
//            if connection.responseCode == 200 {
//                // handle network response
////                return true
//            } else if NetworkServiceConstants.RECOVERABLE_RESPONSE_CODES.contains(connection.responseCode ?? -1) {
//                // retry
//
////                return false
//            } else {
//                // unrecoverable error
//            }
//        }
//
//        // when done processing this hit add the next to the operation orderer
//        let _ = dataQueue.remove()
//        if let nextHit = dataQueue.peek() {
//            operationOrderer.add(nextHit)
//        }
        
        return true
    }
    
    func updatePrivacyStatus(privacyStatus: PrivacyStatus) {
        switch privacyStatus {
        case .optedIn:
            bringOnline()
        case .optedOut:
            suspended = true
            operationOrderer.stop()
            let _ = dataQueue.remove()
        case .unknown:
            suspended = true
            operationOrderer.stop()
        }
    }
}
