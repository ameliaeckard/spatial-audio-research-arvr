//
//  SpatialAudioManager.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/14/25.
//

import AVFoundation
import Spatial

class SpatialAudioManager: @unchecked Sendable {
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayers: [UUID: AVAudioPlayerNode] = [:]
    private var audioEnvironment: AVAudioEnvironmentNode?
    
    // Store object info so we can recalculate frequency
    private var objectInfo: [UUID: ObjectInfo] = [:]
    
    // Track which objects are actively beeping
    private var activeBeepLoops: Set<UUID> = []
    
    private struct ObjectInfo {
        var distance: Float
        var worldPosition: SIMD3<Float>
    }
    
    // Audio configuration
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
            if audioSession.isOtherAudioPlaying {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            }
            
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            
            print("Audio session configured")
        } catch {
            print("ERROR: Failed to configure audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioEnvironment = AVAudioEnvironmentNode()
        
        guard let engine = audioEngine,
              let environment = audioEnvironment else {
            print("ERROR: Failed to create audio engine")
            return
        }
        
        engine.attach(environment)
        
        let format = environment.outputFormat(forBus: 0)
        engine.connect(environment, to: engine.mainMixerNode, format: format)
        
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        environment.renderingAlgorithm = .HRTFHQ
        
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 1.0
        environment.distanceAttenuationParameters.maximumDistance = 50.0
        environment.distanceAttenuationParameters.rolloffFactor = 1.0
        
        print("Audio environment configured - HRTF HQ, Inverse distance model")
        
        startAudioEngine()
    }
    
    private func startAudioEngine() {
        guard let engine = audioEngine, !isEngineRunning else {
            return
        }
        
        do {
            engine.prepare()
            try engine.start()
            isEngineRunning = true
            print("SUCCESS: Audio engine started")
        } catch {
            print("ERROR: Failed to start audio engine: \(error)")
            isEngineRunning = false
        }
    }
    
    func updateAudioForObjects(_ objects: [DetectedObject],
                              listenerPosition: SIMD3<Float>,
                              listenerOrientation: simd_quatf) {
        
        guard isEngineRunning, let environment = audioEnvironment else {
            print("ERROR: Cannot update audio - engine not running")
            return
        }
        
        environment.listenerPosition = AVAudio3DPoint(x: listenerPosition.x, y: listenerPosition.y, z: listenerPosition.z)
        
        let euler = listenerOrientation.eulerAngles
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: euler.y, pitch: euler.x, roll: euler.z)
        
        lock.lock()
        let currentIds = Set(objects.map { $0.id })
        let existingIds = Set(audioPlayers.keys)
        lock.unlock()
        
        let idsToRemove = existingIds.subtracting(currentIds)
        for id in idsToRemove {
            removeAudioPlayer(id: id)
        }
        
        for object in objects {
            updateAudioForObject(object)
        }
    }
    
    private func updateAudioForObject(_ object: DetectedObject) {
        guard isEngineRunning else { return }
        
        lock.lock()
        var player = audioPlayers[object.id]
        let needsCreate = (player == nil)
        let alreadyBeeping = activeBeepLoops.contains(object.id)
        
        // Store/update object info for frequency calculation
        objectInfo[object.id] = ObjectInfo(distance: object.distance, worldPosition: object.worldPosition)
        lock.unlock()
        
        if needsCreate {
            player = createAudioPlayer(for: object)
            print("Created audio player for: \(object.label) at (\(String(format: "%.2f", object.worldPosition.x)), \(String(format: "%.2f", object.worldPosition.y)), \(String(format: "%.2f", object.worldPosition.z)))")
        }
        
        guard let player = player else { return }
        
        // Update 3D position
        let audioPosition = AVAudio3DPoint(x: object.worldPosition.x, y: object.worldPosition.y, z: object.worldPosition.z)
        player.position = audioPosition
        
        // Update volume
        let clampedDistance = min(max(object.distance, minDistance), maxDistance)
        let normalizedDistance = (clampedDistance - minDistance) / (maxDistance - minDistance)
        let volume = Float(1.0 - (normalizedDistance * 0.7))
        player.volume = volume
        
        // Only start beep loop if not already running
        if !alreadyBeeping {
            lock.lock()
            activeBeepLoops.insert(object.id)
            lock.unlock()
            scheduleNextBeep(for: object.id)
        }
    }
    
    private func scheduleNextBeep(for objectId: UUID) {
        guard isEngineRunning else { return }
        
        lock.lock()
        guard let player = audioPlayers[objectId],
              let info = objectInfo[objectId] else {
            activeBeepLoops.remove(objectId)
            lock.unlock()
            return
        }
        lock.unlock()
        
        // Calculate frequency based on distance
        let clampedDistance = min(max(info.distance, minDistance), maxDistance)
        let normalizedDistance = (clampedDistance - minDistance) / (maxDistance - minDistance)
        
        let minFreq: Float = 300.0  // Far away
        let maxFreq: Float = 800.0  // Close
        let frequency = maxFreq - (normalizedDistance * (maxFreq - minFreq))
        
        // Generate tone
        guard let buffer = generateTone(frequency: Double(frequency), duration: 0.2, sampleRate: 44100.0) else {
            print("ERROR: Failed to generate tone, retrying in 2 seconds")
            // Retry after delay if buffer generation fails
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.scheduleNextBeep(for: objectId)
            }
            return
        }

        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            guard let self = self else { return }

            // Wait 2 seconds between beeps
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.scheduleNextBeep(for: objectId)
            }
        }

        if !player.isPlaying {
            player.play()
        }
    }
    
    private func createAudioPlayer(for object: DetectedObject) -> AVAudioPlayerNode? {
        guard let engine = audioEngine,
              let environment = audioEnvironment,
              isEngineRunning else {
            return nil
        }
        
        let player = AVAudioPlayerNode()
        
        engine.attach(player)
        
        let format = player.outputFormat(forBus: 0)
        engine.connect(player, to: environment, format: format)
        
        player.renderingAlgorithm = .HRTFHQ
        player.position = AVAudio3DPoint(x: object.worldPosition.x, y: object.worldPosition.y, z: object.worldPosition.z)
        
        lock.lock()
        audioPlayers[object.id] = player
        lock.unlock()
        
        return player
    }
    
    private func generateTone(frequency: Double, duration: Double, sampleRate: Double) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(duration * sampleRate)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            print("ERROR: Failed to create audio format")
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("ERROR: Failed to create audio buffer")
            return nil
        }
        
        buffer.frameLength = frameCount
        
        let amplitude: Float = 0.3
        let omega = 2.0 * Double.pi * frequency / sampleRate
        
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let fadeIn = min(1.0, t * 5.0)
            let fadeOut = min(1.0, (duration - t) * 5.0)
            let envelope = Float(fadeIn * fadeOut)
            
            let sample = Float(sin(omega * Double(frame))) * amplitude * envelope
            
            buffer.floatChannelData?[0][frame] = sample
            buffer.floatChannelData?[1][frame] = sample
        }
        
        return buffer
    }
    
    private func removeAudioPlayer(id: UUID) {
        lock.lock()
        let player = audioPlayers[id]
        audioPlayers.removeValue(forKey: id)
        objectInfo.removeValue(forKey: id)
        activeBeepLoops.remove(id)
        lock.unlock()
        
        guard let player = player else { return }
        
        player.stop()
        
        if let engine = audioEngine, engine.attachedNodes.contains(player) {
            engine.detach(player)
        }
        
        print("Removed audio player for object ID: \(id)")
    }
    
    func stop() {
        lock.lock()
        let playerIds = Array(audioPlayers.keys)
        lock.unlock()
        
        for id in playerIds {
            removeAudioPlayer(id: id)
        }
        
        audioEngine?.stop()
        isEngineRunning = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
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
