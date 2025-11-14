//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/14/25.
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
    
    private let audioManager = SpatialAudioManager()
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
              let rootEntity = rootEntity else {
            print("Missing provider or root entity")
            return
        }
        
        for await anchorUpdate in objectTrackingProvider.anchorUpdates {
            let anchor = anchorUpdate.anchor
            let objectName = anchor.referenceObject.name
            
            switch anchorUpdate.event {
            case .added:
                print("Object detected: \(objectName)")
                
                if let oldViz = currentVisualization {
                    oldViz.entity.removeFromParent()
                    print("Removed previous visualization")
                }
                
                let visualization = ObjectAnchorVisualization(for: anchor)
                currentVisualization = visualization
                rootEntity.addChild(visualization.entity)
                print("Created visualization for \(objectName)")
                
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
        
        while isTracking {
            guard let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                try? await Task.sleep(for: .milliseconds(50))
                continue
            }
            
            let transform = deviceAnchor.originFromAnchorTransform
            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            let rotation = simd_quatf(transform)
            
            audioManager.updateAudioForObjects(
                trackedObjects,
                listenerPosition: position,
                listenerOrientation: rotation
            )
            
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
        
        audioManager.stop()
        
        print("Object tracking stopped and cleaned up")
    }
}

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
        
        let mesh = MeshResource.generateBox(size: [0.15, 0.15, 0.15])
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
