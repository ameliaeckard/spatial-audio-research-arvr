//
//  YOLOObjectDetector.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/2/25.
//
//  Real object detection using YOLO CoreML model
//

import ARKit
import Vision
import RealityKit
import CoreML
import QuartzCore

@Observable
class YOLOObjectDetector: ObjectDetectionProtocol {
    
    var detectedObjects: [DetectedObject] = []
    
    private var visionRequest: VNCoreMLRequest?
    private let confidenceThreshold: Float = 0.5
    private var isProcessing = false
    private var currentDeviceAnchor: DeviceAnchor?
    private var lastProcessTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.3
    
    private let expectedLabels = ["cup", "bottle", "chair", "dining table", "laptop"]
    
    init() {
        setupYOLOModel()
    }
    
    private func setupYOLOModel() {
        // Try to find the model with either name
        let modelNames = ["CustomObjectDetector", "yolo11n", "yolov8n"]
        var modelURL: URL?
        
        for name in modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                modelURL = url
                print("✅ Found model: \(name).mlmodelc")
                break
            }
            if let url = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
                modelURL = url
                print("✅ Found model: \(name).mlpackage")
                break
            }
        }
        
        guard let modelURL = modelURL else {
            print("⚠️ YOLO model not found. Tried:")
            for name in modelNames {
                print("   - \(name).mlmodelc")
                print("   - \(name).mlpackage")
            }
            print("🔄 Running in MOCK mode - switch to .yolo when model is added")
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
            print("🎯 Ready to detect: \(expectedLabels.joined(separator: ", "))")
            
        } catch {
            print("❌ Failed to load YOLO model: \(error.localizedDescription)")
        }
    }
    
    func processARFrame(_ deviceAnchor: DeviceAnchor) {
        guard let request = visionRequest else {
            return
        }
        
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessTime >= processingInterval else { return }
        guard !isProcessing else { return }
        
        self.currentDeviceAnchor = deviceAnchor
        self.lastProcessTime = currentTime
        self.isProcessing = true
        
        // Capture request locally for Task
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let pixelBuffer = self.createTestPixelBuffer()
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .up,
                options: [:]
            )
            
            do {
                try handler.perform([request])
            } catch {
                print("❌ Failed to perform vision request: \(error.localizedDescription)")
                await MainActor.run {
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func processVisionResults(_ request: VNRequest, _ error: Error?) {
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
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
            guard let label = observation.labels.first else { continue }
            
            let objectLabel = formatLabel(label.identifier)
            
            guard let worldPosition = convertToWorldPosition(
                boundingBox: observation.boundingBox,
                cameraTransform: cameraTransform
            ) else { continue }
            
            let distance = simd_distance(worldPosition, cameraPosition)
            let direction = normalize(worldPosition - cameraPosition)
            
            let detectedObject = DetectedObject(
                label: objectLabel,
                confidence: label.confidence,
                worldPosition: worldPosition,
                boundingBox: observation.boundingBox,
                distance: distance,
                direction: direction
            )
            
            newObjects.append(detectedObject)
        }
        
        Task { @MainActor in
            self.detectedObjects = newObjects
            if !newObjects.isEmpty {
                print("🎯 Detected \(newObjects.count) objects:")
                for obj in newObjects.prefix(3) {
                    print("   - \(obj.label) (\(String(format: "%.1f", obj.distance))m, \(String(format: "%.0f", obj.confidence * 100))%)")
                }
            }
        }
    }
    
    private func formatLabel(_ label: String) -> String {
        // Convert YOLO labels to friendly names
        let labelMap: [String: String] = [
            "cup": "Mug",
            "bottle": "Water Bottle",
            "wine glass": "Glass",
            "dining table": "Table",
            "chair": "Chair",
            "couch": "Couch",
            "laptop": "Laptop",
            "cell phone": "Phone",
            "book": "Book",
            "clock": "Clock",
            "vase": "Vase",
            "mouse": "Mouse",
            "keyboard": "Keyboard"
        ]
        
        return labelMap[label.lowercased()] ?? label.capitalized
    }
    
    private func convertToWorldPosition(
        boundingBox: CGRect,
        cameraTransform: simd_float4x4
    ) -> SIMD3<Float>? {
        
        let centerX = Float(boundingBox.midX - 0.5) * 2.0
        let centerY = Float(0.5 - boundingBox.midY) * 2.0
        
        // Estimate distance based on bounding box size
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
    
    private nonisolated func createTestPixelBuffer() -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            640,
            640,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        return pixelBuffer!
    }
    
    func stop() {
        visionRequest = nil
        detectedObjects.removeAll()
        isProcessing = false
    }
}
