//
//  SpatialAudioManager.swift
//  Spatial-Audio-Research-ARVR
//  Simplified spatial audio for object detection
//

import AVFoundation
import Spatial

@Observable
class SpatialAudioManager {
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayers: [UUID: AVAudioPlayerNode] = [:]
    private var audioEnvironment: AVAudioEnvironmentNode?
    
    private let maxDistance: Float = 10.0
    private let minDistance: Float = 0.5
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioEnvironment = AVAudioEnvironmentNode()
        
        guard let engine = audioEngine,
              let environment = audioEnvironment else {
            print("Failed to create audio engine")
            return
        }
        
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        
        var listenerPos = AVAudio3DPoint()
        listenerPos.x = 0
        listenerPos.y = 0
        listenerPos.z = 0
        environment.listenerPosition = listenerPos
        
        var listenerOrientation = AVAudio3DAngularOrientation()
        listenerOrientation.yaw = 0
        listenerOrientation.pitch = 0
        listenerOrientation.roll = 0
        environment.listenerAngularOrientation = listenerOrientation
        
        do {
            try engine.start()
            print("Audio engine started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func updateAudioForObjects(_ objects: [CoreMLObjectDetector.DetectedObject],
                              listenerPosition: SIMD3<Float>,
                              listenerOrientation: simd_quatf) {
        
        guard let environment = audioEnvironment else { return }
        
        var pos = AVAudio3DPoint()
        pos.x = listenerPosition.x
        pos.y = listenerPosition.y
        pos.z = listenerPosition.z
        environment.listenerPosition = pos
        
        let euler = listenerOrientation.eulerAngles
        var orientation = AVAudio3DAngularOrientation()
        orientation.yaw = euler.y
        orientation.pitch = euler.x
        orientation.roll = euler.z
        environment.listenerAngularOrientation = orientation
        
        let currentObjectIds = Set(objects.map { $0.id })
        for (id, player) in audioPlayers {
            if !currentObjectIds.contains(id) {
                removeAudioPlayer(id: id)
            }
        }
        
        for object in objects {
            updateAudioForObject(object)
        }
    }
    
    private func updateAudioForObject(_ object: CoreMLObjectDetector.DetectedObject) {
        let player = audioPlayers[object.id] ?? createAudioPlayer(for: object)
        
        guard let environment = audioEnvironment else { return }
        
        var pos = AVAudio3DPoint()
        pos.x = object.worldPosition.x
        pos.y = object.worldPosition.y
        pos.z = object.worldPosition.z
        player.position = pos
        
        player.volume = 0.3
        
        let pitchCue = getPitchForDistance(object.distance)
        playAudioCue(pitchCue, for: player)
    }
    
    private func getPitchForDistance(_ distance: Float) -> Float {
        let clampedDistance = min(max(distance, 0.5), 5.0)
        
        let minFreq: Float = 200.0
        let maxFreq: Float = 1000.0
        
        let normalizedDistance = (clampedDistance - 0.5) / (5.0 - 0.5)
        
        let frequency = minFreq + (maxFreq - minFreq) * normalizedDistance
        
        return frequency
    }
    
    private func playAudioCue(_ frequency: Float, for player: AVAudioPlayerNode) {
        let sampleRate = 44100.0
        let duration = 0.15
        
        let buffer = generateTone(frequency: Double(frequency), duration: duration, sampleRate: sampleRate)
        
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if player.engine != nil {
                    self.playAudioCue(frequency, for: player)
                }
            }
        }
        
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func createAudioPlayer(for object: CoreMLObjectDetector.DetectedObject) -> AVAudioPlayerNode {
        guard let engine = audioEngine,
              let environment = audioEnvironment else {
            fatalError("Audio engine not initialized")
        }
        
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: environment, format: nil)
        
        audioPlayers[object.id] = player
        
        return player
    }
    
    private func generateTone(frequency: Double, duration: Double, sampleRate: Double) -> AVAudioPCMBuffer {
        let frameCount = UInt32(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let amplitude: Float = 0.2
        let omega = 2.0 * Double.pi * frequency / sampleRate
        
        for frame in 0..<Int(frameCount) {
            let value = Float(sin(omega * Double(frame))) * amplitude
            buffer.floatChannelData?[0][frame] = value
            buffer.floatChannelData?[1][frame] = value
        }
        
        return buffer
    }
    
    private func removeAudioPlayer(id: UUID) {
        guard let player = audioPlayers[id] else { return }
        
        player.stop()
        audioEngine?.detach(player)
        audioPlayers.removeValue(forKey: id)
    }
    
    func stop() {
        for (id, _) in audioPlayers {
            removeAudioPlayer(id: id)
        }
        audioEngine?.stop()
    }
}

extension simd_quatf {
    var eulerAngles: SIMD3<Float> {
        let w = self.vector.w
        let x = self.vector.x
        let y = self.vector.y
        let z = self.vector.z
        
        let pitch = asin(2 * (w * x - y * z))
        let yaw = atan2(2 * (w * y + x * z), 1 - 2 * (x * x + y * y))
        let roll = atan2(2 * (w * z + x * y), 1 - 2 * (x * x + z * z))
        
        return SIMD3<Float>(pitch, yaw, roll)
    }
}
