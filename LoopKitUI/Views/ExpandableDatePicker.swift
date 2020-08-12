//
//  ExpandableDatePicker.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ExpandableDatePicker: View {
    @State var dateShouldExpand = false
    @Binding var date: Date
    
    public init (with date: Binding<Date>) {
        _date = date
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(dateFormatter.string(from: date))
                Spacer()
            }
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.dateShouldExpand.toggle()
            }
            
            if dateShouldExpand {
                DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
