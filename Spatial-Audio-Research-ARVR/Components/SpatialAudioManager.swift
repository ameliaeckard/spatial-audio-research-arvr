//
//  SpatialAudioManager.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/13/25.
//
//  Simplified spatial audio for object detection
//

import AVFoundation
import Spatial

class SpatialAudioManager: @unchecked Sendable {
    
    private var audioEngine: AVAudioEngine?
    private var audioPlayers: [UUID: (player: AVAudioPlayerNode, filter: AVAudioUnitEQ, lastPosition: SIMD3<Float>, lastUpdateTime: TimeInterval)] = [:]
    private var audioEnvironment: AVAudioEnvironmentNode?
    
    // Audio configuration
    private let maxDistance: Float = 10.0
    private let minDistance: Float = 0.5
    private let speedOfSound: Float = 343.0 // m/s
    
    // Audio effects
    private let eqBands: [AVAudioUnitEQFilterParameters] = []
    
    private var isEngineRunning = false
    private let lock = NSLock()
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure for spatial audio playback on visionOS
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            print("Audio session configured successfully")
            print("  Category: \(audioSession.category.rawValue)")
            print("  Mode: \(audioSession.mode.rawValue)")
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
        guard let engine = audioEngine, !isEngineRunning else {
            print("Audio engine already running or not initialized")
            return
        }
        
        print("Starting audio engine...")
        
        do {
            // Prepare engine before starting
            engine.prepare()
            print("  Engine prepared")
            
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
        guard isEngineRunning, let environment = audioEnvironment else {
            if !isEngineRunning {
                print("WARNING: Audio engine not running, cannot play audio")
            }
            return
        }
        
        // Debug: Log when we receive objects
        if objects.count > 0 && Int(CACurrentMediaTime() * 10) % 50 == 0 {
            print("Audio manager processing \(objects.count) object(s)")
        }
        
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
        
        let currentTime = CACurrentMediaTime()
        
        lock.lock()
        let existingPlayerInfo = audioPlayers[object.id]
        lock.unlock()
        
        // Store previous position and time for velocity calculation
        let previousPosition = existingPlayerInfo?.lastPosition ?? object.worldPosition
        let previousTime = existingPlayerInfo?.lastUpdateTime ?? currentTime
        
        // Get or create player (createAudioPlayer already adds to dictionary if new)
        let playerToUse: AVAudioPlayerNode
        let filter: AVAudioUnitEQ?
        
        if let existing = existingPlayerInfo {
            playerToUse = existing.player
            filter = existing.filter
            
            // Update the dictionary with new position and time for existing players
            lock.lock()
            audioPlayers[object.id] = (
                player: playerToUse,
                filter: existing.filter,
                lastPosition: object.worldPosition,
                lastUpdateTime: currentTime
            )
            lock.unlock()
        } else {
            // Create new player (this already adds to dictionary)
            playerToUse = createAudioPlayer(for: object)
            filter = audioPlayers[object.id]?.filter
        }
        
        // Calculate velocity (m/s)
        let deltaTime = Float(currentTime - previousTime)
        let velocity: SIMD3<Float>
        if deltaTime > 0 {
            let deltaPos = object.worldPosition - previousPosition
            velocity = deltaPos / deltaTime
        } else {
            velocity = .zero
        }
        
        // Update spatial position
        var pos = AVAudio3DPoint()
        pos.x = object.worldPosition.x
        pos.y = object.worldPosition.y
        pos.z = object.worldPosition.z
        playerToUse.position = pos
        
        // Calculate distance-based effects
        let clampedDistance = min(max(object.distance, minDistance), maxDistance)
        
        // Volume attenuation (inverse square law with minimum distance)
        let refDistance: Float = 1.0
        let distanceFactor = max(clampedDistance, refDistance)
        let volume = 1.0 / (1.0 + (distanceFactor - refDistance) * 0.8)
        playerToUse.volume = Float(volume) * 0.8 // Increased from 0.3 for better audibility
        
        // Debug volume setting
        if Int(currentTime * 10) % 50 == 0 {
            print("Audio player volume set to: \(playerToUse.volume) for distance: \(String(format: "%.2f", clampedDistance))m")
        }
        
        // Apply low-pass filter based on distance (distant sounds have less high frequencies)
        let maxFrequency: Float = 10000.0
        let minFrequency: Float = 200.0
        let frequencyRange = maxFrequency - minFrequency
        let distanceRatio = (clampedDistance - minDistance) / (maxDistance - minDistance)
        let cutoffFrequency = maxFrequency - (frequencyRange * distanceRatio)
        
        // Update EQ filters
        if let filter = filter, filter.bands.count >= 2 {
            // Update low-pass filter (first band)
            let lowPass = filter.bands[0]
            lowPass.frequency = cutoffFrequency
            
            // Update high-pass filter (second band) - helps with clarity
            let highPass = filter.bands[1]
            highPass.frequency = min(400.0, 100.0 + (distanceRatio * 300.0))
        }
        
        // Calculate Doppler effect
        let dopplerFactor = calculateDopplerFactor(objectPosition: object.worldPosition,
                                                 objectVelocity: velocity,
                                                 listenerPosition: pos,
                                                 listenerVelocity: .zero)
        
        // Get base pitch from distance and apply Doppler shift
        let basePitch = getPitchForDistance(clampedDistance)
        let finalPitch = basePitch * dopplerFactor
        
        playAudioCue(finalPitch, for: playerToUse)
    }
    
    private func calculateDopplerFactor(objectPosition: SIMD3<Float>,
                                     objectVelocity: SIMD3<Float>,
                                     listenerPosition: AVAudio3DPoint,
                                     listenerVelocity: SIMD3<Float>) -> Float {
        // Calculate relative velocity
        let listenerPos = SIMD3<Float>(listenerPosition.x, listenerPosition.y, listenerPosition.z)
        let toListener = normalize(listenerPos - objectPosition)
        
        // Project velocities onto the line between object and listener
        let objectSpeed = dot(objectVelocity, toListener)
        let listenerSpeed = dot(listenerVelocity, -toListener)
        let relativeSpeed = objectSpeed - listenerSpeed
        
        // Apply Doppler effect formula
        let dopplerFactor = (speedOfSound + relativeSpeed) / speedOfSound
        
        // Clamp to reasonable values
        return min(max(dopplerFactor, 0.5), 2.0)
    }
    
    private func getPitchForDistance(_ distance: Float) -> Float {
        // Clamp distance to reasonable range
        let clampedDistance = min(max(distance, minDistance), maxDistance)
        
        // Map distance to frequency (closer = higher pitch)
        let minFreq: Float = 200.0   // Far away
        let maxFreq: Float = 1200.0  // Close
        
        // Exponential curve for more natural pitch change
        let normalizedDistance = (clampedDistance - minDistance) / (maxDistance - minDistance)
        let frequency = minFreq * pow(maxFreq / minFreq, 1.0 - normalizedDistance)
        
        return frequency
    }
    
    private func playAudioCue(_ frequency: Float, for player: AVAudioPlayerNode) {
        guard isEngineRunning, player.engine != nil else {
            print("WARNING: Cannot play audio cue - engine not running or player detached")
            return
        }
        
        // Debug: Log first few times this is called
        let currentTime = CACurrentMediaTime()
        if Int(currentTime * 10) % 100 == 0 {
            print("Playing audio cue at \(String(format: "%.1f", frequency)) Hz, volume: \(String(format: "%.2f", player.volume))")
        }
        
        let sampleRate = 44100.0
        let duration = 0.15
        
        // Generate tone with the target frequency
        let buffer = generateTone(frequency: Double(frequency), duration: duration, sampleRate: sampleRate)
        
        // Stop any existing playback
        player.stop()
        
        // Schedule new buffer with precise timing
        let audioTime = player.lastRenderTime ?? AVAudioTime(hostTime: 0)
        let sampleTime = audioTime.sampleTime
        let frameCount = AVAudioFramePosition(sampleRate * 0.02) // 20ms from now
        let when = AVAudioTime(sampleTime: sampleTime + frameCount, atRate: sampleRate)
        
        player.scheduleBuffer(buffer, at: when, options: []) { [weak self, weak player] in
            guard let self = self, let player = player else { return }
            
            // Schedule next beep with a more natural timing variation
            let randomDelay = 0.4 + Double.random(in: -0.1...0.1) // 400ms ± 100ms
            
            DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
                if self.isEngineRunning && player.engine != nil {
                    self.playAudioCue(frequency, for: player)
                }
            }
        }
        
        // Log buffer scheduling
        if Int(currentTime * 10) % 100 == 0 {
            print("Buffer scheduled at \(when.sampleTime), player attached: \(player.engine != nil)")
        }
        
        // Start playing if not already playing
        if !player.isPlaying {
            player.play()
            print("Started audio playback for new player")
        }
    }
    
    private func createAudioPlayer(for object: DetectedObject) -> AVAudioPlayerNode {
        guard let engine = audioEngine,
              let environment = audioEnvironment,
              isEngineRunning else {
            fatalError("Audio engine not initialized or running")
        }
        
        print("Creating audio player for object: \(object.label) at distance \(String(format: "%.2f", object.distance))m")
        
        // Create player node
        let player = AVAudioPlayerNode()
        
        // Create EQ for filtering
        let eq = AVAudioUnitEQ(numberOfBands: 2)
        
        // Configure low-pass filter (for distance)
        let lowPass = eq.bands[0]
        lowPass.filterType = .lowPass
        lowPass.frequency = 10000.0
        lowPass.bandwidth = 0.5
        lowPass.gain = 0.0
        lowPass.bypass = false
        
        // Configure high-pass filter (for clarity)
        let highPass = eq.bands[1]
        highPass.filterType = .highPass
        highPass.frequency = 200.0
        highPass.bandwidth = 0.5
        highPass.gain = 0.0
        highPass.bypass = false
        
        // Attach nodes to engine
        engine.attach(player)
        engine.attach(eq)
        
        // Connect nodes: player -> eq -> environment
        let format = player.outputFormat(forBus: 0)
        engine.connect(player, to: eq, format: format)
        engine.connect(eq, to: environment, format: format)
        
        // Store player and filter (thread-safe)
        lock.lock()
        audioPlayers[object.id] = (
            player: player,
            filter: eq,
            lastPosition: object.worldPosition,
            lastUpdateTime: CACurrentMediaTime()
        )
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
        
        // Generate more interesting sound with harmonics
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let fadeIn = min(1.0, t * 2.0) // 0.5s fade in
            let fadeOut = min(1.0, (duration - t) * 4.0) // 0.25s fade out
            let envelope = fadeIn * fadeOut
            
            // Base frequency
            let base = sin(omega * Double(frame))
            
            // Add some harmonics for a richer sound
            let harmonic1 = 0.3 * sin(2.0 * omega * Double(frame))
            let harmonic2 = 0.1 * sin(3.0 * omega * Double(frame))
            
            // Combine with noise for texture
            let noise = Float.random(in: -1...1) * 0.02
            
            // Break down complex expression for compiler
            let combinedSignal = base + harmonic1 + harmonic2
            let signalWithNoise = Float(combinedSignal) + noise
            let envelopedSignal = signalWithNoise * Float(envelope)
            let value = envelopedSignal * amplitude
            
            // Apply panning based on position (subtle stereo effect)
            let pan = Float(sin(omega * 0.1 * t) * 0.3) // Slow panning effect
            
            buffer.floatChannelData?[0][frame] = value * (0.5 - pan)  // Left channel
            buffer.floatChannelData?[1][frame] = value * (0.5 + pan)  // Right channel
        }
        
        return buffer
    }
    
    private func removeAudioPlayer(id: UUID) {
        lock.lock()
        let playerInfo = audioPlayers[id]
        audioPlayers.removeValue(forKey: id)
        lock.unlock()
        
        guard let playerInfo = playerInfo else { return }
        
        // Stop playback
        playerInfo.player.stop()
        
        // Detach from engine
        if let engine = audioEngine {
            if engine.attachedNodes.contains(playerInfo.player) {
                engine.detach(playerInfo.player)
            }
            if engine.attachedNodes.contains(playerInfo.filter) {
                engine.detach(playerInfo.filter)
            }
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
