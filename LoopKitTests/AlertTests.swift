//
//  AlertTests.swift
//  LoopKitTests
//
//  Created by Rick Pasetto on 5/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class AlertTests: XCTestCase {
    let identifier = Alert.Identifier(managerIdentifier: "managerIdentifier1", alertIdentifier: "alertIdentifier1")
    let foregroundContent = Alert.Content(title: "title1", body: "body1", acknowledgeActionButtonLabel: "acknowledgeActionButtonLabel1", isCritical: false)
    let backgroundContent = Alert.Content(title: "title2", body: "body2", acknowledgeActionButtonLabel: "acknowledgeActionButtonLabel2", isCritical: false)

    func testIdentifierValue() {
        XCTAssertEqual("managerIdentifier1.alertIdentifier1", identifier.value)
    }
    
    func testAlertSoundFilename() {
        XCTAssertNil(Alert.Sound.silence.filename)
        XCTAssertNil(Alert.Sound.vibrate.filename)
        XCTAssertEqual("foo", Alert.Sound.sound(name: "foo").filename)
    }
}
