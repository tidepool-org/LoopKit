//
//  GlucoseRangeTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

private enum Component: Int, CaseIterable {
    case time = 0
    case minValue
    case separator
    case maxValue
    case units
}

protocol GlucoseRangeTableViewCellDelegate: class {
    func glucoseRangeTableViewCellDidUpdate(_ cell: GlucoseRangeTableViewCell)
}

class GlucoseRangeTableViewCell: UITableViewCell {

    enum EmptySelectionType {
        case none
        case firstIndex
        case lastIndex

        var rowCount: Int {
            if self == .none {
                return 0
            } else {
                return 1
            }
        }
    }

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet open weak var picker: UIPickerView!
    @IBOutlet open weak var pickerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var minValueTextField: UITextField!
    @IBOutlet weak var maxValueTextField: UITextField!
    @IBOutlet weak var unitLabel: UILabel!

    private var pickerExpandedHeight: CGFloat = 0

    public var minimumTimeInterval: TimeInterval = .hours(0.5)

    public weak var delegate: GlucoseRangeTableViewCellDelegate?

    var minValue: Double? {
        didSet {
            guard let value = minValue else {
                minValueTextField.text = nil
                return
            }
            minValueTextField.text = valueNumberFormatter.string(from: value)
        }
    }

    var maxValue: Double? {
        didSet {
            guard let value = maxValue else {
                maxValueTextField.text = nil
                return
            }
            maxValueTextField.text = valueNumberFormatter.string(from: value)
        }
    }

    public var allowedValues: [Double] = [] {
        didSet {
            picker.reloadAllComponents()
            selectPickerValues()
        }
    }

    public var emptySelectionType = EmptySelectionType.none {
        didSet {
            picker.reloadAllComponents()
            selectPickerValues()
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

    lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1

        return formatter
    }()

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()

    public var timeZone: TimeZone! {
        didSet {
            dateFormatter.timeZone = timeZone
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            startOfDay = calendar.startOfDay(for: Date())
        }
    }

    private lazy var startOfDay = Calendar.current.startOfDay(for: Date())

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

    public var minimumStartTime: TimeInterval = .hours(0) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
            updateStartTimeSelection()
        }
    }
    public var maximumStartTime: TimeInterval = .hours(23.5) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
        }
    }

    var isPickerHidden: Bool {
        get {
            return picker.isHidden
        }
        set {
            picker.isHidden = newValue
            pickerHeightConstraint.constant = newValue ? 0 : pickerExpandedHeight

            if !newValue {
                selectPickerValues()
            }
        }
    }


    private func updateStartTimeSelection() {
        let row = Int(round((startTime - minimumStartTime) / minimumTimeInterval))
        if row >= 0 && row < pickerView(picker, numberOfRowsInComponent: Component.time.rawValue) {
            picker.selectRow(row, inComponent: Component.time.rawValue, animated: true)
        }
    }

    fileprivate func selectPickerValue(for component: Component, with selectedValue: Double?) {
        guard !allowedValues.isEmpty else {
            return
        }
        let selectedIndex: Int
        let rowOffset = emptySelectionType == .firstIndex ? 1 : 0
        if let value = selectedValue {
            if let row = allowedValues.firstIndex(of: value) {
                selectedIndex = row + rowOffset
            } else {
                // Select next highest value
                selectedIndex = allowedValues.enumerated().filter({$0.element >= value}).min(by: { $0.1 < $1.1 })?.offset ?? 0
            }
        } else {
            switch emptySelectionType {
            case .none:
                selectedIndex = allowedValues.count - 1
            case .firstIndex:
                selectedIndex = 0
            case .lastIndex:
                selectedIndex = allowedValues.count
            }
        }
        picker.selectRow(selectedIndex, inComponent: component.rawValue, animated: true)
    }

    fileprivate func selectPickerValues() {
        selectPickerValue(for: .minValue, with: minValue)
        selectPickerValue(for: .maxValue, with: maxValue)
    }

    fileprivate func updateValueFromPicker(for component: Component) {
        let rowOffset = emptySelectionType == .firstIndex ? 1 : 0
        let index = picker.selectedRow(inComponent: component.rawValue) - rowOffset
        let value: Double?
        if index >= 0 && index < allowedValues.count {
            value = allowedValues[index]
        } else {
            value = nil
        }
        switch component {
        case .maxValue:
            maxValue = value
        case .minValue:
            minValue = value
        default:
            break
        }
    }

    func updateDateLabel() {
        dateLabel.text = stringForStartTime(startTime)
    }

    private func startTimeForTimeComponent(row: Int) -> TimeInterval {
        return minimumStartTime + minimumTimeInterval * TimeInterval(row)
    }

    private func stringForStartTime(_ time: TimeInterval) -> String {
        let date = startOfDay.addingTimeInterval(time)
        return dateFormatter.string(from: date)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        pickerExpandedHeight = pickerHeightConstraint.constant

        setSelected(true, animated: false)
        updateDateLabel()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            isPickerHidden.toggle()
        }
    }
}

extension GlucoseRangeTableViewCell: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent componentRaw: Int) {
        let component = Component(rawValue: componentRaw)!
        switch component {
        case .time:
            startTime = selectedStartTime
        case .minValue, .maxValue:
            updateValueFromPicker(for: component)
        default:
            break
        }

        delegate?.glucoseRangeTableViewCellDidUpdate(self)
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return [33,16,4,16,24][component] / 100.0 * picker.frame.width
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
        case .minValue, .maxValue:
            let valueRow = emptySelectionType == .firstIndex ? row - 1 : row
            guard valueRow >= 0 && valueRow < allowedValues.count else {
                return nil
            }
            return valueNumberFormatter.string(from: allowedValues[row])
        case .separator:
            return "–"
        case .units:
            return unitString
        }
    }
}

extension GlucoseRangeTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component)! {
        case .time:
            return Int(round((maximumStartTime - minimumStartTime) / minimumTimeInterval) + 1)
        case .minValue, .maxValue:
            return allowedValues.count + emptySelectionType.rowCount
        case .units, .separator:
            return 1
        }

    }
}

/// UITableViewController extensions to aid working with DatePickerTableViewCell
extension GlucoseRangeTableViewCellDelegate where Self: UITableViewController {
    func hideSetConstrainedScheduleEntryCells(excluding indexPath: IndexPath? = nil) {
        for case let cell as SetConstrainedScheduleEntryTableViewCell in tableView.visibleCells where tableView.indexPath(for: cell) != indexPath && cell.isPickerHidden == false {
            cell.isPickerHidden = true
        }
    }
}
