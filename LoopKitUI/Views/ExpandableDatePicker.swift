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
    let label: String
    
    public init (for date: Binding<Date>, label: String = "") {
        _date = date
        self.label = label
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                Spacer()
                Text("10/15/2001")
            }
            .padding(.horizontal)
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.dateShouldExpand.toggle()
            }
            
            if dateShouldExpand {
                DatePicker("", selection: $date, displayedComponents: [.date])
                .labelsHidden()
            }
            Spacer()
        }
    }
    
    
}
