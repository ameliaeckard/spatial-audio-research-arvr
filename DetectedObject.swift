import Foundation
import simd

struct DetectedObject: Identifiable {
    let id = UUID()
    let name: String
    let position: SIMD3<Float>
    let distance: Float
    let direction: SIMD3<Float> // Normalized direction vector
    let timestamp: Date
    
    var azimuth: Float {
        // Calculate horizontal angle from forward direction
        return atan2(direction.x, -direction.z)
    }
    
    var elevation: Float {
        // Calculate vertical angle
        return asin(direction.y)
    }
}
