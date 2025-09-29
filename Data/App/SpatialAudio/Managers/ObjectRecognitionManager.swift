//
//  ObjectRecognitionManager.swift
//  SpatialSight - Apple Vision Pro Research App
//

import Foundation
import ARKit
import RealityKit
import Combine
import SwiftUI

@MainActor
class ObjectRecognitionManager: ObservableObject {
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isScanning = false
    @Published var recognitionAccuracy: Double = 0.0
    @Published var lastDetectionTime: Date?
    @Published var sessionStats = SessionStats()
    
    private var arkitSession: ARKitSession?
    private var objectTrackingProvider: ObjectTrackingProvider?
    private var cancellables = Set<AnyCancellable>()
    private let confidenceThreshold: Float = 0.7
    
    private let targetObjectTypes: [ObjectType] = [
        .chair, .table, .door, .stairs, .sofa, .desk, .shelf, .cabinet, .window, .plant
    ]
    
    struct SessionStats {
        var totalDetections = 0
        var correctDetections = 0
        var averageConfidence: Float = 0.0
        var averageResponseTime: TimeInterval = 0.0
    }
    
    init() {
        setupARKit()
    }
    
    // MARK: - ARKit Setup
    private func setupARKit() {
        arkitSession = ARKitSession()
        objectTrackingProvider = ObjectTrackingProvider()
        
        Task {
            await requestWorldSensingAuthorization()
        }
    }
    
    private func requestWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession?.requestAuthorization(for: [.worldSensing])
        
        switch authorizationResult?[.worldSensing] {
        case .allowed:
            print("World sensing authorization granted")
        case .denied:
            print("World sensing authorization denied")
        case .notDetermined:
            print("World sensing authorization not determined")
        default:
            break
        }
    }
    
    // MARK: - Object Detection
    func startObjectDetection() async {
        guard let arkitSession = arkitSession,
              let objectTrackingProvider = objectTrackingProvider else {
            print("ARKit not properly initialized")
            return
        }
        
        isScanning = true
        sessionStats = SessionStats()
        
        do {
            try await arkitSession.run([objectTrackingProvider])
            
            // Start monitoring for object anchors
            for await update in objectTrackingProvider.anchorUpdates {
                await processObjectUpdate(update)
            }
        } catch {
            print("Failed to start ARKit session: \(error)")
            isScanning = false
        }
    }
    
    func stopObjectDetection() {
        arkitSession?.stop()
        isScanning = false
    }
    
    private func processObjectUpdate(_ update: AnchorUpdate<ObjectAnchor>) async {
        let objectAnchor = update.anchor
        
        switch update.event {
        case .added:
            await handleObjectDetected(objectAnchor)
        case .updated:
            await handleObjectUpdated(objectAnchor)
        case .removed:
            await handleObjectRemoved(objectAnchor)
        }
    }
    
    private func handleObjectDetected(_ anchor: ObjectAnchor) async {
        let detectedObject = DetectedObject(
            id: anchor.id,
            type: classifyObject(from: anchor),
            confidence: Float.random(in: 0.7...0.95), // Simulated confidence
            position: anchor.originFromAnchorTransform.translation,
            orientation: anchor.originFromAnchorTransform.rotation,
            detectionTime: Date()
        )
        
        detectedObjects.append(detectedObject)
        sessionStats.totalDetections += 1
        lastDetectionTime = Date()
        
        // Update accuracy metrics
        updateAccuracyMetrics()
        
        // Provide immediate feedback for accessibility
        await provideFeedback(for: detectedObject)
    }
    
    private func handleObjectUpdated(_ anchor: ObjectAnchor) async {
        guard let index = detectedObjects.firstIndex(where: { $0.id == anchor.id }) else { return }
        
        detectedObjects[index].position = anchor.originFromAnchorTransform.translation
        detectedObjects[index].orientation = anchor.originFromAnchorTransform.rotation
        detectedObjects[index].lastUpdateTime = Date()
    }
    
    private func handleObjectRemoved(_ anchor: ObjectAnchor) async {
        detectedObjects.removeAll { $0.id == anchor.id }
    }
    
    // MARK: - Object Classification
    private func classifyObject(from anchor: ObjectAnchor) -> ObjectType {
        // In a real implementation, this would use machine learning models
        // For research purposes, we'll simulate classification based on reference objects
        
        // This would typically involve:
        // 1. Analyzing the geometry of the detected object
        // 2. Comparing against trained models for common indoor objects
        // 3. Returning the most likely classification with confidence score
        
        return targetObjectTypes.randomElement() ?? .unknown
    }
    
    // MARK: - Accuracy Metrics
    private func updateAccuracyMetrics() {
        let recentDetections = detectedObjects.suffix(10) // Last 10 detections
        let highConfidenceDetections = recentDetections.filter { $0.confidence > confidenceThreshold }
        
        recognitionAccuracy = Double(highConfidenceDetections.count) / Double(recentDetections.count)
        
        sessionStats.correctDetections = highConfidenceDetections.count
        sessionStats.averageConfidence = recentDetections.map { $0.confidence }.reduce(0, +) / Float(recentDetections.count)
    }
    
    // MARK: - Feedback System
    private func provideFeedback(for object: DetectedObject) async {
        // This will trigger spatial audio feedback
        NotificationCenter.default.post(
            name: .objectDetected,
            object: object
        )
    }
    
    // MARK: - Navigation Assistance
    func getNavigationGuidance(to targetType: ObjectType) -> NavigationGuidance? {
        guard let targetObject = detectedObjects.first(where: { $0.type == targetType }) else {
            return nil
        }
        
        let distance = calculateDistance(to: targetObject.position)
        let direction = calculateDirection(to: targetObject.position)
        
        return NavigationGuidance(
            targetObject: targetObject,
            distance: distance,
            direction: direction,
            instructions: generateNavigationInstructions(for: targetObject, distance: distance, direction: direction)
        )
    }
    
    private func calculateDistance(to position: SIMD3<Float>) -> Float {
        // Simplified distance calculation - in reality would use device position
        return sqrt(position.x * position.x + position.z * position.z)
    }
    
    private func calculateDirection(to position: SIMD3<Float>) -> Float {
        // Return angle in degrees (0 = straight ahead, positive = right, negative = left)
        return atan2(position.x, -position.z) * 180 / .pi
    }
    
    private func generateNavigationInstructions(for object: DetectedObject, distance: Float, direction: Float) -> String {
        let distanceText = distance < 1.0 ? "very close" : distance < 3.0 ? "\(Int(distance)) meters away" : "far away"
        let directionText = abs(direction) < 15 ? "straight ahead" :
                           direction > 0 ? "\(Int(direction)) degrees to your right" :
                           "\(Int(-direction)) degrees to your left"
        
        return "\(object.type.displayName) is \(distanceText), \(directionText)"
    }
}

// MARK: - Models
struct DetectedObject: Identifiable, Codable {
    let id: UUID
    let type: ObjectType
    var confidence: Float
    var position: SIMD3<Float>
    var orientation: simd_quatf
    let detectionTime: Date
    var lastUpdateTime: Date?
    
    var distanceFromUser: Float {
        return sqrt(position.x * position.x + position.z * position.z)
    }
    
    var audioFrequency: Float {
        // Assign different frequencies based on object type for spatial audio
        switch type {
        case .chair, .sofa: return 440.0  // A4 note
        case .table, .desk: return 330.0  // E4 note
        case .door: return 220.0          // A3 note
        case .stairs: return 150.0        // Low frequency for safety
        case .window: return 523.0        // C5 note
        default: return 350.0             // Default frequency
        }
    }
}

enum ObjectType: String, CaseIterable, Codable {
    case chair = "chair"
    case table = "table"
    case door = "door"
    case stairs = "stairs"
    case sofa = "sofa"
    case desk = "desk"
    case shelf = "shelf"
    case cabinet = "cabinet"
    case window = "window"
    case plant = "plant"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .chair: return "Chair"
        case .table: return "Table"
        case .door: return "Door"
        case .stairs: return "Stairs"
        case .sofa: return "Sofa"
        case .desk: return "Desk"
        case .shelf: return "Shelf"
        case .cabinet: return "Cabinet"
        case .window: return "Window"
        case .plant: return "Plant"
        case .unknown: return "Unknown Object"
        }
    }
    
    var iconName: String {
        switch self {
        case .chair: return "chair.fill"
        case .table: return "table.furniture.fill"
        case .door: return "door.left.hand.open"
        case .stairs: return "stairs"
        case .sofa: return "sofa.fill"
        case .desk: return "desk.fill"
        case .shelf: return "shelf.leading.inset.filled"
        case .cabinet: return "cabinet.fill"
        case .window: return "window.vertical.open"
        case .plant: return "leaf.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct NavigationGuidance {
    let targetObject: DetectedObject
    let distance: Float
    let direction: Float
    let instructions: String
}

// MARK: - Notifications
extension Notification.Name {
    static let objectDetected = Notification.Name("objectDetected")
    static let navigationGuidanceUpdated = Notification.Name("navigationGuidanceUpdated")
}

// MARK: - Extensions
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
    
    var rotation: simd_quatf {
        return simd_quatf(self)
    }
}
