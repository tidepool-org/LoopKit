//
//  HeartbeatFobPairingView.swift
//  MockKit
//
//  Created by Pete Schwamb on 4/9/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import MockKit

struct HeartbeatFobPairingView: View {

    @ObservedObject var heartbeatFob: HeartbeatFob
    @Environment(\.guidanceColors) private var guidanceColors

    var body: some View {
        List {
            Image(frameworkImage: "Heartbeat Fob")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .frame(maxWidth: .infinity,maxHeight: .infinity)
            Section(header: HStack {
                Text(LocalizedString("Scanning", comment: "Header for devices section of HeartbeatFobPairingView"))
                ProgressView()
                    .padding(.leading, 5)
            }) {
                ForEach(heartbeatFob.discoveredFobs) { device in
                    HStack {
                        Text(device.displayName)
                        Spacer()

                        if device.isSelected {
                            switch device.peripheralState {
                            case .connected:
                                if #available(iOSApplicationExtension 17.0, *) {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .imageScale(.large)
                                        .symbolRenderingMode(.multicolor)
                                        .symbolEffect(.variableColor, options: .speed(1), isActive: true)
                                } else {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .imageScale(.large)
                                        .symbolRenderingMode(.multicolor)
                                }
                            default:
                                ProgressView()
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        heartbeatFob.setFobId(device.id)
                    }
                }
            }
            .onAppear {
                heartbeatFob.resumeScanning()
            }
            .onDisappear {
                heartbeatFob.stopScanning()
            }
        }
        .navigationTitle(LocalizedString("Heartbeat Pairing", comment: "Navigation title for Heartbeat Fob Pairing View"))

    }

}

#Preview {
    HeartbeatFobPairingView(heartbeatFob: HeartbeatFob(fobId: nil))
}
