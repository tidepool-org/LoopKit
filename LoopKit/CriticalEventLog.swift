//
//  CriticalEventLog.swift
//  LoopKit
//
//  Created by Darin Krauss on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol EstimatedDurationProgressor {

    /// Has the operation been cancelled?
    var isCancelled: Bool { get }

    /// Some progress was made toward the estimated duration of the operation.
    /// - Parameter: estimatedDuration: The estimated duration completed since the last invocation.
    func didProgress(for estimatedDuration: TimeInterval)
}

public protocol CriticalEventLog {

    /// The name for the critical event log export.
    var exportName: String { get }

    /// Calculate the estimated duration for the critical event log export for the specified date range.
    ///
    /// - Parameters:
    ///   - startDate: The start date for the critical events to export.
    ///   - endDate: The end date for the critical events to export. Optional. If not specified, default to now.
    /// - Returns: An estimated duration, as TimeInterval, or an error.
    func exportEstimatedDuration(startDate: Date, endDate: Date?) -> Result<TimeInterval, Error>

    /// Export the critical event log for the specified date range.
    ///
    /// - Parameters:
    ///   - startDate: The start date for the critical events to export.
    ///   - endDate: The end date for the critical events to export.
    ///   - stream: The output stream to write the critical event log to. Typically writes JSON UTF-8 text.
    ///   - progressor: The estimated duration progress to use to check if cancelled and report progress.
    /// - Returns: Any error that occurs during the export, or nil if successful.
    func export(startDate: Date, endDate: Date, to stream: OutputStream, progressor: EstimatedDurationProgressor) -> Error?
}

public enum CriticalEventLogError: Error {

    /// The export was cancelled either by the user or the OS.
    case cancelled
}

public let criticalEventLogExportMinimumProgressDuration = TimeInterval(0.25)
