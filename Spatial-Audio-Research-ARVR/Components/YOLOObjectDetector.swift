//
//  YOLOObjectDetector.swift
//  Spatial-Audio-Research-ARVR
//  Real object detection using YOLO CoreML model
//

import ARKit
import Vision
import RealityKit
import CoreML

@Observable
class YOLOObjectDetector: ObjectDetectionProtocol {
    
    var detectedObjects: [DetectedObject] = []
    
    private var visionRequest: VNCoreMLRequest?
    private let confidenceThreshold: Float = 0.4
    private var isProcessing = false
    private var currentDeviceAnchor: DeviceAnchor?
    private var lastProcessTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.1
    
    private let expectedLabels = ["Mug", "Water Bottle", "Chair"]
    
    init() {
        setupYOLOModel()
    }
    
    private func setupYOLOModel() {
        guard let modelURL = Bundle.main.url(forResource: "CustomObjectDetector", withExtension: "mlmodelc") else {
            print("⚠️ YOLO model not found. Place 'CustomObjectDetector.mlmodel' in the project.")
            print("📝 Expected objects: \(expectedLabels.joined(separator: ", "))")
            return
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            let visionModel = try VNCoreMLModel(for: model)
            
            visionRequest = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                self?.processVisionResults(request, error)
            }
            
            visionRequest?.imageCropAndScaleOption = .scaleFill
            
            print("✅ YOLO model loaded successfully")
            print("📋 Detecting: \(expectedLabels.joined(separator: ", "))")
            
        } catch {
            print("❌ Failed to load YOLO model: \(error.localizedDescription)")
        }
    }
    
    func processARFrame(_ deviceAnchor: DeviceAnchor) {
        guard let visionRequest = visionRequest else {
            print("⚠️ YOLO model not loaded. Cannot process frame.")
            return
        }
        
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessTime >= processingInterval else { return }
        guard !isProcessing else { return }
        
        self.currentDeviceAnchor = deviceAnchor
        self.lastProcessTime = currentTime
        self.isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.isProcessing = false
        }
    }
    
    private func performVisionRequest(on pixelBuffer: CVPixelBuffer, deviceAnchor: DeviceAnchor) {
        guard let request = visionRequest else { return }
        
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Failed to perform vision request: \(error.localizedDescription)")
            isProcessing = false
        }
    }
    
    private func processVisionResults(_ request: VNRequest, _ error: Error?) {
        defer { isProcessing = false }
        
        if let error = error {
            print("❌ Vision error: \(error.localizedDescription)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            return
        }
        
        guard let deviceAnchor = currentDeviceAnchor else {
            return
        }
        
        let cameraTransform = deviceAnchor.originFromAnchorTransform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        var newObjects: [DetectedObject] = []
        
        for observation in observations {
            guard observation.confidence >= confidenceThreshold else { continue }
            guard let label = observation.labels.first?.identifier else { continue }
            
            guard let worldPosition = convertToWorldPosition(
                boundingBox: observation.boundingBox,
                cameraTransform: cameraTransform
            ) else { continue }
            
            let distance = simd_distance(worldPosition, cameraPosition)
            let direction = normalize(worldPosition - cameraPosition)
            
            let detectedObject = DetectedObject(
                label: label,
                confidence: observation.confidence,
                worldPosition: worldPosition,
                boundingBox: observation.boundingBox,
                distance: distance,
                direction: direction
            )
            
            newObjects.append(detectedObject)
        }
        
        Task { @MainActor in
            self.detectedObjects = newObjects
            print("🎯 Detected \(newObjects.count) objects")
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
        
        let forward = SIMD3<Float>(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
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
        
        let direction = normalize(forward + right * centerX + up * centerY)
        
        let cameraPos = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        return cameraPos + direction * clampedDistance
    }
    
    func stop() {
        visionRequest = nil
        detectedObjects.removeAll()
        isProcessing = false
    }
}
