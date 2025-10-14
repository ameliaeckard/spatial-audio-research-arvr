import Foundation
import AVFoundation
import Spatial

@MainActor
class SpatialAudio: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var environmentNode: AVAudioEnvironmentNode
    private var speechSynthesizer: AVSpeechSynthesizer
    private var activeAudioSources: [UUID: AudioSource] = [:]
    
    @Published var isEnabled: Bool = true
    @Published var volume: Float = 0.5
    
    private struct AudioSource {
        let playerNode: AVAudioPlayerNode
        let format: AVAudioFormat
        var isPlaying: Bool
    }
    
    init() {
        audioEngine = AVAudioEngine()
        environmentNode = AVAudioEnvironmentNode()
        speechSynthesizer = AVSpeechSynthesizer()
        
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(environmentNode)
        
        audioEngine.connect(
            environmentNode,
            to: audioEngine.mainMixerNode,
            format: AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)
        )
        
        environmentNode.renderingAlgorithm = .HRTF
        environmentNode.distanceAttenuationParameters.maximumDistance = 10.0
        environmentNode.distanceAttenuationParameters.referenceDistance = 1.0
        
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: 0,
            pitch: 0,
            roll: 0
        )
        
        configureAudioSession()
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .allowBluetooth]
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func updateAudioCues(for objects: [DetectedObject]) {
        guard isEnabled else {
            stopAllAudioCues()
            return
        }
        
        let currentIds = Set(objects.map { $0.id })
        let idsToRemove = activeAudioSources.keys.filter { !currentIds.contains($0) }
        
        for id in idsToRemove {
            stopAudioCue(for: id)
        }
        for object in objects {
            if activeAudioSources[object.id] != nil {
                updateAudioPosition(for: object)
            } else {
                playAudioCue(for: object)
            }
        }
    }
    
    private func playAudioCue(for object: DetectedObject) {
        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1) else {
            return
        }
        audioEngine.connect(playerNode, to: environmentNode, format: format)
        
        playerNode.position = AVAudio3DPoint(
            x: object.position.x,
            y: object.position.y,
            z: object.position.z
        )
        
        if let buffer = generateTone(for: object, format: format) {
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.volume = volume * intensityForDistance(object.distance())
            playerNode.play()
            
            activeAudioSources[object.id] = AudioSource(
                playerNode: playerNode,
                format: format,
                isPlaying: true
            )
        }
    }
    
    private func updateAudioPosition(for object: DetectedObject) {
        guard let source = activeAudioSources[object.id] else { return }
        
        source.playerNode.position = AVAudio3DPoint(
            x: object.position.x,
            y: object.position.y,
            z: object.position.z
        )
        
        source.playerNode.volume = volume * intensityForDistance(object.distance())
    }
    
    private func stopAudioCue(for id: UUID) {
        guard let source = activeAudioSources[id] else { return }
        
        source.playerNode.stop()
        audioEngine.detach(source.playerNode)
        activeAudioSources.removeValue(forKey: id)
    }
    
    func stopAllAudioCues() {
        for id in activeAudioSources.keys {
            stopAudioCue(for: id)
        }
    }
    
    private func generateTone(for object: DetectedObject, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let duration = 0.4
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return nil
        }
        
        let frequency = frequencyForObject(object)
        let distance = object.distance()
        
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let value = sin(2.0 * .pi * frequency * time)
            
            let envelope: Float
            let fadeFrames = Int(frameCount) / 8
            if frame < fadeFrames {
                envelope = Float(frame) / Float(fadeFrames)
            } else if frame > Int(frameCount) - fadeFrames {
                envelope = Float(Int(frameCount) - frame) / Float(fadeFrames)
            } else {
                envelope = 1.0
            }
            
            let sample = Float(value) * envelope * 0.3
            channelData[0][frame] = sample
        }
        
        return buffer
    }
    
    private func frequencyForObject(_ object: DetectedObject) -> Double {
        switch object.name.lowercased() {
        case "chair": return 440.0
        case "table": return 523.25 // C5
        case "door": return 659.25 // E5
        case "cup": return 783.99 // G5
        case "bottle": return 880.0 // A5
        case "laptop": return 587.33 // D5
        default: return 440.0
        }
    }
    
    private func intensityForDistance(_ distance: Float) -> Float {
        let minDistance: Float = 0.5
        let maxDistance: Float = 5.0
        
        let clampedDistance = max(minDistance, min(distance, maxDistance))
        return 1.0 - ((clampedDistance - minDistance) / (maxDistance - minDistance)) * 0.7
    }
    
    func speak(_ text: String, rate: Float = 0.5) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.volume = volume
        
        speechSynthesizer.speak(utterance)
    }
    
    func announceObject(_ object: DetectedObject) {
        let distance = object.distance()
        let direction = object.directionDescription()
        
        let announcement = "\(object.name), \(direction), \(String(format: "%.1f", distance)) meters"
        speak(announcement)
    }
    
    func announceAllObjects(_ objects: [DetectedObject]) {
        guard !objects.isEmpty else {
            speak("No objects detected")
            return
        }
        
        let sorted = objects.sorted { $0.distance() < $1.distance() }
        let announcement = sorted.prefix(5).map { object in
            "\(object.name) at \(String(format: "%.1f", object.distance())) meters"
        }.joined(separator: ", ")
        
        speak("Detected: \(announcement)")
    }
    
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            stopAllAudioCues()
        }
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        
        for source in activeAudioSources.values {
            source.playerNode.volume = volume
        }
    }

    deinit {
        stopAllAudioCues()
        audioEngine.stop()
    }
}