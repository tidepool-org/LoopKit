//
//  InsulinStatusView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

struct InsulinStatusView: View {
    @Environment(\.guidanceColors) var guidanceColors
    @Environment(\.insulinTintColor) var insulinTintColor

    @ObservedObject var viewModel: MockPumpManagerSettingsViewModel

    private let subViewSpacing: CGFloat = 21

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            deliveryStatus
                .fixedSize(horizontal: true, vertical: true)
            Spacer()
            Divider()
                .frame(height: dividerHeight)
                .offset(y:3)
            Spacer()
//            reservoirStatus
//                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var dividerHeight: CGFloat {
        guard inNoDelivery == false else {
            return 65 + subViewSpacing-10
        }

        return 65 + subViewSpacing
    }

    let basalRateFormatter = QuantityFormatter()

    private var inNoDelivery: Bool {
        !viewModel.isDeliverySuspended && viewModel.basalDeliveryRate == nil
    }

    private var deliveryStatusSpacing: CGFloat {
        return subViewSpacing
    }

    var deliveryStatus: some View {
        VStack(alignment: .leading, spacing: deliveryStatusSpacing) {
            Text(deliverySectionTitle)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.isDeliverySuspended {
                insulinSuspended
            } else if let basalRate = viewModel.basalDeliveryRate {
                basalRateView(basalRate)
            } else {
                noDelivery
            }
        }
    }

    var insulinSuspended: some View {
        HStack(alignment: .center, spacing: 2) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 34))
                .fixedSize()
                .foregroundColor(guidanceColors.warning)
            Text("Insulin\nSuspended")
                .font(.system(size: 14, weight: .heavy, design: .default))
                .lineSpacing(0.01)
                .fixedSize()
        }
    }

    private func basalRateView(_ basalRate: Double) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    let unit = HKUnit.internationalUnitsPerHour
                    let quantity = HKQuantity(unit: unit, doubleValue: basalRate)
                    if viewModel.presentDeliveryWarning == true {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(guidanceColors.warning)
                            .font(.system(size: 28))
                            .fixedSize()
                    }
                    Text(basalRateFormatter.string(from: quantity, for: unit, includeUnit: false) ?? "")
                        .font(.system(size: 28))
                        .fontWeight(.heavy)
                        .fixedSize()
                    Text(basalRateFormatter.string(from: unit))
                        .foregroundColor(.secondary)
                }
                Group {
                    if viewModel.isScheduledBasal {
                        Text("Scheduled\(String.nonBreakingSpace)Basal")
                    } else if viewModel.isTempBasal {
                        Text("Temporary\(String.nonBreakingSpace)Basal")
                    }
                }
                .font(.footnote)
                .foregroundColor(.accentColor)
            }
        }
    }

    var noDelivery: some View {
        HStack(alignment: .center, spacing: 2) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 34))
                .fixedSize()
                .foregroundColor(guidanceColors.critical)
            Text("No\nDelivery")
                .font(.system(size: 16, weight: .heavy, design: .default))
                .lineSpacing(0.01)
                .fixedSize()
        }
    }

    var deliverySectionTitle: String {
        LocalizedString("Insulin\(String.nonBreakingSpace)Delivery", comment: "Title of insulin delivery section")
    }

    private var reservoirStatusSpacing: CGFloat {
        subViewSpacing
    }

//    var reservoirStatus: some View {
//        VStack(alignment: .trailing) {
//            VStack(alignment: .leading, spacing: reservoirStatusSpacing) {
//                Text("Insulin\(String.nonBreakingSpace)Remaining")
//                    .foregroundColor(Color(UIColor.secondaryLabel))
//                HStack {
//                    if let pumpStatusHighlight = viewModel.pumpStatusHighlight {
//                        pumpStatusWarningText(pumpStatusHighlight: pumpStatusHighlight)
//                    } else {
//                        reservoirLevelStatus
//                    }
//                }
//            }
//        }
//    }

//    @ViewBuilder
//    func pumpStatusWarningText(pumpStatusHighlight: DeviceStatusHighlight) -> some View {
//        HStack(spacing: 2) {
//            Image(systemName: pumpStatusHighlight.imageName)
//                .font(.system(size: 34))
//                .fixedSize()
//                .foregroundColor(guidanceColors.critical)
//            FixedHeightText(Text(pumpStatusHighlight.localizedMessage).fontWeight(.heavy))
//        }
//    }

//    @ViewBuilder
//    var reservoirLevelStatus: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack(alignment: .lastTextBaseline) {
//                Image(frameworkImage: viewModel.reservoirViewModel.imageName)
//                    .resizable()
//                    .foregroundColor(reservoirColor)
//                    .frame(width: 25, height: 38, alignment: .bottom)
//                HStack(alignment: .firstTextBaseline, spacing: 3) {
//                    Text(viewModel.reservoirLevelString)
//                        .font(.system(size: 28))
//                        .fontWeight(.heavy)
//                        .fixedSize()
//                    let unit = HKUnit.internationalUnit()
//                    Text(basalRateFormatter.string(from: unit))
//                        .foregroundColor(.secondary)
//                }
//            }
//            if viewModel.isEstimatedReservoirLevel {
//                FrameworkLocalizedText("Estimated Reading", comment: "label when reservoire level is estimated")
//                    .font(.footnote)
//                    .foregroundColor(.accentColor)
//            } else {
//                FrameworkLocalizedText("Accurate Reading", comment: "label when reservoire level is estimated")
//                    .font(.footnote)
//                    .foregroundColor(.accentColor)
//            }
//        }
//        .offset(y: -11) // the reservoir image should have tight spacing so move the view up
//        .padding(.bottom, -11)
//    }
//
//    var reservoirColor: Color {
//        switch viewModel.reservoirViewModel.warningColor {
//        case .normal:
//            return insulinTintColor
//        case .warning:
//            return guidanceColors.warning
//        case .error:
//            return guidanceColors.critical
//        case .none:
//            return guidanceColors.acceptable
//        }
//    }
}
