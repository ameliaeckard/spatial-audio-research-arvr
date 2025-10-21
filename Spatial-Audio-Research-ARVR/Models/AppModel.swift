//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//  Merged by Amelia Eckard on 10/21/25.
//

import ARKit
import RealityKit
import SwiftUI

@MainActor
@Observable
class AppModel {
    // MARK: - Enums
    
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
    }
    
    // MARK: - Published Properties
    
    var immersiveSpaceState = ImmersiveSpaceState.closed {
        didSet {
            guard immersiveSpaceState == .closed else { return }
            arkitSession.stop()
            selectedObject = nil
            objectVisualizations.removeAll()
            detectedObjects.removeAll()
        }
    }
    
    var selectedObject: DetectionObject? = nil
    var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    var providersStoppedWithError = false
    var detectedObjects: [DetectionObject: Bool] = [:]
    
    // MARK: - Authorization & Provider Status
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }
    
    var allRequiredProvidersAreSupported: Bool {
        HandTrackingProvider.isSupported && ObjectTrackingProvider.isSupported
    }
    
    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }
    
    var isReadyToRun: Bool {
        handTrackingProvider?.state == .initialized && objectTrackingProvider?.state == .initialized
    }
    
    // MARK: - Private Properties
    
    private var arkitSession = ARKitSession()
    private var handTrackingProvider: HandTrackingProvider?
    private var objectTrackingProvider: ObjectTrackingProvider?
    private var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    private var hasLoadedReferenceObjects = false
    
    let referenceObjectLoader = ReferenceObjectLoader()
    
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
    
    // MARK: - Object Tracking
    
    func startTracking(with rootEntity: Entity) async {
        // Load reference objects if not already loaded
        if !hasLoadedReferenceObjects && allRequiredProvidersAreSupported {
            await referenceObjectLoader.loadReferenceObjects()
            hasLoadedReferenceObjects = true
        }
        
        let referenceObjects = referenceObjectLoader.referenceObjects
        
        guard !referenceObjects.isEmpty else {
            print("No reference objects found to start tracking")
            return
        }
        
        let objectTrackingProvider = ObjectTrackingProvider(referenceObjects: referenceObjects)
        let handTrackingProvider = HandTrackingProvider()
        
        do {
            try await arkitSession.run([objectTrackingProvider, handTrackingProvider])
        } catch {
            print("Error running arkitSession: \(error)")
            return
        }
        
        self.handTrackingProvider = handTrackingProvider
        self.objectTrackingProvider = objectTrackingProvider
        
        Task {
            await processHandUpdates()
        }
        
        Task {
            await processObjectUpdates(with: rootEntity)
        }
    }
    
    // MARK: - Private Methods
    
    private func processHandUpdates() async {
        guard let handTrackingProvider else {
            print("Error obtaining handTrackingProvider upon processHandUpdates")
            return
        }
        
        for await update in handTrackingProvider.anchorUpdates {
            let handAnchor = update.anchor
            
            // Hand tracking logic for spatial audio manipulation
            for (_, visualization) in objectVisualizations {
                guard let modelEntity = visualization.entity.findEntity(named: Constants.objectCaptureMeshName) as? ModelEntity
                else {
                    continue
                }
                
                // Check if hand is near detected object
                if let (_, distance) = handAnchor.nearestFingerDistance(to: modelEntity) {
                    // This is where you could trigger spatial audio cues based on proximity
                    if distance < Constants.maximumInteractionDistance {
                        // Trigger spatial audio feedback here
                        print("Hand \(handAnchor.chirality == .left ? "left" : "right") near \(visualization.objectName ?? "unknown") at distance: \(distance)m")
                    }
                }
            }
        }
    }
    
    private func processObjectUpdates(with rootEntity: Entity) async {
        guard let objectTrackingProvider else {
            print("Error obtaining objectTrackingProvider upon processObjectUpdates")
            return
        }
        
        for await anchorUpdate in objectTrackingProvider.anchorUpdates {
            let anchor = anchorUpdate.anchor
            let id = anchor.id
            
            switch anchorUpdate.event {
            case .added:
                // Create visualization for detected object
                let model: Entity? = referenceObjectLoader.usdzsPerReferenceObjectID[anchor.referenceObject.id]
                let visualization = await ObjectAnchorVisualization(for: anchor, withModel: model)
                objectVisualizations[id] = visualization
                rootEntity.addChild(visualization.entity)
                
                // Update detected objects dictionary
                if let objectName = visualization.objectName,
                   let detectedObject = DetectionObject.allCases.first(where: { $0.rawValue == objectName }) {
                    detectedObjects[detectedObject] = true
                    
                    // Trigger spatial audio cue for detection
                    print("✓ Detected: \(objectName)")
                }
                
            case .updated:
                objectVisualizations[id]?.update(with: anchor)
                
            case .removed:
                // Update detected objects dictionary
                if let objectName = objectVisualizations[id]?.objectName,
                   let detectedObject = DetectionObject.allCases.first(where: { $0.rawValue == objectName }) {
                    detectedObjects[detectedObject] = false
                    print("✗ Lost tracking: \(objectName)")
                }
                
                objectVisualizations[id]?.entity.removeFromParent()
                objectVisualizations.removeValue(forKey: id)
            }
        }
    }
}