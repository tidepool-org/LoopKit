//
//  SuspendThresholdEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


extension Guardrail where Value == HKQuantity {
    static let suspendThreshold = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter)
}

public struct SuspendThresholdEditor: View {
    var buttonText: Text
    var initialValue: HKQuantity?
    var unit: HKUnit
    var maxValue: HKQuantity?
    var save: (_ suspendThreshold: HKQuantity) -> Void
    let mode: PresentationMode

    @State private var userDidTap: Bool = false
    @Binding var userHasEdited: Bool
    @State var value: HKQuantity
    @State var isEditing = false
    @State var showingConfirmationAlert = false
    @Environment(\.dismiss) var dismiss

    let guardrail = Guardrail.suspendThreshold

    public init(
        buttonText: Text = Text("Save", comment: "The button text for saving on a configuration page"),
        value: HKQuantity?,
        unit: HKUnit,
        maxValue: HKQuantity?,
        onSave save: @escaping (_ suspendThreshold: HKQuantity) -> Void,
        mode: PresentationMode = .modal,
        userHasEdited: Binding<Bool> = Binding.constant(false)
    ) {
        self.buttonText = buttonText
        self._value = State(initialValue: value ?? Self.defaultValue(for: unit))
        self.initialValue = value
        self.unit = unit
        self.maxValue = maxValue
        self.save = save
        self.mode = mode
        self._userHasEdited = userHasEdited
    }

    private static func defaultValue(for unit: HKUnit) -> HKQuantity {
        switch unit {
        case .milligramsPerDeciliter:
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
        case .millimolesPerLiter:
            return HKQuantity(unit: .millimolesPerLiter, doubleValue: 4.5)
        default:
            fatalError("Unsupported glucose unit \(unit)")
        }
    }

    public var body: some View {
        ConfigurationPage(
            title: Text("Suspend Threshold", comment: "Title for suspend threshold configuration page"),
            actionButtonTitle: buttonText,
            actionButtonState: saveButtonState,
            cards: {
                // TODO: Remove conditional when Swift 5.3 ships
                // https://bugs.swift.org/browse/SR-11628
                if true {
                    Card {
                        SettingDescription(text: description, informationalContent: { TherapySetting.suspendThreshold.helpScreen() })
                        ExpandableSetting(
                            isEditing: $isEditing,
                            valueContent: {
                                GuardrailConstrainedQuantityView(
                                    value: value,
                                    unit: unit,
                                    guardrail: guardrail,
                                    isEditing: isEditing,
                                    // Workaround for strange animation behavior on appearance
                                    forceDisableAnimations: true
                                )
                            },
                            expandedContent: {
                                GlucoseValuePicker(
                                    value: self.$value.animation(),
                                    unit: self.unit,
                                    guardrail: self.guardrail,
                                    bounds: self.guardrail.absoluteBounds.lowerBound...(self.maxValue ?? self.guardrail.absoluteBounds.upperBound)
                                )
                                // Prevent the picker from expanding the card's width on small devices
                                .frame(maxWidth: UIScreen.main.bounds.width - 48)
                                .clipped()
                            }
                        )
                    }
                }
            },
            actionAreaContent: {
                instructionalContentIfNecessary
                if warningThreshold != nil && (userDidTap || mode == .modal) {
                    SuspendThresholdGuardrailWarning(safetyClassificationThreshold: warningThreshold!)
                }
            },
            action: {
                if self.warningThreshold == nil {
                    self.saveAndDismiss()
                } else {
                    self.showingConfirmationAlert = true
                }
            }
        )
        .alert(isPresented: $showingConfirmationAlert, content: confirmationAlert)
        .onTapGesture {
            self.userDidTap = true
            self.userHasEdited = self.initialValue != self.value
        }
    }

    var description: Text {
        Text("When your glucose is predicted to go below this value, the app will recommend a basal rate of 0 U/h and will not recommend a bolus.", comment: "Suspend threshold description")
    }
    
    private var instructionalContentIfNecessary: some View {
        return Group {
            if mode == .flow && !userDidTap {
                instructionalContent
            }
        }
    }

    private var instructionalContent: some View {
        HStack { // to align with guardrail warning, if present
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedString("You can edit a setting by tapping into any line item.", comment: "Description of how to edit setting"))
                Text(LocalizedString("You can add different correction ranges for different times of day by using the [+].", comment: "Description of how to add a configuration range"))
            }
            .foregroundColor(.accentColor)
            .font(.subheadline)
            Spacer()
        }
    }

    private var saveButtonState: ConfigurationPageActionButtonState {
        initialValue == nil || value != initialValue! || mode == .flow ? .enabled : .disabled
    }

    private var warningThreshold: SafetyClassification.Threshold? {
        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text("Save Suspend Threshold?", comment: "Alert title for confirming a suspend threshold outside the recommended range"),
            message: Text("The suspend threshold you have entered is outside of what Tidepool generally recommends.", comment: "Alert message for confirming a suspend threshold outside the recommended range"),
            primaryButton: .cancel(Text("Go Back")),
            secondaryButton: .default(
                Text("Continue"),
                action: saveAndDismiss
            )
        )
    }

    private func saveAndDismiss() {
        save(value)
        if mode == .modal {
            dismiss()
        }
    }
}

struct SuspendThresholdGuardrailWarning: View {
    var safetyClassificationThreshold: SafetyClassification.Threshold

    var body: some View {
        GuardrailWarning(title: title, threshold: safetyClassificationThreshold)
    }

    private var title: Text {
        switch safetyClassificationThreshold {
        case .minimum, .belowRecommended:
            return Text("Low Suspend Threshold", comment: "Title text for the low suspend threshold warning")
        case .aboveRecommended, .maximum:
            return Text("High Suspend Threshold", comment: "Title text for the high suspend threshold warning")
        }
    }
}

struct SuspendThresholdView_Previews: PreviewProvider {
    static var previews: some View {
        SuspendThresholdEditor(value: nil, unit: .milligramsPerDeciliter, maxValue: nil, onSave: { _ in })
    }
}
