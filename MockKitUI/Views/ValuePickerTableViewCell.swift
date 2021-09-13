//
//  ValuePickerTableViewCell.swift
//  MockKitUI
//
//  Created by Rick Pasetto on 9/13/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit

class ValuePickerTableViewCell<PickerValue>: UITableViewCell where PickerValue: CustomStringConvertible & RawRepresentable {
    
    var valuePicker: UIPickerView!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        valuePicker = UIPickerView()
        valuePicker.dataSource = source
        valuePicker.delegate = source
        self.addSubview(valuePicker)
    }
    
    private class PickerSource<PickerValue>: NSObject, UIPickerViewDataSource, UIPickerViewDelegate where PickerValue: CustomStringConvertible & RawRepresentable {
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            values.count
        }
        
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            guard row < values.count else {
                return nil
            }
            return values[row].description
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard row < values.count else {
                return
            }
            callback?(values[row])
        }
        
        var values: [PickerValue] = []
        var callback: ((PickerValue) -> Void)?
    }
    
    private var source = PickerSource<PickerValue>()
    public var values: [PickerValue] {
        get {
            return source.values
        }
        set {
            source.values = newValue
            valuePicker.reloadAllComponents()
        }
    }
    
    func onSelected(_ callback: @escaping (PickerValue) -> Void) {
        source.callback = callback
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        valuePicker.center = self.contentView.center
    }
}
