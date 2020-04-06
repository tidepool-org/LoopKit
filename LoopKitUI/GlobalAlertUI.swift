//
//  GlobalAlertUI.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 3/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol AlertSink {
    func showAlert(title: String, message: String, completion: @escaping () -> Void)
}

public final class GlobalAlertUI: AlertSink {
        
    // Singleton
    public static let instance = GlobalAlertUI()
    
    // Threading?
    private var initialized = false
    private weak var rootViewController: UIViewController?
    
    private init() {}
    
    public func initialize(with rootViewController: UIViewController) {
        if initialized { return }
        self.rootViewController = rootViewController
    }
    
    public func destroy() {
    }
    
    public func showAlert(title: String, message: String, completion: @escaping () -> Void) {
        // For now, this is a simple alert with an "OK" button
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { _ in completion() }))
        topViewController(controller: rootViewController)?.present(alert, animated: true)
    }
    
    // Helper function pulled from SO...may be outdated, especially in the SwiftUI world
    private func topViewController(controller: UIViewController?) -> UIViewController? {
        if let tabController = controller as? UITabBarController {
            return topViewController(controller: tabController.selectedViewController)
        }
        if let navController = controller as? UINavigationController {
            return topViewController(controller: navController.visibleViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
