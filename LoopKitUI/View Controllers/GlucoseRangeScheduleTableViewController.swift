//
//  GlucoseRangeScheduleTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit

public enum SaveGlucoseRangeScheduleResult {
    case success
    case failure(Error)
}

public protocol GlucoseRangeScheduleStorageDelegate {
    func saveSchedule(_ schedule: GlucoseRangeSchedule, for viewController: GlucoseRangeScheduleTableViewController, completion: @escaping (_ result: SaveGlucoseRangeScheduleResult) -> Void)
}

private struct EditableRange {
    public let minValue: Double?
    public let maxValue: Double?

    public init(minValue: Double?, maxValue: Double?) {
        self.minValue = minValue
        self.maxValue = maxValue
    }
}

public class GlucoseRangeScheduleTableViewController: DailyValueScheduleTableViewController, GlucoseRangeTableViewCellDelegate {

    public init(allowedValues: [Double], minimumTimeInterval: TimeInterval? = nil, unit: HKUnit) {
        self.allowedValues = allowedValues
        self.minimumTimeInterval = minimumTimeInterval ?? .minutes(30)

        super.init(style: .grouped)

        self.unit = unit
        unitDisplayString = unit.glucoseUnitDisplayString
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(GlucoseRangeTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeTableViewCell.className)
        tableView.register(GlucoseRangeOverrideTableViewCell.nib(), forCellReuseIdentifier: GlucoseRangeOverrideTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)

        updateEditButton()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
    }

    @objc private func cancel(_ sender: Any?) {
        self.navigationController?.popViewController(animated: true)
    }

    private func updateInsertButton() {
        guard let lastItem = editableItems.last else {
            return
        }
        insertButtonItem.isEnabled = !isEditing && lastItem.startTime < lastValidStartTime
    }

    private func updateSaveButton() {
        if let section = sections.firstIndex(of: .save), let cell = tableView.cellForRow(at: IndexPath(row: 0, section: section)) as? TextButtonTableViewCell {
            cell.isEnabled = isScheduleModified && isScheduleValid
        }
    }

    private var isScheduleValid: Bool {
        return !editableItems.isEmpty &&
            editableItems.allSatisfy { isValid($0.value) }
    }

    private func updateEditButton() {
        editButtonItem.isEnabled = editableItems.endIndex > 1
    }


    // MARK: - State

    public var glucoseRangeScheduleStorageDelegate: GlucoseRangeScheduleStorageDelegate?

    let allowedValues: [Double]
    let minimumTimeInterval: TimeInterval

    var lastValidStartTime: TimeInterval {
        return TimeInterval.hours(24) - minimumTimeInterval
    }

    private var unit: HKUnit = HKUnit.milligramsPerDeciliter {
        didSet {
            unitDisplayString = unit.glucoseUnitDisplayString
        }
    }

    private var isScheduleModified = false {
        didSet {
            if isScheduleModified {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
            updateSaveButton()
        }
    }

    private var editableItems: [RepeatingScheduleValue<EditableRange>] = [] {
        didSet {
            isScheduleModified = true
            updateInsertButton()
            updateEditButton()
        }
    }

    public var schedule: GlucoseRangeSchedule? {
        get {
            let dailyItems = editableItems.compactMap { (item) -> RepeatingScheduleValue<DoubleRange>? in
                guard isValid(item.value) else {
                    return nil
                }
                guard let min = item.value.minValue, let max = item.value.maxValue else {
                    return nil
                }
                let range = DoubleRange(minValue: min, maxValue: max)
                return RepeatingScheduleValue(startTime: item.startTime, value: range)
            }
            return GlucoseRangeSchedule(unit: unit, dailyItems: dailyItems)
        }
        set {
            if let newValue = newValue {
                unit = newValue.unit
                editableItems = newValue.items.map({ (item) -> RepeatingScheduleValue<EditableRange> in
                    let range = EditableRange(minValue: item.value.minValue, maxValue: item.value.maxValue)
                    return RepeatingScheduleValue<EditableRange>(startTime: item.startTime, value: range)
                })
                isScheduleModified = false
            }
        }
    }

    public var overrideContexts: [TemporaryScheduleOverride.Context] = [.preMeal, .legacyWorkout]

    public var overrideRanges: [TemporaryScheduleOverride.Context: DoubleRange] = [:]

    private func isValid(_ range: EditableRange) -> Bool {
        guard let max = range.maxValue, let min = range.minValue else {
            return false
        }
        return allowedValues.contains(max) && allowedValues.contains(min)
    }

    override func addScheduleItem(_ sender: Any?) {

        guard let allowedTimeRange = allowedTimeRange(for: editableItems.count) else {
            return
        }

        editableItems.append(
            RepeatingScheduleValue(
                startTime: allowedTimeRange.lowerBound,
                value: editableItems.last?.value ?? EditableRange(minValue: nil, maxValue: nil)
            )
        )

        tableView.beginUpdates()

        tableView.insertRows(at: [IndexPath(row: editableItems.count - 1, section: Section.schedule.rawValue)], with: .automatic)

        if editableItems.count == 1 {
            tableView.insertSections(IndexSet(integer: Section.override.rawValue), with: .automatic)
        }

        tableView.endUpdates()
    }

    private func updateTimeLimits(for index: Int) {
        let indexPath = IndexPath(row: index, section: Section.schedule.rawValue)
        if let allowedTimeRange = allowedTimeRange(for: index), let cell = tableView.cellForRow(at: indexPath) as? GlucoseRangeTableViewCell {
            cell.allowedTimeRange = allowedTimeRange
        }
    }

    private func allowedTimeRange(for index: Int) -> ClosedRange<TimeInterval>? {
        let minTime: TimeInterval
        let maxTime: TimeInterval
        if index == 0 {
            maxTime = TimeInterval(0)
        } else if index+1 < editableItems.endIndex {
            maxTime = editableItems[index+1].startTime - minimumTimeInterval
        } else {
            maxTime = lastValidStartTime
        }
        if index > 0 {
            minTime = editableItems[index-1].startTime + minimumTimeInterval
            if minTime > lastValidStartTime {
                return nil
            }
        } else {
            minTime = TimeInterval(0)
        }
        return minTime...maxTime
    }

    override func insertableIndiciesByRemovingRow(_ row: Int, withInterval timeInterval: TimeInterval) -> [Bool] {
        return insertableIndices(for: editableItems, removing: row, with: timeInterval)
    }

    // MARK: - UITableViewDataSource

    private enum Section: Int, CaseIterable {
        case schedule = 0
        case override
        case save
    }

    private var showOverrides: Bool {
        return !editableItems.isEmpty
    }

    private var sections: [Section] {
        if !showOverrides {
            return [.schedule, .save]
        } else {
            return Section.allCases
        }
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .schedule:
            return editableItems.count
        case .override:
            return overrideContexts.count
        case .save:
            return 1
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .schedule:
            let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseRangeTableViewCell.className, for: indexPath) as! GlucoseRangeTableViewCell

            let item = editableItems[indexPath.row]

            cell.timeZone = timeZone
            cell.startTime = item.startTime

            cell.allowedValues = allowedValues

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredFractionDigits
            cell.valueNumberFormatter.maximumFractionDigits = unit.preferredFractionDigits

            cell.minValue = item.value.minValue
            cell.maxValue = item.value.maxValue
            cell.unitString = unitDisplayString
            cell.delegate = self

            if let allowedTimeRange = allowedTimeRange(for: indexPath.row) {
                cell.allowedTimeRange = allowedTimeRange
            }

            return cell
        case .override:
            let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseRangeOverrideTableViewCell.className, for: indexPath) as! GlucoseRangeOverrideTableViewCell

            cell.valueNumberFormatter.minimumFractionDigits = unit.preferredFractionDigits
            cell.valueNumberFormatter.maximumFractionDigits = unit.preferredFractionDigits

            let context = overrideContexts[indexPath.row]

            if let range = overrideRanges[context], !range.isZero {
                cell.minValue = range.minValue
                cell.maxValue = range.maxValue
            }

            let bundle = Bundle(for: type(of: self))
            let titleText: String
            let image: UIImage?

            switch context {
            case .legacyWorkout:
                titleText = LocalizedString("Workout", comment: "Title for the workout override range")
                image = UIImage(named: "workout", in: bundle, compatibleWith: traitCollection)
            case .preMeal:
                titleText = LocalizedString("Pre-Meal", comment: "Title for the pre-meal override range")
                image = UIImage(named: "Pre-Meal", in: bundle, compatibleWith: traitCollection)
            default:
                preconditionFailure("Unexpected override context \(context)")
            }

            cell.titleLabel.text = titleText
            cell.iconImageView.image = image

            cell.unitString = unitDisplayString
            cell.delegate = self

            return cell
        case .save:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = LocalizedString("Save", comment: "Button text for saving glucose correction range schedule")
            cell.isEnabled = isScheduleModified
            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, let overrideSectionIndex = sections.firstIndex(of: .override) {
            editableItems.remove(at: indexPath.row)

            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)

                if editableItems.count == 0 {
                    tableView.deleteSections(IndexSet(integer: overrideSectionIndex), with: .automatic)
                }
            }, completion: nil)

            updateSaveButton()
        }
    }

    public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            switch sections[destinationIndexPath.section] {
            case .schedule:
                let item = editableItems.remove(at: sourceIndexPath.row)
                editableItems.insert(item, at: destinationIndexPath.row)

                guard destinationIndexPath.row > 0 else {
                    return
                }

                let startTime = editableItems[destinationIndexPath.row - 1].startTime + minimumTimeInterval

                editableItems[destinationIndexPath.row] = RepeatingScheduleValue(startTime: startTime, value: editableItems[destinationIndexPath.row].value)

                // Since the valid date ranges of neighboring cells are affected, the lazy solution is to just reload the entire table view
                DispatchQueue.main.async {
                    tableView.reloadData()
                }
            case .override, .save:
                break
            }
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .schedule:
            return true
        default:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .schedule:
            return true
        default:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .override:
            return LocalizedString("Overrides", comment: "The section title of glucose overrides")
        default:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section] {
        case .schedule:
            return LocalizedString("Correction range is the blood glucose range that you would like Loop to correct to.", comment: "The section footer of correction range schedule")
        default:
            return nil
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch sections[indexPath.section] {
        case .schedule:
            updateTimeLimits(for: indexPath.row)
            tableView.performBatchUpdates({
                hideGlucoseRangeCells(excluding: indexPath)
            }, completion: nil)
            return super.tableView(tableView, willSelectRowAt: indexPath)
        default:
            return indexPath
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .schedule:
            super.tableView(tableView, didSelectRowAt: indexPath)
        case .override:
            break
        case .save:
            if let schedule = schedule {
                glucoseRangeScheduleStorageDelegate?.saveSchedule(schedule, for: self, completion: { (result) in
                    switch result {
                    case .success:
                        self.delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
                        self.isScheduleModified = false
                        self.updateInsertButton()
                    case .failure(let error):
                        self.present(UIAlertController(with: error), animated: true)
                    }
                })
            }
        }
    }

    // MARK: - GlucoseRangeTableViewCellDelegate
    func glucoseRangeTableViewCellDidUpdate(_ cell: GlucoseRangeTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            editableItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.startTime,
                value: EditableRange(minValue: cell.minValue, maxValue: cell.maxValue)
            )
        }
    }
}


extension GlucoseRangeScheduleTableViewController: GlucoseRangeOverrideTableViewCellDelegate {
    func glucoseRangeOverrideTableViewCellDidUpdateValue(_ cell: GlucoseRangeOverrideTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        let context = overrideContexts[indexPath.row]
        overrideRanges[context] = DoubleRange(minValue: cell.minValue, maxValue: cell.maxValue)
    }
}
