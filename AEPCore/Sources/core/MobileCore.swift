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

/// Core extension for the Adobe Experience Platform SDK
@objc(AEPCore) public final class MobileCore: NSObject {
    
    /// Current version of the Core extension
    public static var extensionVersion: String {
        return ConfigurationConstants.EXTENSION_VERSION + wrapperType.rawValue
    }
    private static var wrapperType = WrapperType.none
    
    /// Pending extensions to be registered for legacy support
    static var pendingExtensions = ThreadSafeArray<Extension.Type>(identifier: "com.adobe.pendingextensions.queue")
    
    /// Registers the extensions with Core and begins event processing
    /// - Parameter extensions: The extensions to be registered
    /// - Parameter completion: Closure to run when extensions have been registered
    public static func registerExtensions(_ extensions: [Extension.Type], _ completion: (() -> Void)? = nil) {
        let registeredCounter = AtomicCounter()
        let allExtensions = [Configuration.self] + extensions
        
        allExtensions.forEach {
            EventHub.shared.registerExtension($0) { (_) in
                if registeredCounter.incrementAndGet() == allExtensions.count {
                    EventHub.shared.start()
                    completion?()
                }
            }
        }
    }
    
    /// Dispatches an `Event` through the `EventHub`
    /// - Parameter event: The `Event` to be dispatched
    @objc(dispatch:)
    public static func dispatch(event: Event) {
        EventHub.shared.dispatch(event: event)
    }
    
    /// Dispatches an `Event` through the `EventHub` and invokes a closure with the response `Event`.
    /// - Parameters:
    ///   - event: The trigger `Event` to be dispatched through the `EventHub`
    ///   - responseCallback: Callback to be invoked with `event`'s response `Event`
    @objc(dispatch:responseCallback:)
    public static func dispatch(event: Event, responseCallback: @escaping (Event?) -> ()) {
        EventHub.shared.registerResponseListener(triggerEvent: event, timeout: 1) { (event) in
            responseCallback(event)
        }
        
        EventHub.shared.dispatch(event: event)
    }
    
    /// Start event processing
    //@available(*, deprecated, message: "Use `registerExtensions(extensions:)` for both registering extensions and starting the SDK")
    public static func start(_ completion: @escaping (()-> Void)) {
        // Start the event hub processing
        let pending = MobileCore.pendingExtensions.shallowCopy
        MobileCore.pendingExtensions.clear()
        registerExtensions(pending, { completion() })
    }
    
    /// Submits a generic event containing the provided IDFA with event type `generic.identity`.
    /// - Parameter identifier: the advertising identifier string.
    @objc(setAdvertisingIdentifier:)
    public static func setAdvertisingIdentifier(adId: String?) {
        let data = [CoreConstants.Keys.ADVERTISING_IDENTIFIER: adId ?? ""]
        let event = Event(name: "SetAdvertisingIdentifier", type: .genericIdentity, source: .requestContent, data: data)
        MobileCore.dispatch(event: event)
    }
    
    /// Submits a generic event containing the provided push token with event type `generic.identity`.
    /// - Parameter deviceToken: the device token for push notifications
    @objc(setPushIdentifier:)
    public static func setPushIdentifier(deviceToken: Data?) {
        let hexString = SHA256.hexStringFromData(input: deviceToken as NSData?)
        let data = [CoreConstants.Keys.PUSH_IDENTIFIER: hexString]
        let event = Event(name: "SetPushIdentifier", type: .genericIdentity, source: .requestContent, data: data)
        MobileCore.dispatch(event: event)
    }
    
    /// Sets the wrapper type for the SDK. Only applicable when being used in a cross platform environment such as React Native
    /// - Parameter type: the `WrapperType` corresponding to the current platform
    @objc(setWrapperType:)
    public static func setWrapperType(type: WrapperType) {
        MobileCore.wrapperType = type
    }
    
}
