//
//  MockCGMManagerSettingsView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit

struct MockCGMManagerSettingsView: View {
    fileprivate enum PresentedAlert {
        case resumeInsulinDeliveryError(Error)
        case suspendInsulinDeliveryError(Error)
    }
    
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.glucoseTintColor) private var glucoseTintColor
    @ObservedObject var viewModel: MockCGMManagerSettingsViewModel
    
    @State private var showSuspendOptions = false
    @State private var presentedAlert: PresentedAlert?
    private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    private let appName: String
    
    init(cgmManager: MockCGMManager, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, appName: String) {
        viewModel = MockCGMManagerSettingsViewModel(cgmManager: cgmManager, displayGlucoseUnitObservable: displayGlucoseUnitObservable)
        self.displayGlucoseUnitObservable = displayGlucoseUnitObservable
        self.appName = appName
    }
    
    var body: some View {
        List {
            statusSection
            
            sensorSection
            
            lastReadingSection
            
            supportSection
        }
        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(Text("CGM Simulator"), displayMode: .large)
        .alert(item: $presentedAlert, content: alert(for:))
    }
    
    @ViewBuilder
    private var statusSection: some View {
        statusCardSubSection
        
        notificationSubSection
    }
    
    @ViewBuilder
    private var statusCardSubSection: some View {
        Section {
            VStack(spacing: 8) {
                sensorProgressView
                    .openMockCGMSettingsOnLongPress(enabled: true, cgmManager: viewModel.cgmManager, displayGlucoseUnitObservable: displayGlucoseUnitObservable)
                Divider()
                lastReadingInfo
            }
        }
    }
        
    private var sensorProgressView: some View {
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
            Image(frameworkImage: "CGM Simulator")
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
        Text("Sensor expires in ")
            .font(.system(size: 15, weight: .medium, design: .default))
            .foregroundColor(.secondary)
    }
    
    private var expirationTime: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("5")
                .font(.system(size: 24, weight: .heavy, design: .default))
            Text("days")
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .offset(x: -3)
        }
    }
    
    private var progressBar: some View {
        ProgressView(progress: viewModel.sensorExpirationPercentComplete)
            .accentColor(glucoseTintColor)
    }
    
    var lastReadingInfo: some View {
        Text("Placeholder for last reading info")
    }
    
    private var notificationSubSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Notification Settings")
            }
        }
    }
    
    @ViewBuilder
    private var sensorSection: some View {
        deviceDetailsSubSection

        stopSensorSubSection
    }
    
    @ViewBuilder
    private var deviceDetailsSubSection: some View {
        Section(header: SectionHeader(label: "Sensor")) {
            LabeledValueView(label: "Insertion Time", value: viewModel.sensorInsertionDateTimeString)
            
            LabeledValueView(label: "Sensor Expires", value: viewModel.sensorExpirationDateTimeString)
        }
    }
    
    private var stopSensorSubSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                Text("Stop Sensor")
                    .foregroundColor(guidanceColors.critical)
            }
        }
    }

    @ViewBuilder
    private var lastReadingSection: some View {
        Section(header: SectionHeader(label: "Last Reading")) {
            LabeledValueView(label: "Glucose", value: nil)
            LabeledValueView(label: "Time", value: nil)
            LabeledValueView(label: "Trend", value: nil)
        }
    }
    
    private var supportSection: some View {
        Section(header: SectionHeader(label: "Support")) {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
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

extension MockCGMManagerSettingsView.PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .resumeInsulinDeliveryError:
            return 0
        case .suspendInsulinDeliveryError:
            return 1
        }
    }
}

struct MockCGMManagerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MockCGMManagerSettingsView(cgmManager: MockCGMManager(), displayGlucoseUnitObservable: DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter), appName: "Loop")
    }
}

