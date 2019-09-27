//
//  ServiceViewController.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

open class ServiceViewController: UINavigationController, ServiceDelegate, ServiceNotifying, CompletionNotifying {

    public weak var serviceDelegate: ServiceDelegate?

    public weak var completionDelegate: CompletionDelegate?

    public func notifyServiceCreated(_ service: Service) {
        serviceDelegate?.notifyServiceCreated(service)
    }

    public func notifyServiceUpdated(_ service: Service) {
        serviceDelegate?.notifyServiceUpdated(service)
    }

    public func notifyServiceDeleted(_ service: Service) {
        serviceDelegate?.notifyServiceDeleted(service)
    }

    public func notifyComplete() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }

}
