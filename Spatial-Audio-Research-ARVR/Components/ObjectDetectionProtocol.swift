//
//  ObjectDetectionProtocol.swift
//  Spatial-Audio-Research-ARVR
//  Created for swappable detection modes
//

import ARKit
import RealityKit

/// Protocol for object detection implementations
@Observable
protocol ObjectDetectionProtocol: AnyObject {
    
    /// Detected objects array
    var detectedObjects: [DetectedObject] { get set }
    
    /// Process AR frame from Vision Pro
    func processARFrame(_ deviceAnchor: DeviceAnchor)
    
    /// Stop detection and cleanup
    func stop()
}

/// Unified detected object model
struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let worldPosition: SIMD3<Float>
    let boundingBox: CGRect
    let distance: Float
    let direction: SIMD3<Float>
}
