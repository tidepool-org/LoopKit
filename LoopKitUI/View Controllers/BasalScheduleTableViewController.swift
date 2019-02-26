//
//  BasalScheduleTableViewController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public enum SyncBasalScheduleResult<T: RawRepresentable> {
    case success(scheduleItems: [RepeatingScheduleValue<T>], timeZone: TimeZone)
    case failure(Error)
}


public protocol BasalScheduleTableViewControllerSyncSource: class {
    func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (_ result: SyncBasalScheduleResult<Double>) -> Void)

    func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String

    func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String?

    func singleValueScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool
}


open class BasalScheduleTableViewController : DailyValueScheduleTableViewController {

    open override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(BasalScheduleEntryTableViewCell.nib(), forCellReuseIdentifier: BasalScheduleEntryTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if syncSource == nil {
            delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
        }
    }

    @objc private func cancel(_ sender: Any?) {
        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - State

    public var scheduleItems: [RepeatingScheduleValue<Double>] = []

    public var maximumBasalRatePerHour: Double = 30
    public var minimumRateIncrement: Double = 0.025

    private var modifiedSchedule = false {
        didSet {
            if modifiedSchedule {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
        }
    }

    override func addScheduleItem(_ sender: Any?) {
        guard !isReadOnly && !isSyncInProgress else {
            return
        }

        tableView.endEditing(false)

        var startTime = TimeInterval(0)
        var value = 0.0

        if scheduleItems.count > 0 {
            let cell = tableView.cellForRow(at: IndexPath(row: scheduleItems.count - 1, section: 0)) as! BasalScheduleEntryTableViewCell
            let lastItem = scheduleItems.last!
            let interval = cell.pickerInterval

            startTime = lastItem.startTime + interval
            value = lastItem.value

            if startTime >= TimeInterval(hours: 24) {
                return
            }
        }

        scheduleItems.append(
            RepeatingScheduleValue(
                startTime: min(TimeInterval(hours: 23.5), startTime),
                value: value
            )
        )

        super.addScheduleItem(sender)
    }

    override func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        return insertableIndices(for: scheduleItems, removing: row, with: timeInterval)
    }

    func preferredValueFractionDigits() -> Int {
        return 1
    }

    public weak var syncSource: BasalScheduleTableViewControllerSyncSource? {
        didSet {
            isReadOnly = syncSource?.singleValueScheduleTableViewControllerIsReadOnly(self) ?? false

            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    private var isSyncInProgress = false {
        didSet {
            for cell in tableView.visibleCells {
                switch cell {
                case let cell as TextButtonTableViewCell:
                    cell.isEnabled = !isSyncInProgress
                    cell.isLoading = isSyncInProgress
                case let cell as BasalScheduleEntryTableViewCell:
                    cell.isReadOnly = isReadOnly || isSyncInProgress
                default:
                    break
                }
            }

            for item in navigationItem.rightBarButtonItems ?? [] {
                item.isEnabled = !isSyncInProgress
            }

            navigationItem.hidesBackButton = isSyncInProgress
        }
    }

    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case schedule
        case sync
    }

    open override func numberOfSections(in tableView: UITableView) -> Int {
        if syncSource != nil {
            return 2
        }

        return 1
    }

    open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule:
            return scheduleItems.count
        case .sync:
            return 1
        }
    }

    open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            let cell = tableView.dequeueReusableCell(withIdentifier: BasalScheduleEntryTableViewCell.className, for: indexPath) as! BasalScheduleEntryTableViewCell

            let item = scheduleItems[indexPath.row]
            let interval = cell.pickerInterval

            cell.valueNumberFormatter.minimumFractionDigits = preferredValueFractionDigits()
            cell.maximumBasalRatePerHour = maximumBasalRatePerHour
            cell.minimumRateIncrement = minimumRateIncrement
            cell.unitString = unitDisplayString
            //cell.isReadOnly = isReadOnly || isSyncInProgress
            cell.delegate = self

            if indexPath.row > 0 {
                let lastItem = scheduleItems[indexPath.row - 1]

                cell.minimumStartTime = lastItem.startTime + interval
            }
            
            if indexPath.row < scheduleItems.endIndex - 1 {
                let nextItem = scheduleItems[indexPath.row + 1]
                cell.maximumStartTime = nextItem.startTime - interval
            } else if indexPath.row > 0 {
                cell.maximumStartTime = TimeInterval(hours: 24) - interval
            } else {
                cell.maximumStartTime = 0
            }

            cell.value = item.value
            cell.startTime = item.startTime

            return cell
        case .sync:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = syncSource?.syncButtonTitle(for: self)
            cell.isEnabled = !isSyncInProgress
            cell.isLoading = isSyncInProgress

            return cell
        }
    }

    open override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return nil
        case .sync:
            return syncSource?.syncButtonDetailText(for: self)
        }
    }

    open override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            scheduleItems.remove(at: indexPath.row)

            super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
        }
    }

    open override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            let item = scheduleItems.remove(at: sourceIndexPath.row)
            scheduleItems.insert(item, at: destinationIndexPath.row)

            guard destinationIndexPath.row > 0, let cell = tableView.cellForRow(at: destinationIndexPath) as? BasalScheduleEntryTableViewCell else {
                return
            }

            let interval = cell.pickerInterval
            let startTime = scheduleItems[destinationIndexPath.row - 1].startTime + interval

            scheduleItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: scheduleItems[destinationIndexPath.row].value)

            // Since the valid date ranges of neighboring cells are affected, the lazy solution is to just reload the entire table view
            DispatchQueue.main.async {
                tableView.reloadData()
            }
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == 0 else {
            return super.tableView(tableView, shouldHighlightRowAt: indexPath)
        }

        return !isReadOnly
    }

    open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.beginUpdates()
        hideBasalScheduleEntryCells(excluding: indexPath)
        tableView.endUpdates()
        return super.tableView(tableView, willSelectRowAt: indexPath)
    }

    open override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return super.tableView(tableView, canEditRowAt: indexPath) && !isSyncInProgress
    }

    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            break
        case .sync:
            if let syncSource = syncSource, !isSyncInProgress {
                isSyncInProgress = true
                syncSource.syncScheduleValues(for: self) { (result) in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let items, let timeZone):
                            self.scheduleItems = items
                            self.timeZone = timeZone
                            self.tableView.reloadSections([Section.schedule.rawValue], with: .fade)
                            self.isSyncInProgress = false
                            self.delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
                            self.modifiedSchedule = false
                        case .failure(let error):
                            self.present(UIAlertController(with: error), animated: true) {
                                self.isSyncInProgress = false
                            }
                        }
                    }
                }
            }
        }
    }

    open override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

        guard sourceIndexPath != proposedDestinationIndexPath, let cell = tableView.cellForRow(at: sourceIndexPath) as? BasalScheduleEntryTableViewCell else {
            return proposedDestinationIndexPath
        }

        let interval = cell.pickerInterval
        let indices = insertableIndices(for: scheduleItems, removing: sourceIndexPath.row, with: interval)

        if indices[proposedDestinationIndexPath.row] {
            return proposedDestinationIndexPath
        } else {
            var closestRow = sourceIndexPath.row

            for (index, valid) in indices.enumerated() where valid {
                if abs(proposedDestinationIndexPath.row - index) < closestRow {
                    closestRow = index
                }
            }

            return IndexPath(row: closestRow, section: proposedDestinationIndexPath.section)
        }
    }
}

extension BasalScheduleTableViewController: BasalScheduleEntryTableViewCellDelegate {
    func basalScheduleEntryTableViewCellDidUpdate(_ cell: BasalScheduleEntryTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            modifiedSchedule = true
            scheduleItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.startTime,
                value: cell.value
            )
        }
    }
}

