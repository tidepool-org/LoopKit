//
//  MockPumpManagerSettingsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit

struct MockPumpManagerSettingsView: View {
    fileprivate enum PresentedAlert {
        case resumeInsulinDeliveryError(Error)
        case suspendInsulinDeliveryError(Error)
    }
    
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.insulinTintColor) private var insulinTintColor
    @ObservedObject var viewModel: MockPumpManagerSettingsViewModel
    
    @State private var showSuspendOptions = false
    @State private var presentedAlert: PresentedAlert?
    @State private var transitioningSuspendResumeInsulinDelivery = false
    private var supportedInsulinTypes: [InsulinType]
    
    init(pumpManager: MockPumpManager, supportedInsulinTypes: [InsulinType]) {
        viewModel = MockPumpManagerSettingsViewModel(pumpManager: pumpManager)
        self.supportedInsulinTypes = supportedInsulinTypes
    }
    
    var body: some View {
        List {
            statusSection
            
            activitySection
            
            configurationSection
            
            supportSection
        }
        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(Text("Pump Simulator"), displayMode: .large)
        .alert(item: $presentedAlert, content: alert(for:))
    }
    
    @ViewBuilder
    private var statusSection: some View {
        Section {
            VStack(spacing: 8) {
                progressViews
                    .openMockPumpSettingsOnLongPress(enabled: true, pumpManager: viewModel.pumpManager, supportedInsulinTypes: supportedInsulinTypes)
                insulinInfo
            }
        }
    }
    
    private var progressViews: some View {
        Text("Placeholder for Insulin Status View")
//        LazyVStack(spacing: 10) {
//            ForEach(SoloPumpComponent.allCases, id: \.self) {
//                progressView(for: $0)
//            }
//        }
    }
    
//    @ViewBuilder
//    private func progressView(for component: SoloPumpComponent) -> some View {
//        let viewModel = viewModel.expirationProgressViewModel.viewModel(for: component)
//        if viewModel.isHidden {
//            EmptyView()
//        } else {
//            VStack(spacing: 8) {
//                ComponentExpirationProgressView(viewModel: viewModel)
//                Divider()
//            }
//        }
//    }
    
    var insulinInfo: some View {
        Text("Placeholder for Insulin Info View")
//        InsulinStatusView(viewModel: viewModel.insulinStatusViewModel)
//            .environment(\.guidanceColors, guidanceColors)
//            .environment(\.insulinTintColor, insulinTintColor)
    }
    
    @ViewBuilder
    private var activitySection: some View {
        suspendResumeInsulinSubSection

        deviceDetailsSubSection

        replaceSystemComponentsSubSection
    }
    
    private var suspendResumeInsulinSubSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Activity", comment: "Section header for the activity section"))) {
            Button(action: suspendResumeTapped) {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(viewModel.isDeliverySuspended ? guidanceColors.warning : .accentColor)
                    Text(viewModel.suspendResumeInsulinDeliveryLabel)
                    Spacer()
                    if transitioningSuspendResumeInsulinDelivery {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    }
                }
            }
            .disabled(transitioningSuspendResumeInsulinDelivery)
            if viewModel.isDeliverySuspended {
                LabeledValueView(label: LocalizedString("Suspended At", comment: "Label for suspended at field"),
                                 value: viewModel.suspendedAtString)
            }
        }
    }
    
    private func suspendResumeTapped() {
        transitioningSuspendResumeInsulinDelivery = true
        if viewModel.isDeliverySuspended {
            viewModel.resumeDelivery() { error in
                transitioningSuspendResumeInsulinDelivery = false
                if let error = error {
                    self.presentedAlert = .resumeInsulinDeliveryError(error)
                }
            }
        } else {
            viewModel.suspendDelivery() { error in
                transitioningSuspendResumeInsulinDelivery = false
                if let error = error {
                    self.presentedAlert = .suspendInsulinDeliveryError(error)
                }
            }
        }
    }
    
    private var deviceDetailsSubSection: some View {
        Section {
            LabeledValueView(label: "Pump Paired", value: viewModel.lastPumpPairedDateTimeString)
            
            LabeledValueView(label: "Pump Expires", value: viewModel.pumpExpirationDateTimeString)
            
            NavigationLink(destination: DemoPlaceHolderView()) {
                Text("Device Details")
            }
        }
    }
    
    private var replaceSystemComponentsSubSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView()) {
                Text("Replace Pump")
                    .foregroundColor(.accentColor)
            }
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        notificationSubSection
        
        pumpTimeSubSection
    }
    
    private var notificationSubSection: some View {
        Section(header: SectionHeader(label: "Configuration")) {
            NavigationLink(destination: DemoPlaceHolderView()) {
                Text("Notification Settings")
            }
        }
    }
    
    private var pumpTimeSubSection: some View {
        Section {
            LabeledValueView(label: "Pump Time", value: viewModel.pumpTimeString)
        }
    }
    
    private var supportSection: some View {
        Section(header: SectionHeader(label: "Support")) {
            NavigationLink(destination: DemoPlaceHolderView()) {
                Text("Get help with your pump")
            }
        }
    }
    
    private var doneButton: some View {
        Button(LocalizedString("Done", comment: "Settings done button label"), action: dismiss)
    }
    
    private func alert(for presentedAlert: PresentedAlert) -> SwiftUI.Alert {
        switch presentedAlert {
        case .suspendInsulinDeliveryError(let error):
            return Alert(
                title: Text("Failed to Suspend Insulin Delivery"),
                message: Text(error.localizedDescription)
            )
        case .resumeInsulinDeliveryError(let error):
            return Alert(
                title: Text("Failed to Resume Insulin Delivery"),
                message: Text(error.localizedDescription)
            )
        }
    }
}

class MockPumpManagerSettingsViewModel: ObservableObject {
    let pumpManager: MockPumpManager
    
    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        
        isDeliverySuspended = pumpManager.status.basalDeliveryState?.isSuspended == true
        setSuspenededAtString(basalDeliveryState: pumpManager.status.basalDeliveryState)
        
        pumpManager.addStateObserver(self, queue: .main)
    }
    
    @Published var isDeliverySuspended: Bool {
        didSet {
            setSuspenededAtString(basalDeliveryState: pumpManager.status.basalDeliveryState)
        }
    }
    
    @Published var suspendedAtString: String? = nil
    
    var suspendResumeInsulinDeliveryLabel: String {
        if isDeliverySuspended {
            return "Tap to Resume Insulin Delivery"
        } else {
            return "Suspend Insulin Delivery"
        }
    }
    
    static private let dateTimeFormatter: DateFormatter = {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .short
        timeFormatter.timeStyle = .short
        return timeFormatter
    }()
    
    static private let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let pumpPairedInterval = TimeInterval(days: -1.0)
    
    var lastPumpPairedDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(pumpPairedInterval))
    }

    private let pumpExpirationInterval = TimeInterval(days: 2.0)

    var pumpExpirationDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(pumpExpirationInterval))
    }
    
    var pumpTimeString: String {
        Self.shortTimeFormatter.string(from: Date())
    }
    
    private func setSuspenededAtString(basalDeliveryState: PumpManagerStatus.BasalDeliveryState? = nil) {
        switch basalDeliveryState {
        case .suspended(let suspendedAt):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
            suspendedAtString = formatter.string(from: suspendedAt)
        default:
            suspendedAtString = nil
        }
    }
    
    func resumeDelivery(completion: @escaping (Error?) -> Void) {
        pumpManager.resumeDelivery() { [weak self] error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if error == nil {
                    self?.isDeliverySuspended = false
                }
                completion(error)
            }
        }
    }
    
    func suspendDelivery(completion: @escaping (Error?) -> Void) {
        pumpManager.suspendDelivery() { [weak self] error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if error == nil {
                    self?.isDeliverySuspended = true
                }
                completion(error)
            }
        }
    }
}

extension MockPumpManagerSettingsViewModel: MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate state: MockKit.MockPumpManagerState) {
        // TODO remove if unused
    }
    
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate status: LoopKit.PumpManagerStatus, oldStatus: LoopKit.PumpManagerStatus) {
        // TODO remove if unused
    }
}

extension MockPumpManagerSettingsView.PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .resumeInsulinDeliveryError:
            return 0
        case .suspendInsulinDeliveryError:
            return 1
        }
    }
}

//struct InsulinStatusView: View {
//    @Environment(\.guidanceColors) var guidanceColors
//    @Environment(\.insulinTintColor) var insulinTintColor
//
//    @ObservedObject var viewModel: InsulinStatusViewModel
//
//    private let subViewSpacing: CGFloat = 21
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 0) {
//            deliveryStatus
//                .fixedSize(horizontal: true, vertical: true)
//            Spacer()
//            Divider()
//                .frame(height: dividerHeight)
//                .offset(y:3)
//            Spacer()
//            reservoirStatus
//                .fixedSize(horizontal: true, vertical: true)
//        }
//    }
//
//    private var dividerHeight: CGFloat {
//        guard inNoDelivery == false else {
//            return 65 + subViewSpacing-10
//        }
//
//        return 65 + subViewSpacing
//    }
//
//    let basalRateFormatter = QuantityFormatter()
//
//    private var inNoDelivery: Bool {
//        !viewModel.isInsulinSuspended && viewModel.basalDeliveryRate == nil
//    }
//
//    private var deliveryStatusSpacing: CGFloat {
//        return subViewSpacing
//    }
//
//    var deliveryStatus: some View {
//        VStack(alignment: .leading, spacing: deliveryStatusSpacing) {
//            FixedHeightText(deliverySectionTitle)
//                .foregroundColor(.secondary)
//            if viewModel.isInsulinSuspended {
//                insulinSuspended
//            } else if let basalRate = viewModel.basalDeliveryRate {
//                basalRateView(basalRate)
//            } else {
//                noDelivery
//            }
//        }
//    }
//
//    var insulinSuspended: some View {
//        HStack(alignment: .center, spacing: 2) {
//            Image(systemName: "pause.circle.fill")
//                .font(.system(size: 34))
//                .fixedSize()
//                .foregroundColor(guidanceColors.warning)
//            FrameworkLocalizedText("Insulin\nSuspended", comment: "Text shown in insulin remaining space when no micropump is paired")
//                .font(.system(size: 14, weight: .heavy, design: .default))
//                .lineSpacing(0.01)
//                .fixedSize()
//        }
//    }
//
//    private func basalRateView(_ basalRate: Double) -> some View {
//        HStack(alignment: .center) {
//            VStack(alignment: .leading) {
//                HStack(alignment: .lastTextBaseline, spacing: 3) {
//                    let unit = HKUnit.internationalUnitsPerHour
//                    let quantity = HKQuantity(unit: unit, doubleValue: basalRate)
//                    if viewModel.presentDeliveryWarning == true {
//                        Image(systemName: "exclamationmark.circle.fill")
//                            .foregroundColor(guidanceColors.warning)
//                            .font(.system(size: 28))
//                            .fixedSize()
//                    }
//                    Text(basalRateFormatter.string(from: quantity, for: unit, includeUnit: false) ?? "")
//                        .font(.system(size: 28))
//                        .fontWeight(.heavy)
//                        .fixedSize()
//                    Text(basalRateFormatter.string(from: unit))
//                        .foregroundColor(.secondary)
//                }
//                Group {
//                    if viewModel.isScheduledBasal {
//                        FrameworkLocalizedText("Scheduled\(String.nonBreakingSpace)Basal", comment: "Subtitle of insulin delivery section during scheduled basal")
//                    } else if viewModel.isTempBasal {
//                        FrameworkLocalizedText("Temporary\(String.nonBreakingSpace)Basal", comment: "Subtitle of insulin delivery section during temporary basal")
//                    }
//                }
//                .font(.footnote)
//                .foregroundColor(.accentColor)
//            }
//        }
//    }
//
//    var noDelivery: some View {
//        HStack(alignment: .center, spacing: 2) {
//            Image(systemName: "xmark.circle.fill")
//                .font(.system(size: 34))
//                .fixedSize()
//                .foregroundColor(guidanceColors.critical)
//            FrameworkLocalizedText("No\nDelivery", comment: "Text shown in insulin remaining space when no micropump is paired")
//                .font(.system(size: 16, weight: .heavy, design: .default))
//                .lineSpacing(0.01)
//                .fixedSize()
//        }
//    }
//
//    var deliverySectionTitle: String {
//        LocalizedString("Insulin\(String.nonBreakingSpace)Delivery", comment: "Title of insulin delivery section")
//    }
//
//    private var reservoirStatusSpacing: CGFloat {
//        subViewSpacing
//    }
//
//    var reservoirStatus: some View {
//        VStack(alignment: .trailing) {
//            VStack(alignment: .leading, spacing: reservoirStatusSpacing) {
//                FrameworkLocalizedText("Insulin\(String.nonBreakingSpace)Remaining", comment: "Header for insulin remaining on micropump settings screen")
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
//
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
//
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
//}
//
//class InsulinStatusViewModel: ObservableObject {
//    private weak var statePublisher: SoloPumpManagerStatePublisher?
//
//    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState?
//
//    @Published var basalDeliveryRate: Double?
//
//    @Published var presentDeliveryWarning: Bool?
//
//    var isScheduledBasal: Bool {
//        switch basalDeliveryState {
//        case .active, .initiatingTempBasal:
//            return true
//        case .tempBasal, .cancelingTempBasal, .suspending, .suspended, .resuming, .none:
//            return false
//        }
//    }
//
//    var isTempBasal: Bool {
//        switch basalDeliveryState {
//        case .tempBasal, .cancelingTempBasal:
//            return true
//        case .active, .initiatingTempBasal, .suspending, .suspended, .resuming, .none:
//            return false
//        }
//    }
//
//    var isInsulinSuspended: Bool {
//        switch basalDeliveryState {
//        case .suspended:
//            return true
//        default:
//            return false
//        }
//    }
//
//    @Published var reservoirViewModel: SoloReservoirHUDViewModel
//
//    @Published private var statusHighlight: DeviceStatusHighlight?
//    @Published private var lastCommsDate: Date?
//    var isSignalLost: Bool {
//        SoloPumpManager.isSignalLost(lastCommsDate: lastCommsDate, asOf: now)
//    }
//    var pumpStatusHighlight: DeviceStatusHighlight? {
//        let shouldShowStatusHighlight = !isInsulinSuspended ||
//            // This avoids a race condition where we detect signal loss timeout but pumpStatusHighlight has not yet updated.
//            isSignalLost && statusHighlight is SignalLossPumpStatusHighlight
//
//        return shouldShowStatusHighlight ? statusHighlight : nil
//    }
//
//    private let now: () -> Date
//    private var internalBasalDeliveryState: PumpManagerStatus.BasalDeliveryState?
//
//    init(statePublisher: SoloPumpManagerStatePublisher, now: @autoclosure @escaping () -> Date = Date()) {
//        self.statePublisher = statePublisher
//        self.reservoirViewModel = SoloReservoirHUDViewModel(userThreshold: Double(statePublisher.state.lowReservoirWarningThresholdInUnits))
//        self.now = now
//        if let statusPublisher = statePublisher as? PumpManagerStatusPublisher {
//            self.basalDeliveryState = statusPublisher.status.basalDeliveryState
//            update(with: statusPublisher.status, pumpStatusHighlight: statusPublisher.pumpStatusHighlight)
//            statusPublisher.addStatusObserver(self, queue: .main)
//        }
//        statePublisher.addPumpManagerStateObserver(self, queue: .main)
//        update(with: statePublisher.state)
//    }
//
//    func detach() {
//        statePublisher?.removePumpManagerStateObserver(self)
//        if let statusPublisher = statePublisher as? PumpManagerStatusPublisher {
//            statusPublisher.removeStatusObserver(self)
//        }
//        statePublisher = nil
//    }
//
//    deinit {
//        detach()
//    }
//
//    static let reservoirVolumeFormatter: QuantityFormatter = {
//        let formatter = QuantityFormatter(for: .internationalUnit())
//        formatter.numberFormatter.maximumFractionDigits = 2
//        formatter.avoidLineBreaking = true
//        return formatter
//    }()
//
//    var reservoirLevelString: String {
//        let accuracyLimit = SoloPump.reservoirAccuracyLimit
//        let formatter = Self.reservoirVolumeFormatter
//        let fallbackString = ""
//        switch reservoirViewModel.reservoirLevel {
//        case let x? where x >= accuracyLimit:
//            // display reservoir level to the nearest 10U when above the accuracy level
//            let roundedReservoirLevel = x.rounded(to: 10)
//            let quantity = HKQuantity(unit: .internationalUnit(), doubleValue: roundedReservoirLevel)
//            return formatter.string(from: quantity, for: .internationalUnit(), includeUnit: false) ?? fallbackString
//        case .some(let value):
//            let quantity = HKQuantity(unit: .internationalUnit(), doubleValue: value)
//            return formatter.string(from: quantity, for: .internationalUnit(), includeUnit: false) ?? fallbackString
//        default:
//            return fallbackString
//        }
//    }
//
//    var isEstimatedReservoirLevel: Bool {
//        guard let reservoirLevel = reservoirViewModel.reservoirLevel else { return false }
//        return reservoirLevel >= SoloPump.reservoirAccuracyLimit
//    }
//
//    private func update(with state: SoloPumpManagerState) {
//        // ignore updates while suspending
//        guard internalBasalDeliveryState != .suspending else {
//            return
//        }
//        // ... but still update `basalDeliveryRate` while resuming otherwise the UI flashes "No Insulin" briefly
//        basalDeliveryRate = state.basalDeliveryRate(at: now())
//        // ignore updates while resuming
//        guard internalBasalDeliveryState != .resuming else {
//            return
//        }
//        reservoirViewModel = SoloReservoirHUDViewModel(userThreshold: Double(state.lowReservoirWarningThresholdInUnits), reservoirLevel: state.pumpState.deviceInformation?.reservoirLevel)
//        lastCommsDate = state.pumpState.lastCommsDate
//    }
//
//    private func update(with status: PumpManagerStatus, pumpStatusHighlight: DeviceStatusHighlight?) {
//        internalBasalDeliveryState = status.basalDeliveryState
//        guard status.basalDeliveryState != .suspending,
//              status.basalDeliveryState != .resuming else {
//                  return
//              }
//        if status.basalDeliveryState != basalDeliveryState {
//            basalDeliveryState = status.basalDeliveryState
//        }
//        self.statusHighlight = pumpStatusHighlight
//    }
//}
//
//extension InsulinStatusViewModel: SoloPumpManagerStateObserver {
//    func pumpManagerDidUpdateState(_ pumpManager: SoloPumpManager, _ state: SoloPumpManagerState) {
//        update(with: state)
//    }
//}
//
//extension InsulinStatusViewModel: PumpManagerStatusObserver {
//    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
//        update(with: status, pumpStatusHighlight: (pumpManager as? PumpStatusIndicator)?.pumpStatusHighlight)
//    }
//}
//
//extension SoloReservoirHUDViewModel {
//
//    var imageName: String {
//        switch imageType {
//        case .full:
//            return "solo_reservoir_full"
//        case .open:
//            return "solo_reservoir"
//        }
//    }
//}
//
//public protocol PumpManagerStatusPublisher: AnyObject, PumpStatusIndicator {
//    var status: PumpManagerStatus { get }
//    var pumpStatusHighlight: DeviceStatusHighlight? { get }
//    func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue)
//    func removeStatusObserver(_ observer: PumpManagerStatusObserver)
//}
//
//extension SoloPumpManager: PumpManagerStatusPublisher { }
//
//extension SoloPumpManagerState {
//
//    func basalDeliveryRate(at now: Date) -> Double? {
//        switch suspendState {
//        case .resumed:
//            if let tempBasal = unfinalizedTempBasal, !tempBasal.isFinished(at: now) {
//                return tempBasal.rate
//            } else {
//                return basalRateSchedule.value(at: now)
//            }
//        case .suspended, .none:
//            return nil
//        }
//    }
//}
//
//extension String {
//    static let nonBreakingSpace = "\u{00a0}"
//}


struct MockPumpManagerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockPumpManagerSettingsView(pumpManager: MockPumpManager(), supportedInsulinTypes: [])
    }
}
