//
//  ServiceTableViewController.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

open class ServiceTableViewController: UITableViewController {

    public enum Operation {
        case create
        case update
    }

    public let service: Service
    public let operation: Operation

    public init(service: Service, for operation: Operation) {
        self.service = service
        self.operation = operation

        super.init(style: .grouped)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        title = service.localizedTitle

        if operation == .create {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

        updateButtonStates()
    }

    public func updateButtonStates() {
        navigationItem.rightBarButtonItem?.isEnabled = service.hasConfiguration
    }

    @objc public func cancel() {
        view.endEditing(true)

        notifyComplete()
    }

    @objc public func done() {
        guard service.hasConfiguration else {
            return
        }

        view.endEditing(true)

        UIView.animate(withDuration: 0.25, animations: {
            self.navigationItem.titleView = ValidatingIndicatorView(frame: CGRect.zero)
        })

        service.verifyConfiguration { error in
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.25, animations: {
                    self.navigationItem.titleView = nil
                })

                if let error = error {
                    self.present(UIAlertController(with: error), animated: true)
                    return
                }

                switch self.operation {
                case .create:
                    self.completeCreate()
                case .update:
                    self.completeUpdate()
                }
            }
        }
    }

    public func confirmDeletion(completion: (() -> Void)? = nil) {
        view.endEditing(true)

        let alert = UIAlertController(serviceDeletionHandler: {
            self.completeDelete()
        })

        present(alert, animated: true, completion: completion)
    }

    private func completeCreate() {
        service.completeCreate()
        notifyServiceCreated(service)
        notifyComplete()
        }

    private func completeUpdate() {
        service.completeUpdate()
        notifyServiceUpdated(service)
        notifyComplete()
    }

    private func completeDelete() {
        service.completeDelete()
        notifyServiceDeleted(service)
        notifyComplete()
            }

    private func notifyServiceCreated(_ service: Service) {
        if let serviceDelegate = navigationController as? ServiceDelegate {
            serviceDelegate.notifyServiceCreated(service)
        }
    }

    private func notifyServiceUpdated(_ service: Service) {
        if let serviceDelegate = navigationController as? ServiceDelegate {
            serviceDelegate.notifyServiceUpdated(service)
            }
        }

    private func notifyServiceDeleted(_ service: Service) {
        if let serviceDelegate = navigationController as? ServiceDelegate {
            serviceDelegate.notifyServiceDeleted(service)
        }
    }

    private func notifyComplete() {
        if let serviceViewController = navigationController as? ServiceViewController {
            serviceViewController.notifyComplete()
        }
    }

}


extension UIAlertController {

    convenience init(serviceDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: NSLocalizedString("Are you sure you want to delete this service?", comment: "Confirmation message for deleting a service"),
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: NSLocalizedString("Delete Service", comment: "Button title to delete a service"),
            style: .destructive,
            handler: { _ in
                handler()
        }
        ))

        let cancel = NSLocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }

}
