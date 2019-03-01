//
//  BasalScheduleEntryTableViewCell.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

protocol BasalScheduleEntryTableViewCellDelegate: class {
    func basalScheduleEntryTableViewCellDidUpdate(_ cell: BasalScheduleEntryTableViewCell)
    func validateBasalScheduleEntryTableViewCell(_ cell: BasalScheduleEntryTableViewCell) -> Bool
}

private enum Component: Int, CaseIterable {
    case time = 0
    case value
}

class BasalScheduleEntryTableViewCell: UITableViewCell {

    @IBOutlet private weak var picker: UIPickerView!

    @IBOutlet private weak var pickerHeightConstraint: NSLayoutConstraint!

    private var pickerExpandedHeight: CGFloat = 0

    @IBOutlet private weak var dateLabel: UILabel!

    @IBOutlet private weak var unitLabel: UILabel!

    @IBOutlet private weak var valueLabel: UILabel!

    public weak var delegate: BasalScheduleEntryTableViewCellDelegate?

    public var basalRates: [Double] = [] {
        didSet {
            updateValuePicker(with: value)
        }
    }

    public var minimumTimeInterval: TimeInterval = .hours(0.5)

    public var minimumStartTime: TimeInterval = .hours(0) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
            updateStartTimeSelection()
        }
    }
    public var maximumStartTime: TimeInterval = .hours(24.5) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
        }
    }

    var startTime: TimeInterval = 0 {
        didSet {
            updateStartTimeSelection()
            updateDateLabel()
        }
    }

    var selectedStartTime: TimeInterval {
        let row = picker.selectedRow(inComponent: Component.time.rawValue)
        return startTimeForTimeComponent(row: row)
    }

    var value: Double = 0 {
        didSet {
            updateValuePicker(with: value)
            updateValueLabel()
        }
    }

    var unitString: String? {
        get {
            return unitLabel.text
        }
        set {
            unitLabel.text = newValue
        }
    }

    var isPickerHidden: Bool {
        get {
            return picker.isHidden
        }
        set {
            picker.isHidden = newValue
            pickerHeightConstraint.constant = newValue ? 0 : pickerExpandedHeight
        }
    }

    private lazy var startOfDay: Date = {
        return Calendar.current.startOfDay(for: Date())
    }()

    var isReadOnly = false

    override func awakeFromNib() {
        super.awakeFromNib()

        pickerExpandedHeight = pickerHeightConstraint.constant

        setSelected(true, animated: false)
        updateDateLabel()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected && !isReadOnly {
            isPickerHidden = !isPickerHidden
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()

    lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1

        return formatter
    }()

    private func startTimeForTimeComponent(row: Int) -> TimeInterval {
        return minimumStartTime + minimumTimeInterval * TimeInterval(row)
    }

    private func stringForStartTime(_ time: TimeInterval) -> String {
        let date = startOfDay.addingTimeInterval(time)
        return dateFormatter.string(from: date)
    }

    func updateDateLabel() {
        dateLabel.text = stringForStartTime(startTime)
    }

    func validate() {
        if delegate?.validateBasalScheduleEntryTableViewCell(self) == true
        {
            valueLabel.textColor = .darkText
        } else {
            valueLabel.textColor = .invalid
        }
    }

    func updateValueFromPicker() {
        value = basalRates[picker.selectedRow(inComponent: Component.value.rawValue)]
        updateValueLabel()
    }

    private func updateStartTimeSelection() {
        let row = Int(round((startTime - minimumStartTime) / minimumTimeInterval))
        if row >= 0 && row < pickerView(picker, numberOfRowsInComponent: Component.time.rawValue) {
            picker.selectRow(row, inComponent: Component.time.rawValue, animated: true)
        }
    }

    func updateValuePicker(with newValue: Double) {
        let selectedIndex: Int
        if let row = basalRates.firstIndex(of: newValue) {
            selectedIndex = row
        } else {
            let closest = basalRates.enumerated().min(by: { abs($0.1 - newValue) < abs($1.1 - newValue)} )!
            selectedIndex = closest.offset
        }
        picker.selectRow(selectedIndex, inComponent: Component.value.rawValue, animated: true)
    }

    func updateValueLabel() {
        validate()
        valueLabel.text = valueNumberFormatter.string(from: value)
    }
}


extension BasalScheduleEntryTableViewCell: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        switch Component(rawValue: component)! {
        case .time:
            startTime = selectedStartTime
        case .value:
            updateValueFromPicker()
        }

        delegate?.basalScheduleEntryTableViewCellDidUpdate(self)
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .body)
        return metrics.scaledValue(for: 32)
    }

    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {

        switch Component(rawValue: component)! {
        case .time:
            let time = startTimeForTimeComponent(row: row)
            return stringForStartTime(time)
        case .value:
            return valueNumberFormatter.string(from: basalRates[row])
        }
    }
}

extension BasalScheduleEntryTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component)! {
        case .time:
            return Int(round((maximumStartTime - minimumStartTime) / minimumTimeInterval) + 1)
        case .value:
            return basalRates.count
        }
    }
}

/// UITableViewController extensions to aid working with DatePickerTableViewCell
extension BasalScheduleEntryTableViewCellDelegate where Self: UITableViewController {
    func hideBasalScheduleEntryCells(excluding indexPath: IndexPath? = nil) {
        for case let cell as BasalScheduleEntryTableViewCell in tableView.visibleCells where tableView.indexPath(for: cell) != indexPath && cell.isPickerHidden == false {
            cell.isPickerHidden = true
        }
    }
}
