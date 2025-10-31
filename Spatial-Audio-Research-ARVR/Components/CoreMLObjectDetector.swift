//
//  CoreMLObjectDetector.swift
//  Spatial-Audio-Research-ARVR
//  Mock object detection for development/testing
//

import ARKit
import Vision
import RealityKit
import CoreML

@Observable
class CoreMLObjectDetector: ObjectDetectionProtocol {
    
    var detectedObjects: [DetectedObject] = []
    
    private var visionRequest: VNDetectRectanglesRequest?
    private let confidenceThreshold: Float = 0.4
    private var isProcessing = false
    private var currentDeviceAnchor: DeviceAnchor?
    private var detectionTimer: Timer?
    
    init() {
        setupVisionRequest()
        startMockDetection()
    }
    
    private func setupVisionRequest() {
        visionRequest = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Vision error: \(error.localizedDescription)")
                return
            }
            
            self.processVisionResults(request.results as? [VNRectangleObservation] ?? [])
        }
        
        visionRequest?.minimumConfidence = 0.5
        visionRequest?.maximumObservations = 3
    }
    
    private func startMockDetection() {
        Task {
            while true {
                try? await Task.sleep(for: .seconds(2))
                await generateMockDetection()
            }
        }
    }
    
    private func generateMockDetection() async {
        guard let deviceAnchor = currentDeviceAnchor else { return }
        
        let cameraTransform = deviceAnchor.originFromAnchorTransform
        var mockObjects: [DetectedObject] = []
        
        let shouldDetect = Bool.random()
        
        if shouldDetect {
            let angle = Float.random(in: -Float.pi/6...Float.pi/6)
            let distance = Float.random(in: 1.0...3.5)
            
            let direction = SIMD3<Float>(
                sin(angle),
                Float.random(in: -0.2...0.0),
                -cos(angle)
            )
            
            let cameraPos = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            
            let worldPos = cameraPos + normalize(direction) * distance
            
            let object = DetectedObject(
                label: "Water Bottle",
                confidence: Float.random(in: 0.7...0.95),
                worldPosition: worldPos,
                boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.4),
                distance: distance,
                direction: normalize(direction)
            )
            
            mockObjects.append(object)
        }
        
        await MainActor.run {
            self.detectedObjects = mockObjects
        }
    }
    
    func processARFrame(_ deviceAnchor: DeviceAnchor) {
        self.currentDeviceAnchor = deviceAnchor
    }
    
    func stop() {
        detectionTimer?.invalidate()
        detectionTimer = nil
        detectedObjects.removeAll()
    }
    
    private func processVisionResults(_ observations: [VNRectangleObservation]) {
        guard let deviceAnchor = currentDeviceAnchor else { return }
        
        let cameraTransform = deviceAnchor.originFromAnchorTransform
        var newObjects: [DetectedObject] = []
        
        for observation in observations {
            if let worldPos = convertToWorldPosition(
                boundingBox: observation.boundingBox,
                cameraTransform: cameraTransform
            ) {
                let cameraPos = SIMD3<Float>(
                    cameraTransform.columns.3.x,
                    cameraTransform.columns.3.y,
                    cameraTransform.columns.3.z
                )
                
                let distance = simd_distance(worldPos, cameraPos)
                let direction = normalize(worldPos - cameraPos)
                
                let object = DetectedObject(
                    label: "Water Bottle",
                    confidence: observation.confidence,
                    worldPosition: worldPos,
                    boundingBox: observation.boundingBox,
                    distance: distance,
                    direction: direction
                )
                
                newObjects.append(object)
            }
        }
        
        Task { @MainActor in
            self.detectedObjects = newObjects
        }
    }
    
    private func convertToWorldPosition(
        boundingBox: CGRect,
        cameraTransform: simd_float4x4
    ) -> SIMD3<Float>? {
        
        let centerX = Float(boundingBox.midX - 0.5) * 2.0
        let centerY = Float(0.5 - boundingBox.midY) * 2.0
        
        let estimatedDistance: Float = 2.0 / Float(boundingBox.height)
        let clampedDistance = min(max(estimatedDistance, 0.5), 5.0)
        
        let forward = SIMD3<Float>(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
        let right = SIMD3<Float>(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z)
        let up = SIMD3<Float>(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z)
        
        let direction = normalize(forward + right * centerX + up * centerY)
        
        let cameraPos = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        return cameraPos + direction * clampedDistance
    }
}
