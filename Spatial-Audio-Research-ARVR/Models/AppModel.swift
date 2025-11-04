//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  
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
    
    enum DetectionMode {
        case mock
        case yolo
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
    
    var detectionMode: DetectionMode = .mock
    var objectDetector: ObjectDetectionProtocol = CoreMLObjectDetector()
    var audioManager = SpatialAudioManager()
    var isDetecting = false
    var cvDetectedObjects: [DetectedObject] = []
    var boundingBoxes: [UUID: BoundingBoxEntity] = [:]
    var rootEntity: Entity?
    
    init() {
        print("Real-time detection")
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

    func startComputerVisionTracking() async {
        guard !isDetecting else { return }
        
        let worldTrackingProvider = WorldTrackingProvider()
        
        do {
            try await arkitSession.run([worldTrackingProvider])
            self.worldTrackingProvider = worldTrackingProvider
            print("World tracking running")
        } catch {
            print("Error: \(error)")
            return
        }
        
        while worldTrackingProvider.state != .running {
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        try? await Task.sleep(for: .milliseconds(500))
        
        isDetecting = true
        
        await processComputerVisionDetection()
    }
    
    private func processCameraFrames() async {
        // Not used in mock mode
    }
    
    private func processComputerVisionDetection() async {
        var frameCount = 0
        
        while isDetecting {
            frameCount += 1
            if frameCount % 2 != 0 {
                try? await Task.sleep(for: .milliseconds(50))
                continue
            }
            
            guard let provider = worldTrackingProvider,
                  provider.state == .running,
                  let deviceAnchor = provider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
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
            
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
    
    private func updateBoundingBoxes() {
        guard let rootEntity = rootEntity else { return }
        
        let currentObjectIds = Set(cvDetectedObjects.map { $0.id })
        
        for (id, box) in boundingBoxes where !currentObjectIds.contains(id) {
            box.removeFromParent()
            boundingBoxes.removeValue(forKey: id)
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
        guard isDetecting else { return }
        
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
