import Foundation
import AVFoundation
import AudioToolbox
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Sound Service
// Plays sound effects for email actions using system sounds.
// Uses AudioServicesPlaySystemSound for lightweight haptic + audio feedback.

class SoundService {
    static let shared = SoundService()

    private var audioPlayer: AVAudioPlayer?

    // MARK: - System Sound IDs
    // iOS built-in system sounds for crisp, native feel

    /// Plays a send-email sound effect using custom mp3.
    func playSendSound() {
        playBundleSound(named: "email_sent", ext: "mp3")
        // Light haptic feedback
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    /// Plays a receive-notification sound using custom mp3.
    func playReceiveSound() {
        playBundleSound(named: "new_mail", ext: "mp3")
        // Soft haptic
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Plays an mp3 file from the app bundle using AVAudioPlayer.
    private func playBundleSound(named name: String, ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("[SoundService] Sound file \(name).\(ext) not found in bundle")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("[SoundService] Failed to play \(name).\(ext): \(error.localizedDescription)")
        }
    }

    /// Plays a delete/archive sound.
    func playDeleteSound() {
        // System sound 1155 = short "tock" for delete
        AudioServicesPlaySystemSound(1155)
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Plays a star/favorite toggle sound.
    func playStarSound() {
        // System sound 1057 = short pop
        AudioServicesPlaySystemSound(1057)
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        #endif
    }

    /// Plays a refresh/sync sound.
    func playRefreshSound() {
        // System sound 1054 = subtle tick
        AudioServicesPlaySystemSound(1054)
    }

    /// Plays a generic tap feedback.
    func playTapFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Plays a success haptic.
    func playSuccessFeedback() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Plays an error haptic.
    func playErrorFeedback() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
}
