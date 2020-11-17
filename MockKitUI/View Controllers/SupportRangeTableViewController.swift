//
//  SupportRangeTableViewController.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2020-11-16.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation


import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


protocol SupportRangeTableViewControllerDelegate: class {
    func supportedRangeDidUpdate(_ controller: SupportRangeTableViewController)
}

final class SupportRangeTableViewController: UITableViewController {

    weak var delegate: SupportRangeTableViewControllerDelegate?

    var minValue: Double
    
    var maxValue: Double
    
    var stepSize: Double
    
    var indexPath: IndexPath?
    
    init(minValue: Double,
         maxValue: Double,
         stepSize: Double)
    {
        self.minValue = minValue
        self.maxValue = maxValue
        self.stepSize = stepSize
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
    }

    // MARK: - Data Source

    private enum Row: Int, CaseIterable {
        case minValue = 0
        case maxValue
        case stepSize
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Changing the supported values of the pump may cause the app to crash. Ensure you are changing them such that the set therapy values are still valid (e.g., basal rate, max bolus, etc.)"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell

        switch Row(rawValue: indexPath.row)! {
        case .minValue:
            cell.textLabel?.text = "Minimum Value"
            cell.detailTextLabel?.text = "\(minValue)"
        case .maxValue:
            cell.textLabel?.text = "Maximum Value"
            cell.detailTextLabel?.text = "\(maxValue)"
        case .stepSize:
            cell.textLabel?.text = "Step Size"
            cell.detailTextLabel?.text = "\(stepSize)"
        }

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)
        
        let value: Double
        switch Row(rawValue: indexPath.row)! {
        case .minValue:
            value = minValue
        case .maxValue:
            value = maxValue
        case .stepSize:
            value = stepSize
        }

        let vc = TextFieldTableViewController()
        vc.value = "\(value)"
        vc.keyboardType = .decimalPad
        vc.indexPath = indexPath
        vc.delegate = self
        show(vc, sender: sender)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SupportRangeTableViewController: TextFieldTableViewControllerDelegate {
    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController) {
        update(from: controller)
    }

    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController) {
        update(from: controller)
    }

    private func update(from controller: TextFieldTableViewController) {
        guard let indexPath = controller.indexPath,
              let value = controller.value.flatMap(Double.init) else { assertionFailure(); return }

        switch Row(rawValue: indexPath.row)! {
        case .minValue:
            minValue = max(value, 0.0)
        case .maxValue:
            maxValue = max(value, 0.0)
        case .stepSize:
            stepSize = max(value, 0.0)
        }

        delegate?.supportedRangeDidUpdate(self)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
