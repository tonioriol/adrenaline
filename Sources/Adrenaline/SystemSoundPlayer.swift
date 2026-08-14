import AppKit
import AdrenalineCore
import AudioToolbox

final class SystemSoundPlayer: LidSoundPlaying {
    private let preferences: PreferencesProviding

    init(preferences: PreferencesProviding) {
        self.preferences = preferences
    }

    func play(named soundName: String) {
        guard let sound = NSSound(named: NSSound.Name(soundName)) else { return }

        let savedVolume: Float32?
        let savedMute: Bool?

        if preferences.overrideSystemVolumeForLidEventSounds {
            savedVolume = SystemVolume.getVolume()
            savedMute = SystemVolume.getMute()
            SystemVolume.setMute(false)
            SystemVolume.setVolume(1.0)
            sound.volume = 1.0
        } else {
            savedVolume = nil
            savedMute = nil
        }

        sound.play()

        if let savedVolume, let savedMute {
            DispatchQueue.main.asyncAfter(deadline: .now() + sound.duration + 0.05) {
                SystemVolume.setVolume(savedVolume)
                SystemVolume.setMute(savedMute)
            }
        }
    }
}

private enum SystemVolume {
    static func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    static func getVolume() -> Float32 {
        guard let deviceID = defaultOutputDeviceID() else { return 1.0 }
        var volume = Float32(1.0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return volume
    }

    static func setVolume(_ volume: Float32) {
        guard let deviceID = defaultOutputDeviceID() else { return }
        var vol = volume
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
    }

    static func getMute() -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }
        var mute = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &mute)
        return mute != 0
    }

    static func setMute(_ muted: Bool) {
        guard let deviceID = defaultOutputDeviceID() else { return }
        var mute = UInt32(muted ? 1 : 0)
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &mute)
    }
}
