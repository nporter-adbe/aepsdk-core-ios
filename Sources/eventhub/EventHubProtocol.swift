//
//  EH.swift
//  AEPCore
//
//  Created by Nick Porter on 7/8/20.
//  Copyright © 2020 Adobe. All rights reserved.
//

import Foundation

public protocol EventHubProtocol {
    var containerType: ExtensionContainerProtocol.Type { get }
    func start()
    func dispatch(event: Event)
    func registerExtension(_ type: Extension.Type, completion: @escaping (_ error: EventHubError?) -> Void)
    func registerResponseListener(triggerEvent: Event, timeout: TimeInterval, listener: @escaping EventResponseListener)
    func createSharedState(extensionName: String, data: [String: Any]?, event: Event?)
    func createPendingSharedState(extensionName: String, event: Event?) -> SharedStateResolver
    func getSharedState(extensionName: String, event: Event?) -> (value: [String: Any]?, status: SharedStateStatus)?
    func getExtensionContainer(_ type: Extension.Type) -> ExtensionContainerProtocol?
}

public protocol ExtensionContainerProtocol {
    init(_ type: Extension.Type, _ queue: DispatchQueue)
    var eventOrderer: OperationOrderer<Event> { get }
    var sharedStateName: String? { get }
    var sharedState: SharedState? { get }
    func registerListener(type: EventType, source: EventSource, listener: @escaping EventListener)
}


