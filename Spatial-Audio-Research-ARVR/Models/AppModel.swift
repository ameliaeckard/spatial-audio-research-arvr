//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 4/29/26.
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
              self.rootEntity != nil else {
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

                if let existingViz = currentVisualization {
                    print("Updating existing visualization instead of recreating")
                    existingViz.update(with: anchor)
                } else {
                    let visualization = ObjectAnchorVisualization(for: anchor)
                    currentVisualization = visualization
                    self.rootEntity?.addChild(visualization.entity)
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
            let listenerPos = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )

            // Push updated distance + listener position into the visualization
            // so audio frequency and metrics label stay current
            if let viz = currentVisualization {
                let objPos = viz.position
                let distance = simd_distance(objPos, listenerPos)
                viz.updateMetrics(distance: distance, listenerWorldPosition: listenerPos)
            }

            // Debug logging every 2 seconds
            if debugCounter % 40 == 0 && !trackedObjects.isEmpty {
                print("Listener (head) position: (\(String(format: "%.2f", listenerPos.x)), \(String(format: "%.2f", listenerPos.y)), \(String(format: "%.2f", listenerPos.z)))")
                for obj in trackedObjects {
                    print("   Object '\(obj.label)' at: (\(String(format: "%.2f", obj.worldPosition.x)), \(String(format: "%.2f", obj.worldPosition.y)), \(String(format: "%.2f", obj.worldPosition.z))) - Distance: \(String(format: "%.2f", obj.distance))m")
                }
            }
            debugCounter += 1

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
        // BoundingBoxEntity is now redundant since ObjectAnchorVisualization
        // renders its own accurate wireframe. Clear any leftover boxes.
        guard let rootEntity = rootEntity else { return }

        for (_, box) in boundingBoxes {
            box.removeFromParent()
        }
        boundingBoxes.removeAll()
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

        print("Object tracking stopped and cleaned up")
    }
}

// MARK: - ObjectAnchorVisualization

class ObjectAnchorVisualization {
    let entity: Entity
    let label: String
    var position: SIMD3<Float>
    let detectedObjectId: UUID

    // Distance-driven audio constants — far = HIGH pitch, close = LOW pitch
    static let minDistance: Float   = 0.3
    static let maxDistance: Float   = 10.0
    static let minFrequency: Double = 300.0
    static let maxFrequency: Double = 1200.0

    private(set) var currentDistance: Float  = 0
    private(set) var currentFrequency: Double = 300.0

    // Entity-based audio so RealityKit handles 3D positioning automatically
    private var audioPlaybackController: AudioPlaybackController?
    private var beepTimer: Timer?

    // Cached audio resources keyed by frequency bucket (avoids regenerating every beep)
    private static var audioCache: [Int: AudioFileResource] = [:]
    private static let cacheBucketSize: Double = 50.0  // Hz per bucket

    // Floating metrics label shown above the box
    private var metricsLabelRoot: Entity?

    // Store extent so the label offset stays correct after updates
    private var boxExtent: SIMD3<Float> = .zero
    private var boxCenter: SIMD3<Float> = .zero

    init(for anchor: ObjectAnchor) {
        self.entity           = Entity()
        self.label            = anchor.referenceObject.name
        self.detectedObjectId = UUID()
        self.position = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )

        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)

        // anchor.boundingBox.center is the offset from the anchor origin to the box centre
        // anchor.boundingBox.extent is the full width/height/depth
        let bbox   = anchor.boundingBox
        boxExtent  = bbox.extent
        boxCenter  = bbox.center

        buildWireframeBox(extent: boxExtent, center: boxCenter)
        buildMetricsLabel(extent: boxExtent, center: boxCenter)

        // Attach SpatialAudioComponent so RealityKit positions the sound at the entity
        entity.components.set(SpatialAudioComponent())

        // Kick off the beep loop
        scheduleNextBeep()
    }

    // MARK: - Wireframe

    private func buildWireframeBox(extent: SIMD3<Float>, center: SIMD3<Float>) {
        // Wrapper positioned at the bounding box centre offset
        let boxRoot = Entity()
        boxRoot.position = center
        entity.addChild(boxRoot)

        // UnlitMaterial requires explicit blending to be truly transparent
        let fillMesh = MeshResource.generateBox(size: extent)
        var fillMat  = UnlitMaterial()
        fillMat.color    = .init(tint: .white.withAlphaComponent(0.0))
        fillMat.blending = .transparent(opacity: .init(floatLiteral: 0.0))
        let fillEntity = ModelEntity(mesh: fillMesh, materials: [fillMat])
        boxRoot.addChild(fillEntity)

        // 12-edge wireframe from thin box prisms
        let t: Float = 0.003
        let (w, h, d) = (extent.x, extent.y, extent.z)

        let edgeConfigs: [(size: SIMD3<Float>, pos: SIMD3<Float>)] = [
            ([w, t, t], [ 0,  h/2,  d/2]),
            ([w, t, t], [ 0, -h/2,  d/2]),
            ([w, t, t], [ 0,  h/2, -d/2]),
            ([w, t, t], [ 0, -h/2, -d/2]),
            ([t, h, t], [ w/2,  0,  d/2]),
            ([t, h, t], [-w/2,  0,  d/2]),
            ([t, h, t], [ w/2,  0, -d/2]),
            ([t, h, t], [-w/2,  0, -d/2]),
            ([t, t, d], [ w/2,  h/2,  0]),
            ([t, t, d], [-w/2,  h/2,  0]),
            ([t, t, d], [ w/2, -h/2,  0]),
            ([t, t, d], [-w/2, -h/2,  0])
        ]

        var edgeMat = UnlitMaterial()
        edgeMat.color = .init(tint: .green)

        for cfg in edgeConfigs {
            let edge = ModelEntity(mesh: MeshResource.generateBox(size: cfg.size), materials: [edgeMat])
            edge.position = cfg.pos
            boxRoot.addChild(edge)
        }
    }

    // MARK: - Metrics label

    private func buildMetricsLabel(extent: SIMD3<Float>, center: SIMD3<Float>) {
        let root = Entity()
        // Position above the top face: center.y + half-height + small gap
        root.position = SIMD3<Float>(center.x, center.y + extent.y / 2 + 0.06, center.z)
        entity.addChild(root)
        metricsLabelRoot = root
        refreshMetricsText()
    }

    private func refreshMetricsText() {
        guard let root = metricsLabelRoot else { return }
        root.children.forEach { $0.removeFromParent() }

        let lines: [String] = [
            label,
            String(format: "Dist: %.2f m",  currentDistance),
            String(format: "Freq: %.0f Hz", currentFrequency),
            String(format: "Pitch: %.0f Hz", currentFrequency)
        ]

        let fontSize:   CGFloat = 0.012   // small — readable up close, not overwhelming
        let lineHeight: Float   = 0.016
        var yOffset: Float = 0

        for line in lines.reversed() {
            guard let font = MeshResource.Font(name: "Helvetica", size: fontSize) else { continue }
            let mesh = MeshResource.generateText(
                line,
                extrusionDepth: 0.001,
                font: font,
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )

            var mat = UnlitMaterial()
            mat.color = .init(tint: yOffset == 0 ? UIColor.systemGreen : UIColor.white)

            let textEntity = ModelEntity(mesh: mesh, materials: [mat])
            let textWidth  = mesh.bounds.max.x - mesh.bounds.min.x
            textEntity.position = SIMD3<Float>(-textWidth / 2, yOffset, 0)
            root.addChild(textEntity)

            yOffset += lineHeight
        }
    }

    // MARK: - Audio (entity-based — RealityKit positions it in 3D automatically)

    private func frequencyForDistance(_ distance: Float) -> Double {
        let clamped    = min(max(distance, Self.minDistance), Self.maxDistance)
        let normalised = Double((clamped - Self.minDistance) / (Self.maxDistance - Self.minDistance))
        return Self.minFrequency + normalised * (Self.maxFrequency - Self.minFrequency)
    }

    private func scheduleNextBeep() {
        let freq    = frequencyForDistance(currentDistance)
        currentFrequency = freq

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let resource = try await self.audioResource(for: freq)
                self.audioPlaybackController = self.entity.playAudio(resource)
            } catch {
                print("Beep audio error: \(error)")
            }

            // 0.25 s gap between beeps — faster cadence than before
            self.beepTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                self?.scheduleNextBeep()
            }
        }
    }

    /// Returns a cached AudioFileResource for the given frequency, generating it if needed.
    private func audioResource(for frequency: Double) async throws -> AudioFileResource {
        let bucket = Int(frequency / Self.cacheBucketSize) * Int(Self.cacheBucketSize)

        if let cached = Self.audioCache[bucket] {
            return cached
        }

        let url      = try generateToneFile(frequency: frequency)
        let resource = try await AudioFileResource(contentsOf: url)
        Self.audioCache[bucket] = resource
        return resource
    }

    private func generateToneFile(frequency: Double) throws -> URL {
        let sampleRate = 44100.0
        let duration   = 0.12        // slightly shorter beep for snappier feel
        let frameCount = UInt32(duration * sampleRate)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioGen", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }
        buffer.frameLength = frameCount

        let omega = 2.0 * Double.pi * frequency / sampleRate
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / (sampleRate * duration)
            let env: Float
            if      t < 0.08 { env = Float(t / 0.08) }
            else if t > 0.75 { env = Float((1.0 - t) / 0.25) }
            else              { env = 1.0 }
            buffer.floatChannelData?[0][frame] = Float(sin(omega * Double(frame))) * 0.4 * env
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("beep_\(Int(frequency)).caf")
        try? FileManager.default.removeItem(at: url)

        let file = try AVAudioFile(forWriting: url,
                                   settings: format.settings,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        try file.write(from: buffer)
        return url
    }

    // MARK: - Update

    func update(with anchor: ObjectAnchor) {
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        self.position = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )
    }

    /// Called every ~50 ms from AppModel's listener loop
    func updateMetrics(distance: Float, listenerWorldPosition: SIMD3<Float>) {
        currentDistance = distance
        refreshMetricsText()
    }

    deinit {
        beepTimer?.invalidate()
        audioPlaybackController?.stop()
        print("Audio cleanup complete")
    }
}
