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
    private let log = OSLog(category: "DeviceAVSoundPlayer")
    private let baseURL: URL?
    private var delegate: Delegate!
    private var players = [AVAudioPlayer]()
    
    @objc class Delegate: NSObject, AVAudioPlayerDelegate {
        weak var parent: DeviceAVSoundPlayer?
        init(parent: DeviceAVSoundPlayer) { self.parent = parent }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            parent?.players.removeAll { $0 == player }
        }
    }
    
    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
        self.delegate = Delegate(parent: self)
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
                soundEffect.delegate = self.delegate
                self.players.append(soundEffect)
                if !soundEffect.play() {
                    self.log.default("couldn't play sound (app may be in the background): %@", url.absoluteString)
                }
            } catch {
                self.log.error("couldn't play sound %@: %@", url.absoluteString, String(describing: error))
            }
        }
    }
}

public extension DeviceAVSoundPlayer {

    func playAlert(sound: DeviceAlert.Sound) {
        switch sound {
        case .silence:
            // noop
            break
        case .vibrate:
            vibrate()
        default:
            if let baseURL = baseURL {
                if let name = sound.filename {
                    self.play(url: baseURL.appendingPathComponent(name))
                } else {
                    log.default("No file to play for %@", "\(sound)")
                }
            } else {
                log.error("No base URL, could not play %@", sound.filename ?? "")
            }
        }
    }
}
