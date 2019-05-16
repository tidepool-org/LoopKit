//
//  ServiceViewController.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


open class ServiceViewController: UINavigationController, ServiceSetupNotifying, CompletionNotifying {

    public weak var serviceSetupDelegate: ServiceSetupDelegate?

    public weak var completionDelegate: CompletionDelegate?

    public func notifySetupService(_ service: Service) {
        serviceSetupDelegate?.serviceSetupNotifyingDidSetupService(self, service: service)
    }

    public func notifyComplete() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }

}
