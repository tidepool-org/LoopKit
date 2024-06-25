//
//  HeartbeatFob.swift
//  MockKit
//
//  Created by Pete Schwamb on 4/5/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import CoreBluetooth
import HealthKit
import os.log
import Combine

public protocol HeartbeatFobDelegate: AnyObject {
    func heartbeatFobTriggeredHeartbeat(_ fob: HeartbeatFob)
    func heartbeatFobIdChanged(name: String)
}

public struct DiscoveredFob: Identifiable {
    public var name: String
    public var isSelected: Bool
    public var isConnected: Bool
    public var id: UUID
}

@MainActor
public final class HeartbeatFob: ObservableObject, BluetoothManagerDelegate {

    @Published var fobId: String?

    @Published public var discoveredFobs: [DiscoveredFob] = []

    @Published var connected: Bool = false

    @Published var scanning: Bool = false

    @Published var connectionError: Error?

    @Published var batteryPercent: UInt16?

    public weak var delegate: HeartbeatFobDelegate?

    /// The date of last connection
    private var lastConnection: Date?

    // MARK: -

    private let log = OSLog(category: "HeartbeatFob")

    private let bluetoothManager = BluetoothManager()

    private let delegateQueue = DispatchQueue(label: "com.loopkit.HeartbeatFob.delegateQueue", qos: .unspecified)

    public func setFobId(_ newId: String) {
        self.fobId = newId
        delegate?.heartbeatFobIdChanged(name: newId)
    }

    nonisolated
    public init(fobId: String?) {
        Task { @MainActor in
            self.fobId = fobId
            bluetoothManager.delegate = self
        }
    }

    public func scanForNewSensor() {
        self.fobId = nil
        bluetoothManager.disconnect()
        bluetoothManager.forgetPeripheral()
        bluetoothManager.scanForPeripheral()
    }

    public func resumeScanning() {
        bluetoothManager.scanForPeripheral()
    }

    public func stopScanning() {
        bluetoothManager.disconnect()
    }

    // MARK: - BluetoothManagerDelegate

    func bluetoothManager(_ manager: BluetoothManager, readied peripheralManager: PeripheralManager) async -> Bool {
        var shouldStopScanning = false;

        if let fobId = fobId, fobId == peripheralManager.peripheral.name {
            shouldStopScanning = true
            connected = true
        }

        return shouldStopScanning
    }

    nonisolated func bluetoothManager(_ manager: BluetoothManager, readyingFailed peripheralManager: PeripheralManager, with error: Error) {
        Task { @MainActor in
            connectionError = error
        }
    }

    nonisolated func peripheralDidDisconnect(_ manager: BluetoothManager, peripheralManager: PeripheralManager, wasRemoteDisconnect: Bool) {
        Task { @MainActor in
            if let sensorID = fobId, sensorID == peripheralManager.peripheral.name {
                connected = false
            }
        }
    }

    func bluetoothManager(_ manager: BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral) async -> Bool {

        guard let name = peripheral.name else {
            log.debug("Not connecting to unnamed peripheral: %{public}@", String(describing: peripheral))
            return false
        }

        let index = discoveredFobs.firstIndex{ $0.id == peripheral.identifier }
        if index == nil {
            let device = DiscoveredFob(name: name, isSelected: name == fobId, isConnected: peripheral.state == .connected, id: peripheral.identifier)
            discoveredFobs.append(device)
        }

        if name.hasPrefix("Heartbeat") {
            return fobId == name
        }

        log.info("Not connecting to peripheral: %{public}@", name)
        return false
    }

    nonisolated func bluetoothManagerScanningStatusDidChange(_ manager: BluetoothManager) {
        Task { @MainActor in
            scanning = manager.isScanning
        }
    }

    nonisolated func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveHeartbeat response: Data) {
        Task { @MainActor in
            self.delegate?.heartbeatFobTriggeredHeartbeat(self)
        }
    }

    nonisolated func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveBatteryLevel response: Data) {
        Task { @MainActor in
            let batteryPercent = response.toBigEndian(UInt16.self)
            self.batteryPercent = batteryPercent
        }
    }

}


// MARK: - Helpers
fileprivate extension PeripheralManager {
    func listenToCharacteristic(_ characteristic: HeartbeatServiceCharacteristicUUID) throws {
        try setNotifyValue(true, for: characteristic)
    }
}
