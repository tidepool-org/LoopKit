//
//  MockPumpManagerSettingsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
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
                pumpProgressView
                    .openMockPumpSettingsOnLongPress(enabled: true, pumpManager: viewModel.pumpManager, supportedInsulinTypes: supportedInsulinTypes)
                Divider()
                insulinInfo
            }
        }
    }
    
    private var pumpProgressView: some View {
        HStack(alignment: .center, spacing: 16) {
            pumpImage
            expirationArea
                .offset(y: -3)
        }
    }
    
    private var pumpImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(frameworkColor: "LightGrey")!)
                .frame(width: 77, height: 76)
            Image(frameworkImage: "Pump Simulator")
                .resizable()
                .aspectRatio(contentMode: ContentMode.fit)
                .frame(maxHeight: 70)
                .frame(width: 70)
        }
    }
    
    private var expirationArea: some View {
        VStack(alignment: .leading) {
            expirationText
                .offset(y: 4)
            expirationTime
                .offset(y: 10)
            progressBar
        }
    }
    
    private var expirationText: some View {
        Text("Pump expires in ")
            .font(.system(size: 15, weight: .medium, design: .default))
            .foregroundColor(.secondary)
    }
    
    private var expirationTime: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("2")
                .font(.system(size: 24, weight: .heavy, design: .default))
            Text("days")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .offset(x: -3)
        }
    }
    
    private var progressBar: some View {
        ProgressView(progress: viewModel.pumpExpirationPercentComplete)
            .foregroundColor(insulinTintColor)
    }
    
    var insulinInfo: some View {
        InsulinStatusView(viewModel: viewModel)
            .environment(\.guidanceColors, guidanceColors)
            .environment(\.insulinTintColor, insulinTintColor)
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
                    if viewModel.transitioningSuspendResumeInsulinDelivery {
                        ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    }
                }
            }
            .disabled(viewModel.transitioningSuspendResumeInsulinDelivery)
            if viewModel.isDeliverySuspended {
                LabeledValueView(label: LocalizedString("Suspended At", comment: "Label for suspended at field"),
                                 value: viewModel.suspendedAtString)
            }
        }
    }
    
    private func suspendResumeTapped() {
        if viewModel.isDeliverySuspended {
            viewModel.resumeDelivery() { error in
                if let error = error {
                    self.presentedAlert = .resumeInsulinDeliveryError(error)
                }
            }
        } else {
            viewModel.suspendDelivery() { error in
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
    
    @Published var isDeliverySuspended: Bool {
        didSet {
            transitioningSuspendResumeInsulinDelivery = false
            basalDeliveryState = pumpManager.status.basalDeliveryState
        }
    }
    
    @Published var transitioningSuspendResumeInsulinDelivery = false
    
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
    
    private var pumpPairedInterval: TimeInterval { pumpExpirationRemaing - pumpLifeTime
    }
    
    var lastPumpPairedDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(pumpPairedInterval))
    }

    private let pumpExpirationRemaing = TimeInterval(days: 2.0)
    private let pumpLifeTime = TimeInterval(days: 3.0)
    var pumpExpirationPercentComplete: Double {
        (pumpLifeTime - pumpExpirationRemaing) / pumpLifeTime
    }

    var pumpExpirationDateTimeString: String {
        Self.dateTimeFormatter.string(from: Date().addingTimeInterval(pumpExpirationRemaing))
    }
    
    var pumpTimeString: String {
        Self.shortTimeFormatter.string(from: Date())
    }
    
    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? {
        didSet {
            setSuspenededAtString()
        }
    }

    @Published var basalDeliveryRate: Double?

    @Published var presentDeliveryWarning: Bool?
    
    var isScheduledBasal: Bool {
        switch basalDeliveryState {
        case .active, .initiatingTempBasal:
            return true
        case .tempBasal, .cancelingTempBasal, .suspending, .suspended, .resuming, .none:
            return false
        }
    }
    
    var isTempBasal: Bool {
        switch basalDeliveryState {
        case .tempBasal, .cancelingTempBasal:
            return true
        case .active, .initiatingTempBasal, .suspending, .suspended, .resuming, .none:
            return false
        }
    }
    
    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        
        isDeliverySuspended = pumpManager.status.basalDeliveryState?.isSuspended == true
        basalDeliveryState = pumpManager.status.basalDeliveryState
        basalDeliveryRate = pumpManager.state.basalDeliveryRate(at: Date())
        setSuspenededAtString()
        
        pumpManager.addStateObserver(self, queue: .main)
    }
    
    private func setSuspenededAtString() {
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
        transitioningSuspendResumeInsulinDelivery = true
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
        transitioningSuspendResumeInsulinDelivery = true
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
        guard !transitioningSuspendResumeInsulinDelivery else { return }
        basalDeliveryRate = state.basalDeliveryRate(at: Date())
        basalDeliveryState = manager.status.basalDeliveryState
    }
    
    func mockPumpManager(_ manager: MockKit.MockPumpManager, didUpdate status: LoopKit.PumpManagerStatus, oldStatus: LoopKit.PumpManagerStatus) {
        guard !transitioningSuspendResumeInsulinDelivery else { return }
        basalDeliveryRate = manager.state.basalDeliveryRate(at: Date())
        basalDeliveryState = status.basalDeliveryState
    }
}
 
extension MockPumpManagerState {
    func basalDeliveryRate(at now: Date) -> Double? {
        switch suspendState {
        case .resumed:
            if let tempBasal = unfinalizedTempBasal, !tempBasal.isFinished(at: now) {
                return tempBasal.rate
            } else {
                return basalRateSchedule?.value(at: now)
            }
        case .suspended:
            return nil
        }
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
