import Foundation
import ARKit
import RealityKit
import Vision
import CoreML
import simd

@MainActor
class ObjectDetector: ObservableObject {
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isProcessing: Bool = false
    
    private var lastProcessTime: Date = Date()
    private let processInterval: TimeInterval = 0.5
    
    private var objectDetectionRequest: VNCoreMLRequest?
    
    private let supportedObjects = [
        "chair", "table", "door", "cup", "bottle", 
        "laptop", "keyboard", "mouse", "phone", "book"
    ]
    
    init() {
        setupObjectDetection()
    }
    
    private func setupObjectDetection() {

        // Example with a hypothetical model:
        // guard let model = try? VNCoreMLModel(for: YourObjectDetectionModel().model) else {
        //     print("Failed to load Core ML model")
        //     return
        // }
        
        // objectDetectionRequest = VNCoreMLRequest(model: model) { [weak self] request, error in
        //     self?.processDetections(request: request, error: error)
        // }
    }

    func processARFrame(_ frame: ARFrame, with worldTracking: simd_float4x4) {
        guard Date().timeIntervalSince(lastProcessTime) >= processInterval else { return }
        lastProcessTime = Date()
        
        guard !isProcessing else { return }
        isProcessing = true
        
        let pixelBuffer = frame.capturedImage
        
        detectObjects(in: pixelBuffer, cameraTransform: worldTracking)
    }
    
    private func detectObjects(in pixelBuffer: CVPixelBuffer, cameraTransform: simd_float4x4) {

        /*
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        guard let request = objectDetectionRequest else {
            isProcessing = false
            return
        }
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform detection: \(error)")
            isProcessing = false
        }
        */
        
        simulateObjectDetection(cameraTransform: cameraTransform)
    }
    
    private func processDetections(request: VNRequest, error: Error?) {
        guard error == nil else {
            print("Detection error: \(error!.localizedDescription)")
            isProcessing = false
            return
        }
        
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            isProcessing = false
            return
        }
        
        var newDetections: [DetectedObject] = []
        
        for observation in results {
            guard let topLabel = observation.labels.first else { continue }
            
            let objectName = topLabel.identifier.lowercased()
            guard supportedObjects.contains(objectName) else { continue }
            
            let position = estimate3DPosition(from: observation.boundingBox)
            
            let detectedObject = DetectedObject(
                name: objectName,
                position: position,
                confidence: topLabel.confidence,
                timestamp: Date()
            )
            
            newDetections.append(detectedObject)
        }
        
        detectedObjects = newDetections
        isProcessing = false
    }
    
    private func estimate3DPosition(from boundingBox: CGRect) -> SIMD3<Float> {
        
        // 1. Getting the center of the bounding box
        // 2. Raycasting from camera through that point
        // 3. Using depth map or scene reconstruction
        // 4. Returning world position
        
        // Placeholder implementation
        let centerX = Float(boundingBox.midX - 0.5) * 2.0 // -1 to 1
        let centerY = Float(0.5 - boundingBox.midY) * 2.0 // -1 to 1
        let estimatedDepth: Float = 2.0
        
        return SIMD3<Float>(
            centerX * estimatedDepth,
            centerY * estimatedDepth,
            -estimatedDepth
        )
    }
    
    private func simulateObjectDetection(cameraTransform: simd_float4x4) {
        
        let mockObjects: [DetectedObject] = [
            DetectedObject(
                name: "table",
                position: SIMD3<Float>(0.5, 0.7, -2.0),
                confidence: 0.92,
                timestamp: Date()
            ),
            DetectedObject(
                name: "chair",
                position: SIMD3<Float>(-1.0, 0.5, -2.5),
                confidence: 0.88,
                timestamp: Date()
            ),
            DetectedObject(
                name: "cup",
                position: SIMD3<Float>(0.3, 0.8, -1.8),
                confidence: 0.95,
                timestamp: Date()
            ),
            DetectedObject(
                name: "laptop",
                position: SIMD3<Float>(0.2, 0.75, -2.1),
                confidence: 0.90,
                timestamp: Date()
            )
        ]
        
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        detectedObjects = mockObjects.filter { object in
            let distance = object.distance(from: cameraPosition)
            return distance > 0.5 && distance < 5.0
        }
        
        isProcessing = false
    }
    
    func setMockObjects(_ objects: [DetectedObject]) {
        detectedObjects = objects
    }
    
    func clearDetections() {
        detectedObjects.removeAll()
    }
    
    func findNearest(objectType: String) -> DetectedObject? {
        detectedObjects
            .filter { $0.name.lowercased() == objectType.lowercased() }
            .min(by: { $0.distance() < $1.distance() })
    }
    
    func countObjects(ofType type: String) -> Int {
        detectedObjects.filter { $0.name.lowercased() == type.lowercased() }.count
    }
}