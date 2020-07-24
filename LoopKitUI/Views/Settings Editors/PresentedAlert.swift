//
//  PresentedAlert.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 8/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

enum PresentedAlert {
    case saveConfirmation(AlertContent)
    case saveError(Error)
}

extension PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .saveConfirmation:
            return 0
        case .saveError:
            return 1
        }
    }
}

extension PresentedAlert {
    func alert(okAction action: @escaping () -> Void) -> SwiftUI.Alert {
        switch self {
        case .saveConfirmation(let content):
            return SwiftUI.Alert(
                title: content.title,
                message: content.message,
                primaryButton: .cancel(content.cancel ?? Text("Go Back", comment: "Cancel button text")),
                secondaryButton: .default(content.ok ?? Text("Continue", comment: "Button text to confirm"),
                                          action: action)
            )
        case .saveError(let error):
            return SwiftUI.Alert(
                title: Text("Unable to Save", comment: "Alert title when error occurs while saving"),
                message: Text(error.localizedDescription)
            )
        }
    }
}
 
