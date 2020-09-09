//
//  FileManager.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public extension FileManager {
    
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    func ensureDirectoryExists(at url: URL, with protectionType: FileProtectionType? = nil) throws {
        if !directoryExists(at: url) {
            try createDirectory(at: url, withIntermediateDirectories: true, attributes: protectionType.map { [FileAttributeKey.protectionKey: $0 ] })
        }
        guard let protectionType = protectionType else {
            return
        }
        // double check protection type
        var attrs = try attributesOfItem(atPath: url.path)
        if attrs[FileAttributeKey.protectionKey] as? FileProtectionType != protectionType {
            attrs[FileAttributeKey.protectionKey] = protectionType
            try setAttributes(attrs, ofItemAtPath: url.path)
        }
    }
 
    func copyIfNewer(from fromURL: URL, to toURL: URL) throws {
        if fileExists(atPath: toURL.path) {
            // If the source file is newer, remove the old one, otherwise skip it.
            let toCreationDate = try toURL.fileCreationDate(self)
            let fromCreationDate = try fromURL.fileCreationDate(self)
            if fromCreationDate > toCreationDate {
                try removeItem(at: toURL)
            } else {
                return
            }
        }
        try copyItem(at: fromURL, to: toURL)
    }
}

// MARK: Extensions

fileprivate extension URL {

    func fileCreationDate(_ fileManager: FileManager) throws -> Date {
        return try fileManager.attributesOfItem(atPath: self.path)[.creationDate] as! Date
    }
}

