//
//  SizeablePicker.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 12/7/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

struct SizeablePicker<SelectionValue>: UIViewRepresentable where SelectionValue: CustomStringConvertible & Hashable {
    let selection: Binding<SelectionValue>
    // TODO: Would be nice if we could just use `ForEach` and Content, but for now, this'll do
    let data: [SelectionValue]
    let formatter: (SelectionValue) -> String
    let colorer: (SelectionValue) -> Color

    private var selectedRow: Int = 0

    public init(selection: Binding<SelectionValue>,
                data: [SelectionValue],
                formatter: @escaping (SelectionValue) -> String = { $0.description },
                colorer: @escaping (SelectionValue) -> Color = { _ in .primary }
    ) {
        self.selection = selection
        self.selectedRow = data.firstIndex(of: selection.wrappedValue) ?? 0
        self.data = data
        self.formatter = formatter
        self.colorer = colorer
    }

    //makeCoordinator()
    func makeCoordinator() -> SizeablePicker.Coordinator {
        Coordinator(self)
    }

    //makeUIView(context:)
    func makeUIView(context: UIViewRepresentableContext<SizeablePicker>) -> UIPickerView {
        let picker = UIPickerViewResizeable(frame: .zero)
        
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        return picker
    }

    //updateUIView(_:context:)
    func updateUIView(_ view: UIPickerView, context: UIViewRepresentableContext<SizeablePicker>) {
        if view.selectedRow(inComponent: 0) != selectedRow {
            view.selectRow(selectedRow, inComponent: 0, animated: true)
        }
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: SizeablePicker

        //init(_:)
        init(_ pickerView: SizeablePicker) {
            self.parent = pickerView
        }

        //numberOfComponents(in:)
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }

        //pickerView(_:numberOfRowsInComponent:)
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            self.parent.data.count
        }

        //pickerView(_:viewForRow:forComponent:reusing:)
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let text = self.parent.formatter(self.parent.data[row])
            let result: UILabel
            if let view = view as? UILabel {
                result = view
            } else {
                result = UILabel()
            }
            result.text = text
            result.font = UIFont.preferredFont(forTextStyle: .title3)
            result.textAlignment = .center
            result.textColor = UIColor(self.parent.colorer(self.parent.data[row]))
            result.accessibilityHint = text
            return result
        }
        
        //pickerView(_:didSelectRow:inComponent:)
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            self.parent.selectedRow = row
            self.parent.selection.wrappedValue = self.parent.data[row]
        }
    }
}

class UIPickerViewResizeable: UIPickerView {
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}
