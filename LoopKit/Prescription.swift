//
//  Prescription.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public protocol Prescription {
    var datePrescribed: Date { get } // Date prescription was prescribed
    var providerName: String { get } // Name of clinician prescribing
}
