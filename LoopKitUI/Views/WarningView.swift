//
//  WarningView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public enum WarningSeverity: Int, Comparable {
    case `default`
    case critical

    public static func < (lhs: WarningSeverity, rhs: WarningSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct WarningView: View {
    var title: Text
    var caption: Text
    var severity: WarningSeverity
//    private let defaultColor: Color
//    private let criticalColor: Color

    public init(title: Text,
                caption: Text,
                severity: WarningSeverity = .default
//                defaultColor: Color,
//                criticalColor: Color
    ) {
        self.title = title
        self.caption = caption
        self.severity = severity
//        self.defaultColor = defaultColor
//        self.criticalColor = criticalColor
    }

    public var body: some View {
        HStack {
              VStack(alignment: .leading) {
                  HStack(alignment: .firstTextBaseline) {
                      Image(systemName: "exclamationmark.triangle.fill")
                          .foregroundColor(warningColor)

                      title
                          .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                          .bold()
                          .fixedSize()
                          .animation(nil)
                  }

                  caption
                      .font(.callout)
                      .foregroundColor(Color(.secondaryLabel))
                      .fixedSize(horizontal: false, vertical: true)
                      .animation(nil)
              }

              Spacer()
          }
    }

    private var warningColor: Color {
        switch severity {
        case .default:
            return .orange// .warning
        case .critical:
            return .red// .critical
        }
    }
}
