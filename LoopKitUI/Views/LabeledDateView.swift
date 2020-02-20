//
//  LabeledDateView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct LabeledDateView: View {
    var label: String
    var date: Date?
    var dateStyle: DateFormatter.Style
    var timeStyle: DateFormatter.Style
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }
    
    private var dateString: String? {
        guard let date = self.date else {
            return nil
        }
        return self.dateFormatter.string(from: date)
    }
    
    public init(label: String, date: Date?, dateStyle: DateFormatter.Style = .short, timeStyle: DateFormatter.Style = .short) {
        self.label = label
        self.date = date
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }
    
    public var body: some View {
        LabeledValueView(label: label,
                         value: dateString)
    }
}

struct LabeledDateView_Previews: PreviewProvider {
    static var previews: some View {
        LabeledDateView(label: "Last Calibration",
                        date: Date())
    }
}
