//
//  ObjectDetectionProtocol.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.

//  Updated for camera frame support
//

import ARKit
import RealityKit

protocol ObjectDetectionProtocol: AnyObject {
    
    var detectedObjects: [DetectedObject] { get set }
    
    func processARFrame(_ deviceAnchor: DeviceAnchor)
    
    func stop()
}

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let worldPosition: SIMD3<Float>
    let boundingBox: CGRect
    let distance: Float
    let direction: SIMD3<Float>
}
