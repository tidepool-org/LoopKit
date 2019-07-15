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
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        delegate?.dailyValueScheduleTableViewControllerWillFinishUpdating(self)
    }

    // MARK: - State

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
    private var editableItems: [RepeatingScheduleValue<EditableRange>] = []

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

    private enum Section: Int {
        case schedule = 0
        case override

        static let count = 2
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        if editableItems.isEmpty {
            return Section.count - 1
        } else {
            return Section.count
        }
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .schedule:
            return editableItems.count
        case .override:
            return overrideContexts.count
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
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

            if indexPath.row > 0 {
                let lastItem = editableItems[indexPath.row - 1]

                cell.startTime = lastItem.startTime + minimumTimeInterval
            }

            if let allowedTimeRange = allowedTimeRange(for: indexPath.row) {
                cell.allowedTimeRange = allowedTimeRange
                cell.startTime = allowedTimeRange.lowerBound
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
        }
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            editableItems.remove(at: indexPath.row)

            tableView.beginUpdates()

            tableView.deleteRows(at: [indexPath], with: .automatic)

            if editableItems.count == 0 {
                tableView.deleteSections(IndexSet(integer: Section.override.rawValue), with: .automatic)
            }

            tableView.endUpdates()
        }
    }

    public override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath != destinationIndexPath {
            switch Section(rawValue: destinationIndexPath.section)! {
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
            case .override:
                break
            }
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return true
        case .override:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            return true
        case .override:
            return false
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .schedule:
            return nil
        case .override:
            return LocalizedString("Overrides", comment: "The section title of glucose overrides")
        }
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == Section.schedule.rawValue 
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            updateTimeLimits(for: indexPath.row)
            tableView.beginUpdates()
            hideGlucoseRangeCells(excluding: indexPath)
            tableView.endUpdates()
            return super.tableView(tableView, willSelectRowAt: indexPath)
        case .override:
            return nil
        }

        
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .schedule:
            super.tableView(tableView, didSelectRowAt: indexPath)
        case .override:
            break
        }
    }

    // MARK: - GlucoseRangeTableViewCellDelegate
    func glucoseRangeTableViewCellDidUpdate(_ cell: GlucoseRangeTableViewCell) {
        if let indexPath = tableView.indexPath(for: cell) {
            let currentItem = editableItems[indexPath.row]

            editableItems[indexPath.row] = RepeatingScheduleValue(
                startTime: cell.startTime,
                value: currentItem.value
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
