import Foundation
import simd

struct DetectedObject: Identifiable, Codable {
    let id: UUID
    let name: String
    let position: SIMD3<Float>
    let confidence: Float
    let timestamp: Date
    
    init(id: UUID = UUID(), name: String, position: SIMD3<Float>, confidence: Float, timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.position = position
        self.confidence = confidence
        self.timestamp = timestamp
    }
    
    func distance(from origin: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) -> Float {
        let delta = position - origin
        return length(delta)
    }
    
    func direction(from origin: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) -> SIMD3<Float> {
        let delta = position - origin
        return normalize(delta)
    }
    
    func azimuth(from origin: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) -> Float {
        let dir = direction(from: origin)
        return atan2(dir.x, -dir.z)
    }
    
    func elevation(from origin: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) -> Float {
        let dir = direction(from: origin)
        return asin(dir.y)
    }
    
    func directionDescription(from origin: SIMD3<Float> = SIMD3<Float>(0, 0, 0)) -> String {
        let azimuthDegrees = azimuth(from: origin) * 180 / .pi
        let elevationDegrees = elevation(from: origin) * 180 / .pi
        
        var description = ""
        
        // Horizontal direction
        if abs(azimuthDegrees) < 15 {
            description += "ahead"
        } else if azimuthDegrees > 0 {
            if azimuthDegrees > 75 {
                description += "far right"
            } else if azimuthDegrees > 30 {
                description += "right"
            } else {
                description += "slightly right"
            }
        } else {
            if azimuthDegrees < -75 {
                description += "far left"
            } else if azimuthDegrees < -30 {
                description += "left"
            } else {
                description += "slightly left"
            }
        }
        
        // Vertical direction
        if abs(elevationDegrees) > 20 {
            if elevationDegrees > 0 {
                description += " and above"
            } else {
                description += " and below"
            }
        }
        
        return description
    }
}

extension DetectedObject {
    enum CodingKeys: String, CodingKey {
        case id, name, confidence, timestamp
        case positionX, positionY, positionZ
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        confidence = try container.decode(Float.self, forKey: .confidence)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        let x = try container.decode(Float.self, forKey: .positionX)
        let y = try container.decode(Float.self, forKey: .positionY)
        let z = try container.decode(Float.self, forKey: .positionZ)
        position = SIMD3<Float>(x, y, z)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(position.z, forKey: .positionZ)
    }
}