//
//  RemoteData.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public protocol RemoteData {

    func uploadLoopStatus(insulinOnBoard: InsulinValue?,
                          carbsOnBoard: CarbValue?,
                          predictedGlucose: [GlucoseValue]?,
                          recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)?,
                          recommendedBolus: Double?,
                          lastTempBasal: DoseEntry?,
                          lastReservoirValue: ReservoirValue?,
                          pumpManagerStatus: PumpManagerStatus?,
                          loopError: Error?)

    func upload(pumpStatus: PumpStatus?, deviceName: String?, firmwareVersion: String?)

    func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?)

    func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void)

    func upload(carbEntries entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void)

    func delete(carbEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void)

}
