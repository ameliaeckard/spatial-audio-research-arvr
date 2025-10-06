import Foundation
import AVFoundation
import CoreAudio

class SpatialAudioManager {
    private var audioEngine: AVAudioEngine
    private var audioPlayers: [UUID: (player: AVAudioPlayerNode, mixer: AVAudioMixerNode)] = [:]
    private var environmentNode: AVAudioEnvironmentNode
    private var speechSynthesizer: AVSpeechSynthesizer
    
    init() {
        audioEngine = AVAudioEngine()
        environmentNode = AVAudioEnvironmentNode()
        speechSynthesizer = AVSpeechSynthesizer()
        
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        // Attach environment node
        audioEngine.attach(environmentNode)
        
        // Connect to output
        audioEngine.connect(
            environmentNode,
            to: audioEngine.mainMixerNode,
            format: nil
        )
        
        // Configure spatial audio
        var listenerPosition = AVAudio3DPoint()
        listenerPosition.x = 0
        listenerPosition.y = 0
        listenerPosition.z = 0
        environmentNode.listenerPosition = listenerPosition
        
        var listenerOrientation = AVAudio3DAngularOrientation()
        listenerOrientation.yaw = 0
        listenerOrientation.pitch = 0
        listenerOrientation.roll = 0
        environmentNode.listenerAngularOrientation = listenerOrientation
        
        // Set rendering algorithm
        environmentNode.renderingAlgorithm = .HRTF
        
        // Start engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
        
        // Configure audio session
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func updateAudioForObjects(_ objects: [DetectedObject]) {
        // Clear old players
        stopAllAudio()
        
        // Create audio cues for each object
        for object in objects {
            playAudioCue(for: object)
        }
    }
    
    private func playAudioCue(for object: DetectedObject) {
        // Create player node and mixer for spatial positioning
        let playerNode = AVAudioPlayerNode()
        let mixerNode = AVAudioMixerNode()
        
        audioEngine.attach(playerNode)
        audioEngine.attach(mixerNode)
        
        // Create format for audio
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        
        // Connect: player -> mixer -> environment node
        audioEngine.connect(playerNode, to: mixerNode, format: format)
        audioEngine.connect(mixerNode, to: environmentNode, format: format)
        
        // Set 3D position on the mixer node
        environmentNode.position = AVAudioMake3DPoint(
            object.position.x,
            object.position.y,
            object.position.z
        )
        
        // Generate audio buffer for object
        if let buffer = generateAudioBuffer(for: object, format: format) {
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.play()
            
            // Store player and mixer
            audioPlayers[object.id] = (player: playerNode, mixer: mixerNode)
        }
    }
    
    private func generateAudioBuffer(for object: DetectedObject, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // Generate a simple tone based on object type and distance
        let sampleRate = format.sampleRate
        let duration = 0.3
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else {
            return nil
        }
        
        // Frequency based on object distance (closer = higher pitch)
        let baseFrequency = 440.0
        let frequency = baseFrequency + (5.0 - Double(object.distance)) * 100.0
        
        // Generate sine wave for all channels
        let channelCount = Int(format.channelCount)
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
            
            // Apply envelope (fade in/out)
            let envelope: Float
            let fadeFrames = frameCount / 10
            if frame < fadeFrames {
                envelope = Float(frame) / Float(fadeFrames)
            } else if frame > frameCount - fadeFrames {
                envelope = Float(frameCount - AVAudioFrameCount(frame)) / Float(fadeFrames)
            } else {
                envelope = 1.0
            }
            
            // Adjust volume based on distance
            let distanceAttenuation = 1.0 / max(object.distance, 1.0)
            
            let sample = Float(value) * envelope * distanceAttenuation * 0.3
            
            // Write to all channels
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }
        
        return buffer
    }
    
    func stopAllAudio() {
        for (_, playerTuple) in audioPlayers {
            playerTuple.player.stop()
            audioEngine.detach(playerTuple.player)
            audioEngine.detach(playerTuple.mixer)
        }
        audioPlayers.removeAll()
    }
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }
    
    deinit {
        stopAllAudio()
        audioEngine.stop()
    }
}
