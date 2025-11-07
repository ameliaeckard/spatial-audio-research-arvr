//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/6/25.
//
//  Uses ObjectTrackingProvider for visionOS compatibility
//

import ARKit
import RealityKit
import SwiftUI
import QuartzCore

@MainActor
@Observable
class AppModel {
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    enum DetectionObject: String, CaseIterable {
        case mug = "Mug"
        case waterBottle = "Water Bottle"
        case chair = "Chair"

        var icon: String {
            switch self {
            case .mug: return "cup.and.saucer.fill"
            case .waterBottle: return "waterbottle.fill"
            case .chair: return "chair.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .mug: return .brown
            case .waterBottle: return .blue
            case .chair: return .orange
            }
        }
        
        // Expected names for .arobject files
        var referenceObjectName: String {
            switch self {
            case .mug: return "mug"
            case .waterBottle: return "water_bottle"
            case .chair: return "chair"
            }
        }
    }
    
    // MARK: - State Properties
    
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
    
    // Object tracking
    var audioManager = SpatialAudioManager()
    var isTracking = false
    var trackedObjects: [DetectedObject] = []
    var boundingBoxes: [UUID: BoundingBoxEntity] = [:]
    var rootEntity: Entity?
    var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    
    // Reference objects
    private let referenceObjectLoader = ReferenceObjectLoader()
    
    // MARK: - Computed Properties
    
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
    
    // MARK: - Private Properties
    
    private var arkitSession = ARKitSession()
    private var objectTrackingProvider: ObjectTrackingProvider?
    private var worldTrackingProvider: WorldTrackingProvider?
    private var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    // MARK: - Initialization
    
    init() {
        print("Object Tracking initialized")
    }
    
    // MARK: - Session Management
    
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
    
    // MARK: - Object Tracking
    
    func startObjectTracking() async {
        guard !isTracking else { return }
        
        // Load reference objects first
        await referenceObjectLoader.loadReferenceObjects()
        
        let referenceObjects = referenceObjectLoader.referenceObjects
        
        // Check if we have reference objects
        if referenceObjects.isEmpty {
            print("No reference objects available - cannot start tracking")
            print("Add .arobject files to your project to enable detection")
            return
        }
        
        print("🔍 Starting object tracking with \(referenceObjects.count) reference object(s)")
        
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
        
        // Wait for provider to be ready
        while objectTrackingProvider.state != .running {
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        print("Object tracking active")
        isTracking = true
        
        // Start processing loops
        Task {
            await processObjectUpdates()
        }
        
        Task {
            await updateAudioLoop()
        }
    }
    
    private func processObjectUpdates() async {
        guard let objectTrackingProvider = objectTrackingProvider,
              let rootEntity = rootEntity else {
            print("Missing provider or root entity")
            return
        }
        
        for await anchorUpdate in objectTrackingProvider.anchorUpdates {
            let anchor = anchorUpdate.anchor
            let id = anchor.id
            
            switch anchorUpdate.event {
            case .added:
                let objectName = anchor.referenceObject.name
                print("Object detected: \(objectName)")
                
                // Create visualization
                let visualization = ObjectAnchorVisualization(for: anchor)
                objectVisualizations[id] = visualization
                rootEntity.addChild(visualization.entity)
                
                // Update tracked objects list
                updateTrackedObjectsList()
                
            case .updated:
                objectVisualizations[id]?.update(with: anchor)
                updateTrackedObjectsList()
                
            case .removed:
                let objectName = anchor.referenceObject.name
                print("Object lost: \(objectName)")
                objectVisualizations[id]?.entity.removeFromParent()
                objectVisualizations.removeValue(forKey: id)
                updateTrackedObjectsList()
            }
        }
    }
    
    private func updateTrackedObjectsList() {
        guard let worldTrackingProvider = worldTrackingProvider,
              let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return
        }
        
        let cameraTransform = deviceAnchor.originFromAnchorTransform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        var newTrackedObjects: [DetectedObject] = []
        
        for (_, visualization) in objectVisualizations {
            let objectPosition = visualization.position
            let distance = simd_distance(objectPosition, cameraPosition)
            let direction = normalize(objectPosition - cameraPosition)
            
            let label = visualization.label
            
            let detectedObject = DetectedObject(
                label: label,
                confidence: 1.0, // ObjectTracking is always confident when it finds a match
                worldPosition: objectPosition,
                boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
                distance: distance,
                direction: direction
            )
            
            newTrackedObjects.append(detectedObject)
        }
        
        trackedObjects = newTrackedObjects
        updateDetectionStatus()
        updateBoundingBoxes()
    }
    
    private func updateAudioLoop() async {
        while isTracking {
            guard let worldTrackingProvider = worldTrackingProvider,
                  let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            
            let cameraTransform = deviceAnchor.originFromAnchorTransform
            let cameraPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            
            let rotation = simd_quatf(cameraTransform)
            
            audioManager.updateAudioForObjects(
                trackedObjects,
                listenerPosition: cameraPosition,
                listenerOrientation: rotation
            )
            
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
    
    private func updateBoundingBoxes() {
        guard let rootEntity = rootEntity else { return }
        
        let currentObjectIds = Set(trackedObjects.map { $0.id })
        
        // Remove old boxes
        for (id, box) in boundingBoxes where !currentObjectIds.contains(id) {
            box.removeFromParent()
            boundingBoxes.removeValue(forKey: id)
        }
        
        // Update or create boxes
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
        audioManager.stop()
        trackedObjects.removeAll()
        
        // Clean up bounding boxes
        for (_, box) in boundingBoxes {
            box.removeFromParent()
        }
        boundingBoxes.removeAll()
        
        // Clean up visualizations
        for (_, visualization) in objectVisualizations {
            visualization.entity.removeFromParent()
        }
        objectVisualizations.removeAll()
    }
}

// MARK: - Object Anchor Visualization

class ObjectAnchorVisualization {
    let entity: Entity
    let label: String
    var position: SIMD3<Float>
    
    init(for anchor: ObjectAnchor) {
        self.entity = Entity()
        self.label = anchor.referenceObject.name
        self.position = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        
        // Create wireframe visualization
        let mesh = MeshResource.generateBox(size: [0.3, 0.3, 0.3])
        var material = UnlitMaterial()
        material.color = .init(tint: .cyan.withAlphaComponent(0.5))
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        entity.addChild(modelEntity)
    }
    
    func update(with anchor: ObjectAnchor) {
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        
        self.position = SIMD3<Float>(
            anchor.originFromAnchorTransform.columns.3.x,
            anchor.originFromAnchorTransform.columns.3.y,
            anchor.originFromAnchorTransform.columns.3.z
        )
    }
}
