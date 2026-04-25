import AppKit
import CocaineCore

final class SystemSoundPlayer: LidSoundPlaying {
    func play(named soundName: String) {
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}
