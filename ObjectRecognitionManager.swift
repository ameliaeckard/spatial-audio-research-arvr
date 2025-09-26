
import Foundation
import RealityKit
import ARKit
import SwiftUI
import Combine

@MainActor
@Observable
class ObjectRecognitionManager {
    var detectedObjects: [DetectedObject] = []
    var isDetectionActive = false
    
    private var arSession: ARSession?
    private var cancellables = Set<AnyCancellable>()
    
    func startObjectDetection() async {
        guard !isDetectionActive else { return }
        
        isDetectionActive = true
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        arSession = ARSession()
        arSession?.run(configuration)
        
        await startDetectionLoop()
    }
    
    func stopObjectDetection() {
        isDetectionActive = false
        arSession?.pause()
        detectedObjects.removeAll()
    }
    
    private func startDetectionLoop() async {
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.simulateObjectDetection()
                }
            }
            .store(in: &cancellables)
    }
    
    private func simulateObjectDetection() async {
        guard isDetectionActive else { return }
        
        let simulatedObject = DetectedObject(
            id: UUID(),
            type: .chair,
            position: SIMD3<Float>(0, 0, -2),
            orientation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            confidence: 0.85,
            boundingBox: BoundingBox(center: SIMD3<Float>(0, 0, -2), size: SIMD3<Float>(0.6, 1.2, 0.6))
        )
        
        if !detectedObjects.contains(where: { $0.id == simulatedObject.id }) {
            detectedObjects.append(simulatedObject)
            
            NotificationCenter.default.post(
                name: .objectDetected,
                object: simulatedObject
            )
        }
    }
}

// MARK: - Data Models

struct DetectedObject: Identifiable {
    let id: UUID
    let type: ObjectType
    let position: SIMD3<Float>
    let orientation: simd_quatf
    let confidence: Float
    let boundingBox: BoundingBox
    let timestamp = Date()
    
    var distanceFromUser: Float {
        return simd_length(position)
    }
}

enum ObjectType: String, CaseIterable {
    case chair = "chair"
    case table = "table"
    case door = "door"
    case stairs = "stairs"
    case sofa = "sofa"
    case desk = "desk"
    case window = "window"
    case plant = "plant"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

struct BoundingBox {
    let center: SIMD3<Float>
    let size: SIMD3<Float>
}

// MARK: - Notifications
extension Notification.Name {
    static let objectDetected = Notification.Name("objectDetected")
}
