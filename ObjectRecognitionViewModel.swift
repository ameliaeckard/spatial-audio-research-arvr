import SwiftUI
import RealityKit
import ARKit
import Combine

class ObjectRecognitionViewModel: ObservableObject {
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isAudioEnabled: Bool = true
    
    var arView: ARView?
    private var spatialAudioManager: SpatialAudioManager?
    private var lastProcessTime: Date = Date()
    private let processInterval: TimeInterval = 0.5 // Process every 0.5 seconds
    
    // Common indoor objects to detect (simplified for basic version)
    private let targetObjects = ["chair", "table", "door", "cup", "bottle", "laptop"]
    
    init() {
        spatialAudioManager = SpatialAudioManager()
    }
    
    func processFrame(_ frame: ARFrame) {
        // Throttle processing
        guard Date().timeIntervalSince(lastProcessTime) >= processInterval else { return }
        lastProcessTime = Date()
        
        // Get camera transform
        let cameraTransform = frame.camera.transform
        
        // In a real implementation, you would use Vision framework for object detection
        // For this basic version, we'll detect planes and create mock objects
        detectPlanesAndObjects(frame: frame, cameraTransform: cameraTransform)
    }
    
    private func detectPlanesAndObjects(frame: ARFrame, cameraTransform: simd_float4x4) {
        guard let arView = arView else { return }
        
        var newDetectedObjects: [DetectedObject] = []
        
        // Get all anchors
        for anchor in frame.anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // Create mock objects on detected planes
                let planePosition = planeAnchor.transform.columns.3
                let objectPosition = SIMD3<Float>(planePosition.x, planePosition.y, planePosition.z)
                
                // Calculate distance and direction from camera
                let cameraPosition = SIMD3<Float>(
                    cameraTransform.columns.3.x,
                    cameraTransform.columns.3.y,
                    cameraTransform.columns.3.z
                )
                
                let directionVector = objectPosition - cameraPosition
                let distance = length(directionVector)
                let normalizedDirection = normalize(directionVector)
                
                // Only include objects within reasonable range (0.5m to 5m)
                if distance > 0.5 && distance < 5.0 {
                    // Assign a mock object type based on plane characteristics
                    let objectName = determineMockObjectType(for: planeAnchor)
                    
                    let detectedObject = DetectedObject(
                        name: objectName,
                        position: objectPosition,
                        distance: distance,
                        direction: normalizedDirection,
                        timestamp: Date()
                    )
                    
                    newDetectedObjects.append(detectedObject)
                }
            }
        }
        
        // Update detected objects
        DispatchQueue.main.async {
            self.detectedObjects = newDetectedObjects
            
            // Trigger spatial audio feedback
            if self.isAudioEnabled {
                self.spatialAudioManager?.updateAudioForObjects(newDetectedObjects)
            }
        }
    }
    
    private func determineMockObjectType(for planeAnchor: ARPlaneAnchor) -> String {
        // Simple heuristic based on plane orientation and size
        if planeAnchor.alignment == .horizontal {
            // Horizontal planes could be tables or floor
            if planeAnchor.planeExtent.width > 0.5 {
                return "table"
            }
            return "surface"
        } else {
            // Vertical planes could be walls or doors
            return "wall"
        }
    }
    
    func toggleAudioFeedback() {
        isAudioEnabled.toggle()
        if !isAudioEnabled {
            spatialAudioManager?.stopAllAudio()
        }
    }
    
    func announceObjects() {
        guard !detectedObjects.isEmpty else {
            spatialAudioManager?.speak("No objects detected")
            return
        }
        
        let sortedObjects = detectedObjects.sorted { $0.distance < $1.distance }
        let announcement = sortedObjects.prefix(3).map { obj in
            "\(obj.name) at \(String(format: "%.1f", obj.distance)) meters"
        }.joined(separator: ", ")
        
        spatialAudioManager?.speak("Detected: \(announcement)")
    }
}
