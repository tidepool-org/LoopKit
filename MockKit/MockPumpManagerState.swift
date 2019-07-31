//
//  MockPumpManagerState.swift
//  MockKit
//
//  Created by Pete Schwamb on 7/31/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public struct MockPumpManagerState {
    public var reservoirUnitsRemaining: Double
    public var tempBasalEnactmentShouldError: Bool
    public var bolusEnactmentShouldError: Bool
    public var deliverySuspensionShouldError: Bool
    public var deliveryResumptionShouldError: Bool
    public var maximumBolus: Double
    public var maximumBasalRatePerHour: Double
    public var suspended: Bool
    public var pumpBatteryChargeRemaining: Double?

    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?

    var finalizedDoses: [UnfinalizedDose]

    public var dosesToStore: [UnfinalizedDose] {
        return  finalizedDoses + [unfinalizedTempBasal, unfinalizedBolus].compactMap {$0}
    }

    public mutating func finalizeFinishedDoses() {
        if let bolus = unfinalizedBolus, bolus.finished {
            finalizedDoses.append(bolus)
            unfinalizedBolus = nil
        }

        if let tempBasal = unfinalizedTempBasal, tempBasal.finished {
            finalizedDoses.append(tempBasal)
            unfinalizedTempBasal = nil
        }
    }
}


extension MockPumpManagerState: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let reservoirUnitsRemaining = rawValue["reservoirUnitsRemaining"] as? Double else {
            return nil
        }

        self.reservoirUnitsRemaining = reservoirUnitsRemaining
        self.suspended = rawValue["suspended"] as? Bool ?? false
        self.tempBasalEnactmentShouldError = rawValue["tempBasalEnactmentShouldError"] as? Bool ?? false
        self.bolusEnactmentShouldError = rawValue["bolusEnactmentShouldError"] as? Bool ?? false
        self.deliverySuspensionShouldError = rawValue["deliverySuspensionShouldError"] as? Bool ?? false
        self.deliveryResumptionShouldError = rawValue["deliveryResumptionShouldError"] as? Bool ?? false
        self.maximumBolus = rawValue["maximumBolus"] as? Double ?? 25.0
        self.maximumBasalRatePerHour = rawValue["maximumBasalRatePerHour"] as? Double ?? 5.0
        self.pumpBatteryChargeRemaining = rawValue["pumpBatteryChargeRemaining"] as? Double ?? nil

        if let rawUnfinalizedBolus = rawValue["unfinalizedBolus"] as? UnfinalizedDose.RawValue
        {
            self.unfinalizedBolus = UnfinalizedDose(rawValue: rawUnfinalizedBolus)
        }

        if let rawUnfinalizedTempBasal = rawValue["unfinalizedTempBasal"] as? UnfinalizedDose.RawValue
        {
            self.unfinalizedTempBasal = UnfinalizedDose(rawValue: rawUnfinalizedTempBasal)
        }

        if let rawFinalizedDoses = rawValue["finalizedDoses"] as? [UnfinalizedDose.RawValue] {
            self.finalizedDoses = rawFinalizedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finalizedDoses = []
        }


    }

    public var rawValue: RawValue {

        var raw: RawValue = [
            "reservoirUnitsRemaining": reservoirUnitsRemaining,
            "suspended": suspended
        ]

        if tempBasalEnactmentShouldError {
            raw["tempBasalEnactmentShouldError"] = true
        }

        if bolusEnactmentShouldError {
            raw["bolusEnactmentShouldError"] = true
        }

        if deliverySuspensionShouldError {
            raw["deliverySuspensionShouldError"] = true
        }

        if deliveryResumptionShouldError {
            raw["deliveryResumptionShouldError"] = true
        }

        raw["finalizedDoses"] = finalizedDoses.map( { $0.rawValue })

        raw["maximumBolus"] = maximumBolus
        raw["maximumBasalRatePerHour"] = maximumBasalRatePerHour

        raw["unfinalizedBolus"] = unfinalizedBolus?.rawValue
        raw["unfinalizedTempBasal"] = unfinalizedTempBasal?.rawValue

        raw["pumpBatteryChargeRemaining"] = pumpBatteryChargeRemaining

        return raw
    }
}

extension MockPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## MockPumpManagerState
        * reservoirUnitsRemaining: \(reservoirUnitsRemaining)
        * tempBasalEnactmentShouldError: \(tempBasalEnactmentShouldError)
        * bolusEnactmentShouldError: \(bolusEnactmentShouldError)
        * deliverySuspensionShouldError: \(deliverySuspensionShouldError)
        * deliveryResumptionShouldError: \(deliveryResumptionShouldError)
        * maximumBolus: \(maximumBolus)
        * maximumBasalRatePerHour: \(maximumBasalRatePerHour)
        * pumpBatteryChargeRemaining: \(String(describing: pumpBatteryChargeRemaining))
        * unfinalizedBolus: \(String(describing: unfinalizedBolus))
        * unfinalizedTempBasal: \(String(describing: unfinalizedTempBasal))
        * finalizedDoses: \(finalizedDoses)
        """
    }
}

