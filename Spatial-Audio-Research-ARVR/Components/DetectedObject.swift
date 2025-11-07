//
//  DetectedObject.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/6/25.
//
//  Simple model for detected objects (used by ObjectTracking and UI)
//

import Foundation
import RealityKit

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let worldPosition: SIMD3<Float>
    let boundingBox: CGRect
    let distance: Float
    let direction: SIMD3<Float>
}
