//
//  SpatialAudioManager.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/2/25.
//
//  Simplified spatial audio for object detection
//

import AVFoundation
import Spatial

class SpatialAudioManager: @unchecked Sendable {
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayers: [UUID: AVAudioPlayerNode] = [:]
    private var audioEnvironment: AVAudioEnvironmentNode?
    
    private let maxDistance: Float = 10.0
    private let minDistance: Float = 0.5
    
    private var isEngineRunning = false
    
    private let lock = NSLock()
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure for spatial audio playback
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            print("Audio session configured successfully")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // Listen for interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("Audio interrupted")
            audioEngine?.pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                print("Resuming audio")
                restartAudioEngine()
            }
        @unknown default:
            break
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioEnvironment = AVAudioEnvironmentNode()
        
        guard let engine = audioEngine,
              let environment = audioEnvironment else {
            print("Failed to create audio engine")
            return
        }
        
        // Configure environment node for spatial audio
        engine.attach(environment)
        
        // Connect environment to main mixer
        let format = environment.outputFormat(forBus: 0)
        engine.connect(environment, to: engine.mainMixerNode, format: format)
        
        // Set up listener position and orientation
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
        
        // Configure rendering algorithm for best spatial audio
        environment.renderingAlgorithm = .HRTFHQ
        
        startAudioEngine()
    }
    
    private func startAudioEngine() {
        guard let engine = audioEngine, !isEngineRunning else { return }
        
        do {
            // Prepare engine before starting
            engine.prepare()
            
            try engine.start()
            isEngineRunning = true
            print("Audio engine started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
            isEngineRunning = false
        }
    }
    
    private func restartAudioEngine() {
        guard let engine = audioEngine else { return }
        
        if !engine.isRunning {
            startAudioEngine()
        }
    }
    
    func updateAudioForObjects(_ objects: [DetectedObject],
                              listenerPosition: SIMD3<Float>,
                              listenerOrientation: simd_quatf) {
        
        // Don't process if engine isn't running
        guard isEngineRunning, let environment = audioEnvironment else { return }
        
        // Update listener position
        var pos = AVAudio3DPoint()
        pos.x = listenerPosition.x
        pos.y = listenerPosition.y
        pos.z = listenerPosition.z
        environment.listenerPosition = pos
        
        // Update listener orientation
        let euler = listenerOrientation.eulerAngles
        var orientation = AVAudio3DAngularOrientation()
        orientation.yaw = euler.y
        orientation.pitch = euler.x
        orientation.roll = euler.z
        environment.listenerAngularOrientation = orientation
        
        // Clean up players for objects that are no longer detected (thread-safe)
        lock.lock()
        let currentObjectIds = Set(objects.map { $0.id })
        let idsToRemove = audioPlayers.keys.filter { !currentObjectIds.contains($0) }
        lock.unlock()
        
        for id in idsToRemove {
            removeAudioPlayer(id: id)
        }
        
        // Update audio for each detected object
        for object in objects {
            updateAudioForObject(object)
        }
    }
    
    private func updateAudioForObject(_ object: DetectedObject) {
        guard isEngineRunning else { return }
        
        // Get or create audio player for this object (thread-safe)
        lock.lock()
        let player = audioPlayers[object.id]
        lock.unlock()
        
        let playerToUse = player ?? createAudioPlayer(for: object)
        
        // Update spatial position
        var pos = AVAudio3DPoint()
        pos.x = object.worldPosition.x
        pos.y = object.worldPosition.y
        pos.z = object.worldPosition.z
        playerToUse.position = pos
        
        // Set volume based on distance (closer = louder, but not too loud)
        let normalizedDistance = min(max(object.distance, 0.5), 5.0)
        let volume = 1.0 - ((normalizedDistance - 0.5) / 4.5) * 0.7
        playerToUse.volume = Float(volume) * 0.3
        
        // Get pitch based on distance
        let pitchCue = getPitchForDistance(object.distance)
        playAudioCue(pitchCue, for: playerToUse)
    }
    
    private func getPitchForDistance(_ distance: Float) -> Float {
        // Clamp distance to reasonable range
        let clampedDistance = min(max(distance, 0.5), 5.0)
        
        // Map distance to frequency (closer = higher pitch)
        let minFreq: Float = 200.0   // Far away
        let maxFreq: Float = 1000.0  // Close
        
        // Normalize distance to 0-1 range
        let normalizedDistance = (clampedDistance - 0.5) / (5.0 - 0.5)
        
        // Invert so closer objects have higher pitch
        let invertedDistance = 1.0 - normalizedDistance
        
        let frequency = minFreq + (maxFreq - minFreq) * invertedDistance
        
        return frequency
    }
    
    private func playAudioCue(_ frequency: Float, for player: AVAudioPlayerNode) {
        guard isEngineRunning, player.engine != nil else { return }
        
        let sampleRate = 44100.0
        let duration = 0.15
        
        let buffer = generateTone(frequency: Double(frequency), duration: duration, sampleRate: sampleRate)
        
        // Stop any existing playback
        player.stop()
        
        // Schedule new buffer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self, weak player] in
            guard let self = self, let player = player else { return }
            
            // Schedule next beep after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isEngineRunning && player.engine != nil {
                    self.playAudioCue(frequency, for: player)
                }
            }
        }
        
        // Start playing if not already playing
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func createAudioPlayer(for object: DetectedObject) -> AVAudioPlayerNode {
        guard let engine = audioEngine,
              let environment = audioEnvironment,
              isEngineRunning else {
            fatalError("Audio engine not initialized or not running")
        }
        
        let player = AVAudioPlayerNode()
        
        // Attach player to engine
        engine.attach(player)
        
        // Connect player to environment node
        let format = player.outputFormat(forBus: 0)
        engine.connect(player, to: environment, format: format)
        
        // Store player (thread-safe)
        lock.lock()
        audioPlayers[object.id] = player
        lock.unlock()
        
        return player
    }
    
    private func generateTone(frequency: Double, duration: Double, sampleRate: Double) -> AVAudioPCMBuffer {
        let frameCount = UInt32(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Failed to create audio buffer")
        }
        
        buffer.frameLength = frameCount
        
        let amplitude: Float = 0.2
        let omega = 2.0 * Double.pi * frequency / sampleRate
        
        // Generate sine wave
        for frame in 0..<Int(frameCount) {
            let value = Float(sin(omega * Double(frame))) * amplitude
            
            // Apply envelope to avoid clicks
            let envelope: Float
            let fadeFrames = Int(frameCount / 10)
            if frame < fadeFrames {
                envelope = Float(frame) / Float(fadeFrames)
            } else if frame > Int(frameCount) - fadeFrames {
                envelope = Float(Int(frameCount) - frame) / Float(fadeFrames)
            } else {
                envelope = 1.0
            }
            
            let finalValue = value * envelope
            
            buffer.floatChannelData?[0][frame] = finalValue  // Left channel
            buffer.floatChannelData?[1][frame] = finalValue  // Right channel
        }
        
        return buffer
    }
    
    private func removeAudioPlayer(id: UUID) {
        lock.lock()
        let player = audioPlayers[id]
        audioPlayers.removeValue(forKey: id)
        lock.unlock()
        
        guard let player = player else { return }
        
        // Stop playback
        player.stop()
        
        // Detach from engine
        if let engine = audioEngine, engine.attachedNodes.contains(player) {
            engine.detach(player)
        }
    }
    
    func stop() {
        // Get all player IDs (thread-safe)
        lock.lock()
        let playerIds = Array(audioPlayers.keys)
        lock.unlock()
        
        // Stop all players
        for id in playerIds {
            removeAudioPlayer(id: id)
        }
        
        // Stop engine
        audioEngine?.stop()
        isEngineRunning = false
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
        
        print("Audio manager stopped")
    }
    
    deinit {
        stop()
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
