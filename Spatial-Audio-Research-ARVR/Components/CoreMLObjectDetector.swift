//
//  CoreMLObjectDetector.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  Simulates realistic object detection for testing
//

import ARKit
import Vision
import RealityKit
import CoreML

@Observable
class CoreMLObjectDetector: ObjectDetectionProtocol {
    
    var detectedObjects: [DetectedObject] = []
    
    private var isProcessing = false
    private var currentDeviceAnchor: DeviceAnchor?
    private var detectionCycle = 0
    
    init() {
        print("🎯 Mock detector initialized - simulating object detection")
    }
    
    func processARFrame(_ deviceAnchor: DeviceAnchor) {
        self.currentDeviceAnchor = deviceAnchor
        
        // Simulate detection every 10 frames
        detectionCycle += 1
        if detectionCycle % 10 == 0 {
            Task {
                await generateRealisticDetection()
            }
        }
    }
    
    private func generateRealisticDetection() async {
        guard let deviceAnchor = currentDeviceAnchor else { return }
        
        let cameraTransform = deviceAnchor.originFromAnchorTransform
        let cameraPos = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // Get camera forward direction
        let forward = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
        
        var mockObjects: [DetectedObject] = []
        
        // Simulate 1-3 objects in front of the camera
        let numObjects = Int.random(in: 1...3)
        
        let objectTypes = ["Mug", "Water Bottle", "Chair"]
        
        for i in 0..<numObjects {
            // Place objects at realistic positions
            let distance = Float.random(in: 1.0...3.0)
            let horizontalOffset = Float.random(in: -0.5...0.5)
            let verticalOffset = Float.random(in: -0.2...0.2)
            
            // Calculate world position
            let right = SIMD3<Float>(
                cameraTransform.columns.0.x,
                cameraTransform.columns.0.y,
                cameraTransform.columns.0.z
            )
            let up = SIMD3<Float>(
                cameraTransform.columns.1.x,
                cameraTransform.columns.1.y,
                cameraTransform.columns.1.z
            )
            
            let direction = normalize(forward + right * horizontalOffset + up * verticalOffset)
            let worldPos = cameraPos + direction * distance
            
            // Random object type
            let objectType = objectTypes[i % objectTypes.count]
            
            let object = DetectedObject(
                label: objectType,
                confidence: Float.random(in: 0.75...0.95),
                worldPosition: worldPos,
                boundingBox: CGRect(
                    x: 0.3 + Double(horizontalOffset) * 0.2,
                    y: 0.3 + Double(verticalOffset) * 0.2,
                    width: 0.2,
                    height: 0.3
                ),
                distance: distance,
                direction: direction
            )
            
            mockObjects.append(object)
        }
        
        await MainActor.run {
            self.detectedObjects = mockObjects
            if !mockObjects.isEmpty {
                print("Mock detection: \(mockObjects.count) objects")
                for obj in mockObjects {
                    print("   - \(obj.label) at \(String(format: "%.1fm", obj.distance))")
                }
            }
        }
    }
    
    func stop() {
        detectedObjects.removeAll()
        detectionCycle = 0
        print("Mock detector stopped")
    }
}
