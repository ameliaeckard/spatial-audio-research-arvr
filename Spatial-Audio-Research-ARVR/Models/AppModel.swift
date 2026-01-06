//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 1/6/26.
//

import ARKit
import RealityKit
import SwiftUI
import QuartzCore
import AVFoundation
import CoreGraphics

@MainActor
@Observable
class AppModel {
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    enum DetectionObject: String, CaseIterable {
        case box = "Box"

        var icon: String {
            switch self {
            case .box: return "shippingbox.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .box: return .green
            }
        }
        
        var referenceObjectName: String {
            switch self {
            case .box: return "Box"
            }
        }
    }
    
    var immersiveSpaceState = ImmersiveSpaceState.closed {
        didSet {
            guard immersiveSpaceState == .closed else { return }
            arkitSession.stop()
            selectedObject = nil
            detectedObjects.removeAll()
            stopObjectTracking()
        }
    }
    
    var selectedObject: DetectionObject? = nil
    var providersStoppedWithError = false
    var detectedObjects: [DetectionObject: Bool] = [:]
    
    var isTracking = false
    var trackedObjects: [DetectedObject] = []
    var boundingBoxes: [UUID: BoundingBoxEntity] = [:]
    var rootEntity: Entity?
    var currentVisualization: ObjectAnchorVisualization? = nil

    // Disabled - using entity-based audio instead
    // private let audioManager = SpatialAudioManager()
    private let referenceObjectLoader = ReferenceObjectLoader()
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }
    
    var allRequiredProvidersAreSupported: Bool {
        ObjectTrackingProvider.isSupported && WorldTrackingProvider.isSupported
    }
    
    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }
    
    var isReadyToRun: Bool {
        objectTrackingProvider?.state == .running
    }
    
    private var arkitSession = ARKitSession()
    private var objectTrackingProvider: ObjectTrackingProvider?
    private var worldTrackingProvider: WorldTrackingProvider?
    private var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    init() {
        print("Object Tracking initialized")
    }
    
    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                switch newState {
                case .initialized, .running, .paused:
                    break
                case .stopped:
                    if let error {
                        print("ARKitSession error: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
            default:
                break
            }
        }
    }
    
    func queryWorldSensingAuthorization() async {
        let authorizationQuery = await arkitSession.queryAuthorization(for: [.worldSensing])
        
        if let worldSensingResult = authorizationQuery[.worldSensing] {
            worldSensingAuthorizationStatus = worldSensingResult
        }
    }
    
    func requestWorldSensingAuthorization() async {
        let authorizationRequest = await arkitSession.requestAuthorization(for: [.worldSensing])
        
        if let worldSensingResult = authorizationRequest[.worldSensing] {
            worldSensingAuthorizationStatus = worldSensingResult
        }
    }
    
    func startObjectTracking() async {
        guard !isTracking else { return }

        print("Starting object tracking")

        // Audio now handled by entity-based audio in ObjectAnchorVisualization

        await referenceObjectLoader.loadReferenceObjects()
        
        let referenceObjects = referenceObjectLoader.referenceObjects
        
        if referenceObjects.isEmpty {
            print("No reference objects available - cannot start tracking")
            return
        }
        
        print("Starting object tracking with \(referenceObjects.count) reference object(s)")
        
        let objectTrackingProvider = ObjectTrackingProvider(referenceObjects: referenceObjects)
        let worldTrackingProvider = WorldTrackingProvider()
        
        do {
            try await arkitSession.run([objectTrackingProvider, worldTrackingProvider])
            self.objectTrackingProvider = objectTrackingProvider
            self.worldTrackingProvider = worldTrackingProvider
            print("ARKit session running")
        } catch {
            print("Error starting tracking: \(error)")
            return
        }
        
        while objectTrackingProvider.state != .running {
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        print("Object tracking active")
        isTracking = true
        
        Task {
            await processObjectUpdates()
        }
        
        Task {
            await updateListenerPositionLoop()
        }
    }
    
    private func processObjectUpdates() async {
        guard let objectTrackingProvider = objectTrackingProvider,
              let rootEntity = rootEntity else {
            print("Missing provider or root entity")
            return
        }

        print("Starting to monitor for object anchor updates...")

        for await anchorUpdate in objectTrackingProvider.anchorUpdates {
            let anchor = anchorUpdate.anchor
            let objectName = anchor.referenceObject.name
            
            switch anchorUpdate.event {
            case .added:
                print("Object detected: \(objectName)")

                // If we already have a visualization, just update it instead of recreating
                // This preserves the UUID and prevents audio player recreation
                if let existingViz = currentVisualization {
                    print("Updating existing visualization instead of recreating")
                    existingViz.update(with: anchor)
                } else {
                    let visualization = ObjectAnchorVisualization(for: anchor)
                    currentVisualization = visualization
                    rootEntity.addChild(visualization.entity)
                    print("Created visualization for \(objectName)")
                }

                updateTrackedObjectsList()
                
            case .updated:
                currentVisualization?.update(with: anchor)
                updateTrackedObjectsList()
                
            case .removed:
                print("Object lost: \(objectName)")
                
                if let viz = currentVisualization {
                    viz.entity.removeFromParent()
                    currentVisualization = nil
                    print("Removed visualization for \(objectName)")
                }
                
                updateTrackedObjectsList()
            }
        }
    }
    
    private func updateListenerPositionLoop() async {
        guard let worldTrackingProvider = worldTrackingProvider else {
            print("Missing world tracking provider")
            return
        }

        var debugCounter = 0
        while isTracking {
            guard let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                try? await Task.sleep(for: .milliseconds(50))
                continue
            }

            let transform = deviceAnchor.originFromAnchorTransform
            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            // Debug logging every 2 seconds
            if debugCounter % 40 == 0 && !trackedObjects.isEmpty {
                print("Listener (head) position: (\(String(format: "%.2f", position.x)), \(String(format: "%.2f", position.y)), \(String(format: "%.2f", position.z)))")
                for obj in trackedObjects {
                    print("   Object '\(obj.label)' at: (\(String(format: "%.2f", obj.worldPosition.x)), \(String(format: "%.2f", obj.worldPosition.y)), \(String(format: "%.2f", obj.worldPosition.z))) - Distance: \(String(format: "%.2f", obj.distance))m")
                }
            }
            debugCounter += 1

            // Audio handled by entity-based audio (no manual updates needed)

            try? await Task.sleep(for: .milliseconds(50))
        }
    }
    
    private func updateTrackedObjectsList() {
        guard let viz = currentVisualization else {
            trackedObjects.removeAll()
            updateDetectionStatus()
            updateBoundingBoxes()
            return
        }

        let worldPos = viz.entity.position(relativeTo: nil)
        
        guard let worldTrackingProvider = worldTrackingProvider,
              let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }
        
        let deviceTransform = deviceAnchor.originFromAnchorTransform
        let devicePosition = SIMD3<Float>(
            deviceTransform.columns.3.x,
            deviceTransform.columns.3.y,
            deviceTransform.columns.3.z
        )
        
        let distance = simd_distance(worldPos, devicePosition)
        let direction = normalize(worldPos - devicePosition)
        
        // Use the stable UUID from the visualization instead of creating a new one
        let detected = DetectedObject(
            id: viz.detectedObjectId,
            label: viz.label,
            confidence: 1.0,
            worldPosition: worldPos,
            boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
            distance: distance,
            direction: direction
        )
        
        trackedObjects = [detected]
        updateDetectionStatus()
        updateBoundingBoxes()
    }
    
    private func updateBoundingBoxes() {
        guard let rootEntity = rootEntity else { return }
        
        let currentObjectIds = Set(trackedObjects.map { $0.id })
        
        for (id, box) in boundingBoxes where !currentObjectIds.contains(id) {
            box.removeFromParent()
            boundingBoxes.removeValue(forKey: id)
        }
        
        for object in trackedObjects {
            if let existingBox = boundingBoxes[object.id] {
                existingBox.update(with: object)
            } else {
                let newBox = BoundingBoxEntity(for: object)
                rootEntity.addChild(newBox)
                boundingBoxes[object.id] = newBox
            }
        }
    }
    
    private func updateDetectionStatus() {
        for object in DetectionObject.allCases {
            let isDetected = trackedObjects.contains { detected in
                detected.label.lowercased().contains(object.rawValue.lowercased()) ||
                object.rawValue.lowercased().contains(detected.label.lowercased())
            }
            detectedObjects[object] = isDetected
        }
    }
    
    func stopObjectTracking() {
        guard isTracking else { return }
        
        print("Stopping object tracking")
        
        isTracking = false
        trackedObjects.removeAll()
        
        for (_, box) in boundingBoxes {
            box.removeFromParent()
        }
        boundingBoxes.removeAll()
        
        if let viz = currentVisualization {
            viz.entity.removeFromParent()
            currentVisualization = nil
        }

        // Audio stops automatically when entity is removed (deinit)

        print("Object tracking stopped and cleaned up")
    }
}

class ObjectAnchorVisualization {
    let entity: Entity
    let label: String
    var position: SIMD3<Float>
    let detectedObjectId: UUID  // Stable ID for this visualization
    private var audioPlaybackController: AudioPlaybackController?
    private var beepTimer: Timer?
    private static var cachedBeepResource: AudioFileResource?  // Cache audio resource globally

    init(for anchor: ObjectAnchor) {
        self.entity = Entity()
        self.label = anchor.referenceObject.name
        self.position = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )
        self.detectedObjectId = UUID()  // Create stable ID once

        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        let mesh = MeshResource.generateBox(size: [0.15, 0.15, 0.15])
        var material = UnlitMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(0.5))

        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        entity.addChild(modelEntity)

        // Setup spatial audio on the entity
        setupEntityAudio()
    }

    private func setupEntityAudio() {
        // Add spatial audio component
        entity.components.set(SpatialAudioComponent())

        // Load and play audio
        Task { @MainActor in
            do {
                // Use cached resource if available, otherwise generate it once
                if Self.cachedBeepResource == nil {
                    print("Generating beep audio (one-time)...")
                    let beepURL = try await generateBeepFile()
                    Self.cachedBeepResource = try await AudioFileResource(contentsOf: beepURL)
                    print("Audio cached")
                }

                guard let resource = Self.cachedBeepResource else { return }

                // Start playing in a loop
                startBeepLoop(with: resource)

            } catch {
                print("Audio setup failed: \(error.localizedDescription)")
            }
        }
    }

    private func generateBeepFile() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let frequency = 800.0
                    let duration = 0.15
                    let sampleRate = 44100.0
                    let frameCount = UInt32(duration * sampleRate)

                    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
                        throw NSError(domain: "AudioGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
                    }

                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                        throw NSError(domain: "AudioGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
                    }

                    buffer.frameLength = frameCount

                    guard let channelData = buffer.floatChannelData?[0] else {
                        throw NSError(domain: "AudioGen", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get channel data"])
                    }

                    // Generate sine wave
                    let angularFrequency = 2.0 * Double.pi * frequency
                    for frame in 0..<Int(frameCount) {
                        let time = Double(frame) / sampleRate
                        let sample = Float(sin(angularFrequency * time))

                        // Apply fade in/out
                        let fadeFrames = Int(sampleRate * 0.01)
                        var amplitude: Float = 1.0
                        if frame < fadeFrames {
                            amplitude = Float(frame) / Float(fadeFrames)
                        } else if frame > Int(frameCount) - fadeFrames {
                            amplitude = Float(Int(frameCount) - frame) / Float(fadeFrames)
                        }

                        channelData[frame] = sample * amplitude * 0.5
                    }

                    // Save to file (use fixed name for caching)
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileURL = tempDir.appendingPathComponent("spatial_beep.caf")

                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: fileURL)

                    let audioFile = try AVAudioFile(forWriting: fileURL,
                                                   settings: format.settings,
                                                   commonFormat: .pcmFormatFloat32,
                                                   interleaved: false)

                    try audioFile.write(from: buffer)

                    continuation.resume(returning: fileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startBeepLoop(with resource: AudioFileResource) {
        print("Beep loop started")

        // Play immediately
        playBeep(with: resource)

        // Setup timer for continuous beeping
        DispatchQueue.main.async {
            self.beepTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.playBeep(with: resource)
            }
        }
    }

    private func playBeep(with resource: AudioFileResource) {
        audioPlaybackController = entity.playAudio(resource)
        // Removed excessive logging - audio plays automatically
    }

    func update(with anchor: ObjectAnchor) {
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        self.position = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )
    }

    deinit {
        beepTimer?.invalidate()
        audioPlaybackController?.stop()
        print("Audio cleanup complete")
    }
}
