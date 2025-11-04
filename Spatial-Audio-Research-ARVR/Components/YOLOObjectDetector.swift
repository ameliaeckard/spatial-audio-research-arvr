//
//  YOLOObjectDetector.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  Added CoreMedia import
//

import ARKit
import Vision
import RealityKit
import CoreML
import QuartzCore
import CoreMedia

@Observable
class YOLOObjectDetector: ObjectDetectionProtocol {
    
    var detectedObjects: [DetectedObject] = []
    
    private var visionRequest: VNCoreMLRequest?
    private let confidenceThreshold: Float = 0.4
    private var isProcessing = false
    private var currentDeviceAnchor: DeviceAnchor?
    private var lastProcessTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.2
    
    init() {
        setupYOLOModel()
    }
    
    private func setupYOLOModel() {
        // Try multiple model names and formats
        let modelNames = ["CustomObjectDetector", "yolov8n", "yolo11n"]
        var modelURL: URL?
        
        for name in modelNames {
            // Try .mlmodelc first, then .mlpackage
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                modelURL = url
                print("✅ Found model: \(name).mlmodelc")
                break
            } else if let url = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
                modelURL = url
                print("✅ Found model: \(name).mlpackage")
                break
            }
        }
        
        guard let modelURL = modelURL else {
            print("⚠️ YOLO model not found. Place 'CustomObjectDetector.mlpackage' in the project.")
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
            print("🎯 Ready for real-time detection")
            
        } catch {
            print("❌ Failed to load YOLO model: \(error.localizedDescription)")
        }
    }
    
    // Process with camera frame sample buffer
    func processARFrame(_ deviceAnchor: DeviceAnchor, cameraSample: CMSampleBuffer? = nil) {
        guard let request = visionRequest else {
            print("⚠️ YOLO model not loaded. Cannot process frame.")
            return
        }
        
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessTime >= processingInterval else { return }
        guard !isProcessing else { return }
        
        self.currentDeviceAnchor = deviceAnchor
        self.lastProcessTime = currentTime
        self.isProcessing = true
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            var pixelBuffer: CVPixelBuffer?
            
            // Try to get pixel buffer from camera sample
            if let sample = cameraSample,
               let imageBuffer = CMSampleBufferGetImageBuffer(sample) {
                pixelBuffer = imageBuffer
                print("Processing real camera frame")
            } else {
                print("No camera frame")
                await MainActor.run {
                    self.isProcessing = false
                }
                return
            }
            
            guard let buffer = pixelBuffer else {
                await MainActor.run {
                    self.isProcessing = false
                }
                return
            }
            
            let handler = VNImageRequestHandler(
                cvPixelBuffer: buffer,
                orientation: .up,
                options: [:]
            )
            
            do {
                try handler.perform([request])
            } catch {
                print("Vision failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.isProcessing = false
                }
            }
        }
    }
    
    // Compatibility wrapper
    func processARFrame(_ deviceAnchor: DeviceAnchor) {
        processARFrame(deviceAnchor, cameraSample: nil)
    }
    
    private func processVisionResults(_ request: VNRequest, _ error: Error?) {
        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        if let error = error {
            print("Vision error: \(error.localizedDescription)")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            Task { @MainActor in
                if !self.detectedObjects.isEmpty {
                    self.detectedObjects = []
                }
            }
            return
        }
        
        guard !observations.isEmpty else {
            Task { @MainActor in
                if !self.detectedObjects.isEmpty {
                    self.detectedObjects = []
                }
            }
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
                print("Detected \(newObjects.count) objects:")
                for obj in newObjects.prefix(3) {
                    print("   - \(obj.label) at \(String(format: "%.1fm", obj.distance)) (\(String(format: "%.0f", obj.confidence * 100))%)")
                }
            }
        }
    }
    
    private func formatLabel(_ label: String) -> String {
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
