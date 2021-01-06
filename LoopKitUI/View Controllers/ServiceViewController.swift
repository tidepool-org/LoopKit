//
//  ServiceViewController.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

open class ServiceViewController: UINavigationController, ServiceCreateNotifying, ServiceOnboardNotifying, CompletionNotifying {
    public weak var serviceCreateDelegate: ServiceCreateDelegate?
    public weak var serviceOnboardDelegate: ServiceOnboardDelegate?
    public weak var completionDelegate: CompletionDelegate?

    public func notifyServiceCreated(_ service: Service) {
        serviceCreateDelegate?.serviceCreateNotifying(self, didCreateService: service)
    }

    public func notifyServiceSetup(_ service: Service) {
        serviceOnboardDelegate?.serviceOnboardNotifying(self, didOnboardService: service)
    }

    public func notifyServiceCreatedAndSetup(_ service: ServiceUI) {
        notifyServiceCreated(service)
        notifyServiceSetup(service)
    }

    public func notifyComplete() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }
}
