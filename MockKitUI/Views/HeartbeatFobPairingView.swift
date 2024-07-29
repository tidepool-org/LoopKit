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
            Section(header: HStack {
                Text(LocalizedString("Heartbeat Fob Devices", comment: "Header for devices section of HeartbeatFobPairingView"))
                Spacer()
                ProgressView()
            }) {
                ForEach(heartbeatFob.discoveredFobs) { device in
                    HStack {
                        Text(device.displayName)
                        Spacer()

                        if device.isSelected {
                            switch device.peripheralState {
                            case .connected:
                                Image(systemName: "wifi")
                                    .imageScale(.large)
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

    }

}

#Preview {
    HeartbeatFobPairingView(heartbeatFob: HeartbeatFob(fobId: nil))
}
