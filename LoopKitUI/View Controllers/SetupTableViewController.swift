//
//  SetupTableViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

public protocol SetupTableViewControllerDelegate: class {
    func setupTableViewControllerCancelButtonPressed(_ viewController: SetupTableViewController)
}

open class SetupTableViewController: MultiButtonFooterTableViewController {

    public weak var delegate: SetupTableViewControllerDelegate?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed(_:)))

        footerView = SetupTableFooterView(frame: .zero)
        footerView.primaryButton?.addTarget(self, action: #selector(continueButtonPressed(_:)), for: .touchUpInside)
    }

    @IBAction open func cancelButtonPressed(_: Any) {
        delegate?.setupTableViewControllerCancelButtonPressed(self)
    }

    @IBAction open func continueButtonPressed(_ sender: Any) {
        if shouldPerformSegue(withIdentifier: "Continue", sender: sender) {
            performSegue(withIdentifier: "Continue", sender: sender)
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    open override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    open override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
}
