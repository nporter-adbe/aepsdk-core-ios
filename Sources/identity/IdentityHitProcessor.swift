//
//  IdentityHitProcessor.swift
//  AEPCoreTests
//
//  Created by Nick Porter on 7/9/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import Foundation

struct IdentityHit: Codable {
    let url: URL
}

class IdentityHitProcessor {
    let dataQueue: DataQueue
    let operationOrderer = OperationOrderer<DataEntity>("IdentityHitProcessor")
    private var suspended = true
    private var networkService: NetworkService {
        return AEPServiceProvider.shared.networkService
    }
    
    init(dataQueue: DataQueue) {
        self.dataQueue = dataQueue
        operationOrderer.setHandler(processNext)
        operationOrderer.stop()
    }
    
    private func bringOnline() {
        suspended = false
        if let firstHit = dataQueue.peek() {
            operationOrderer.add(firstHit)
        }
    }
    
    func queue(url: URL, event: Event, configSharedState: [String: Any]) -> Bool {
        let hit = IdentityHit(url: url)
        guard let hitData = try? JSONEncoder().encode(hit) else { return false }
        let hitEntity = DataEntity(uniqueIdentifier: event.id.uuidString, timestamp: event.timestamp, data: hitData)
        
        return dataQueue.add(dataEntity: hitEntity)
    }
    
    private func processNext(_ hitId: DataEntity) -> Bool {
        guard suspended else { return false }
        
        guard let hitData = dataQueue.peek()?.data, let hit = try? JSONDecoder().decode(IdentityHit.self, from: hitData) else { return true }
        
        // TODO: process hit
        let networkRequest = NetworkRequest(url: hit.url)
        networkService.connectAsync(networkRequest: networkRequest) { (connection) in
            if connection.responseCode == 200 {
                
                
                
            }
        }
        
        // when done processing this hit add the next to the operation orderer
        let _ = dataQueue.remove()
        if let nextHit = dataQueue.peek() {
            operationOrderer.add(nextHit)
        }
        
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
