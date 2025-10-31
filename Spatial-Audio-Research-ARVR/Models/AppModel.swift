//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/28/25.
//
//  Handles the app's model data and state using Swift's Observable feature.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
@Observable
class AppModel {
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    enum DetectionMode {
        case mock  // For development/testing without model
        case yolo  // For real object detection with YOLO
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
    }
    
    var immersiveSpaceState = ImmersiveSpaceState.closed {
        didSet {
            guard immersiveSpaceState == .closed else { return }
            arkitSession.stop()
            selectedObject = nil
            detectedObjects.removeAll()
            stopComputerVisionDetection()
        }
    }
    
    var selectedObject: DetectionObject? = nil
    var providersStoppedWithError = false
    var detectedObjects: [DetectionObject: Bool] = [:]
    
    // Detection mode configuration
    var detectionMode: DetectionMode = .mock  // Change to .yolo when model is ready
    var objectDetector: ObjectDetectionProtocol = CoreMLObjectDetector()
    var audioManager = SpatialAudioManager()
    var isDetecting = false
    var cvDetectedObjects: [DetectedObject] = []
    var boundingBoxes: [UUID: BoundingBoxEntity] = [:]
    var rootEntity: Entity?
    
    // Initialize with selected detection mode
    init() {
        switchDetectionMode(to: detectionMode)
    }
    
    // Switch between detection modes
    func switchDetectionMode(to mode: DetectionMode) {
        objectDetector.stop()
        
        switch mode {
        case .mock:
            objectDetector = CoreMLObjectDetector()
            print("🔄 Switched to MOCK detection mode")
        case .yolo:
            objectDetector = YOLOObjectDetector()
            print("🔄 Switched to YOLO detection mode")
        }
        
        detectionMode = mode
        cvDetectedObjects.removeAll()
    }
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }
    
    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported
    }
    
    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }
    
    var isReadyToRun: Bool {
        worldTrackingProvider?.state == .running
    }
    
    private var arkitSession = ARKitSession()
    private var worldTrackingProvider: WorldTrackingProvider?
    private var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                switch newState {
                case .initialized, .running, .paused:
                    break
                case .stopped:
                    if let error {
                        print("An ARKitSession error occurred: \(error)")
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
                print("An unknown ARKitSession event occurred")
            }
        }
    }
    
    func queryWorldSensingAuthorization() async {
        let authorizationQuery = await arkitSession.queryAuthorization(for: [.worldSensing])
        
        guard let authorizationResult = authorizationQuery[.worldSensing] else {
            print("Failed to obtain .worldSensing authorization query result")
            return
        }
        
        worldSensingAuthorizationStatus = authorizationResult
    }
    
    func requestWorldSensingAuthorization() async {
        let authorizationRequest = await arkitSession.requestAuthorization(for: [.worldSensing])
        
        guard let authorizationResult = authorizationRequest[.worldSensing] else {
            print("Failed to obtain .worldSensing authorization request result")
            return
        }
        
        worldSensingAuthorizationStatus = authorizationResult
    }

    func startComputerVisionTracking() async {
        guard !isDetecting else { return }
        
        let worldTrackingProvider = WorldTrackingProvider()
        
        do {
            try await arkitSession.run([worldTrackingProvider])
            self.worldTrackingProvider = worldTrackingProvider
            print("WorldTrackingProvider started successfully")
        } catch {
            print("Error running arkitSession: \(error)")
            return
        }
        
        while worldTrackingProvider.state != .running {
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        isDetecting = true
        
        await processComputerVisionDetection()
    }
    
    private func processComputerVisionDetection() async {
        while isDetecting {
            guard let deviceAnchor = worldTrackingProvider?.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            
            objectDetector.processARFrame(deviceAnchor)
            
            let cameraTransform = deviceAnchor.originFromAnchorTransform
            let cameraPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            
            let rotation = simd_quatf(cameraTransform)
            
            await MainActor.run {
                self.cvDetectedObjects = objectDetector.detectedObjects
                self.updateDetectionStatus()
                self.updateBoundingBoxes()
            }
            
            audioManager.updateAudioForObjects(
                objectDetector.detectedObjects,
                listenerPosition: cameraPosition,
                listenerOrientation: rotation
            )
            
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    
    private func updateBoundingBoxes() {
        guard let rootEntity = rootEntity else { return }
        
        let currentObjectIds = Set(cvDetectedObjects.map { $0.id })
        
        for (id, box) in boundingBoxes {
            if !currentObjectIds.contains(id) {
                box.removeFromParent()
                boundingBoxes.removeValue(forKey: id)
            }
        }
        
        for object in cvDetectedObjects {
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
            let isDetected = cvDetectedObjects.contains { detected in
                detected.label.lowercased().contains(object.rawValue.lowercased()) ||
                object.rawValue.lowercased().contains(detected.label.lowercased())
            }
            detectedObjects[object] = isDetected
        }
    }
    
    func stopComputerVisionDetection() {
        isDetecting = false
        objectDetector.stop()
        audioManager.stop()
        cvDetectedObjects.removeAll()
        
        for (_, box) in boundingBoxes {
            box.removeFromParent()
        }
        boundingBoxes.removeAll()
    }
}
