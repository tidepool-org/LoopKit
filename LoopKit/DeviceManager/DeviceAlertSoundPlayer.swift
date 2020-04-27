//
//  DeviceAlertSoundPlayer.swift
//  Loop
//
//  Created by Rick Pasetto on 4/27/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

#if os(watchOS)
import WatchKit
#else
import AudioToolbox
#endif
import AVFoundation
import os.log

public protocol DeviceAlertSoundPlayer {
    func vibrate()
    func play(url: URL)
}

public class DeviceAVSoundPlayer: DeviceAlertSoundPlayer {
    private var soundEffect: AVAudioPlayer?
    private let log = OSLog(category: "DeviceAVSoundPlayer")
    private let baseURL: URL?

    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }
    
    enum Error: Swift.Error {
        case playFailed
    }
    
    public func vibrate() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #else
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        #endif
    }
    
    public func play(url: URL) {
        DispatchQueue.main.async {
            do {
                // The AVAudioPlayer has to remain around until the sound completes playing.  A cleaner way might be
                // to wait until that completes, then delete it, but seems overkill.
                let soundEffect = try AVAudioPlayer(contentsOf: url)
                self.soundEffect = soundEffect
                if !soundEffect.play() {
                    self.log.error("couldn't play sound %@", url.absoluteString)
                }
            } catch {
                self.log.error("couldn't play sound %@: %@", url.absoluteString, String(describing: error))
            }
        }
    }
}

public extension DeviceAVSoundPlayer {
    
    func playAlertSound(named name: DeviceAlert.SoundName) {
        switch name {
        case .silence:
            // noop
            break
        case .vibrate:
            vibrate()
        default:
            if let baseURL = baseURL {
                self.play(url: baseURL.appendingPathComponent(name))
            } else {
                log.error("No base URL, could not play %@", name)
            }
        }
    }
}
