//
//  MockEventHub.swift
//  AEPCore
//
//  Created by Nick Porter on 7/9/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import Foundation

class MockEventHub: EventHubProtocol {
    var containerType: ExtensionContainerProtocol.Type = MockExtensionContainer.self
    
    func start() {
        // todo
        let mockContainer = containerType.init(AEPConfiguration.self, DispatchQueue(label: "mock"))
    }
    
    func dispatch(event: Event) {
        // todo
    }
    
    func registerExtension(_ type: Extension.Type, completion: @escaping (EventHubError?) -> Void) {
        // todo
    }
    
    func registerResponseListener(triggerEvent: Event, timeout: TimeInterval, listener: @escaping EventResponseListener) {
        // todo
    }
    
    func createSharedState(extensionName: String, data: [String : Any]?, event: Event?) {
        // todo
    }
    
    func createPendingSharedState(extensionName: String, event: Event?) -> SharedStateResolver {
        // todo
    }
    
    func getSharedState(extensionName: String, event: Event?) -> (value: [String : Any]?, status: SharedStateStatus)? {
        return nil
    }
    
    func getExtensionContainer(_ type: Extension.Type) -> ExtensionContainerProtocol? {
        return nil
    }
    
    
}


class MockExtensionContainer: ExtensionContainerProtocol {
    required init(_ type: Extension.Type, _ queue: DispatchQueue) {
        // todo
    }
    
    var eventOrderer: OperationOrderer<Event>
    
    var sharedStateName: String?
    
    var sharedState: SharedState?
    
    func registerListener(type: EventType, source: EventSource, listener: @escaping EventListener) {
        // todo
    }
    
    
}
