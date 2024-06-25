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
                Text(LocalizedString("Devices", comment: "Header for devices section of RileyLinkSetupView"))
                Spacer()
                ProgressView()
            }) {
                ForEach(heartbeatFob.discoveredFobs) { device in
                    HStack {
                        Text(device.name)
                        Spacer()

                        if device.isSelected {
                            if device.isConnected {
                                Image(systemName: "wifi")
                                    .imageScale(.large)
                            } else {
                                Image(systemName: "wifi.slash")
                                    .imageScale(.large)
                                    .foregroundColor(guidanceColors.warning)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        heartbeatFob.setFobId(device.name)
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
