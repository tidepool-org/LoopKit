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
}

private enum Component: Int, CaseIterable {
    case time = 0
    case whole
    case fractional
}

class BasalScheduleEntryTableViewCell: UITableViewCell {

    @IBOutlet weak var picker: UIPickerView!

    @IBOutlet weak var pickerHeightConstraint: NSLayoutConstraint!

    private var pickerExpandedHeight: CGFloat = 0

    @IBOutlet weak var dateLabel: UILabel!

    @IBOutlet weak var unitLabel: UILabel!

    @IBOutlet weak var valueLabel: UILabel!

    public weak var delegate: BasalScheduleEntryTableViewCellDelegate?

    public var maximumBasalRatePerHour: Double = 30

    public var minimumRateIncrement: Double = 0.025 {
        didSet {
            let remainder = abs(minimumRateIncrement.truncatingRemainder(dividingBy: 0.01))
            fractionalNumberFormatter.minimumFractionDigits = remainder > 0.001 ? 3 : 2
        }
    }

    public let pickerInterval: TimeInterval = .hours(0.5)

    private var maximumWholeValue: Int {
        return Int(floor(maximumBasalRatePerHour))
    }

    private var maximumFractionalValue: Double {

        if Int(floor(value)) == maximumWholeValue {
            return maximumBasalRatePerHour.truncatingRemainder(dividingBy: 1)
        } else {
            return 1 - minimumRateIncrement
        }
    }

    public var minimumStartTime: TimeInterval = .hours(0) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
        }
    }
    public var maximumStartTime: TimeInterval = .hours(24.5) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
        }
    }

    var startTime: TimeInterval {
        get {
            let row = picker.selectedRow(inComponent: Component.time.rawValue)
            return startTimeForTimeComponent(row: row)
        }
        set {
            let row = Int(round((newValue - minimumStartTime) / pickerInterval))
            picker.selectRow(row, inComponent: Component.time.rawValue, animated: true)
            updateDateLabel()
        }
    }

    var value: Double = 0 {
        didSet {
            updatePickerWith(newValue: value)
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

    var isReadOnly = false

    override func awakeFromNib() {
        super.awakeFromNib()

        pickerExpandedHeight = pickerHeightConstraint.constant

        setSelected(true, animated: false)
        updateDateLabel()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
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

    lazy var wholeNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    lazy var fractionalNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumIntegerDigits = 0
        return formatter
    }()

    private func startTimeForTimeComponent(row: Int) -> TimeInterval {
        return minimumStartTime + pickerInterval * TimeInterval(row)
    }

    private func stringForStartTime(_ time: TimeInterval) -> String {
        let date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(time)
        return dateFormatter.string(from: date)
    }

    func updateDateLabel() {
        dateLabel.text = stringForStartTime(startTime)
    }

    func validate() {
        if abs(value.remainder(dividingBy: minimumRateIncrement)) > (minimumRateIncrement/10.0) ||
            value > maximumBasalRatePerHour
        {
            valueLabel.textColor = .invalid
        } else {
            valueLabel.textColor = .black
        }
    }

    func updateValueFromPicker() {
        let wholePart = Double(picker.selectedRow(inComponent: Component.whole.rawValue))
        let fractionalPart = Double(picker.selectedRow(inComponent: Component.fractional.rawValue)) * minimumRateIncrement
        value = wholePart + fractionalPart
        updateValueLabel()
    }

    func updatePickerWith(newValue: Double) {
        picker.selectRow(Int(floor(newValue)), inComponent: Component.whole.rawValue, animated: true)
        let fractionalPartIndex = Int(round(newValue.truncatingRemainder(dividingBy: 1) / minimumRateIncrement))
        picker.selectRow(fractionalPartIndex, inComponent: Component.fractional.rawValue, animated: true)
    }

    func updateValueLabel() {
        validate()
        valueLabel.text = valueNumberFormatter.string(from: value)
    }
}


extension BasalScheduleEntryTableViewCell: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {

        switch Component(rawValue: component)! {
        case .time:
            let time = startTimeForTimeComponent(row: row)
            return stringForStartTime(time)
        case .whole:
            return valueNumberFormatter.string(from: Double(row))
        case .fractional:
            return valueNumberFormatter.string(from: Double(row) * minimumRateIncrement)
        }
    }

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        switch Component(rawValue: component)! {
        case .time:
            updateDateLabel()
        case .whole:
            updateValueFromPicker()
            picker.reloadComponent(Component.fractional.rawValue)
        case .fractional:
            updateValueFromPicker()
        }

        delegate?.basalScheduleEntryTableViewCellDidUpdate(self)
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        let w = pickerView.frame.size.width
        switch Component(rawValue: component)! {
        case .time:
            return w / 2.0
        case .whole, .fractional:
            return w / 4.0
        }
    }

    func pickerView(_ pickerView: UIPickerView,
                    viewForRow row: Int,
                    forComponent component: Int,
                    reusing view: UIView?) -> UIView {

        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body).withSize(22)

        switch Component(rawValue: component)! {
        case .time:
            let time = startTimeForTimeComponent(row: row)
            label.text = stringForStartTime(time)
            label.textAlignment = .center
        case .whole:
            label.text = wholeNumberFormatter.string(from: Double(row))
            label.textAlignment = .right
        case .fractional:
            label.text = fractionalNumberFormatter.string(from: Double(row) * minimumRateIncrement)
            label.textAlignment = .left
        }
        return label
    }
}

extension BasalScheduleEntryTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component)! {
        case .time:
            return Int(round((maximumStartTime - minimumStartTime) / pickerInterval) + 1)
        case .whole:
            return maximumWholeValue + 1
        case .fractional:
            return Int(round(maximumFractionalValue / minimumRateIncrement)) + 1
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
