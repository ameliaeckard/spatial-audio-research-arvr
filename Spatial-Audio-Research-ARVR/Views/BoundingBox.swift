//
//  BoundingBoxEntity.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  Creates 3D bounding boxes for detected objects
//

import RealityKit
import SwiftUI

class BoundingBoxEntity: Entity {
    
    private var boxModel: ModelEntity?
    private var labelEntity: Entity?
    
    init(for detectedObject: DetectedObject) {
        super.init()
        
        createBoundingBox(for: detectedObject)
        updatePosition(detectedObject.worldPosition)
    }
    
    required init() {
        super.init()
    }
    
    private func createBoundingBox(for object: DetectedObject) {
        let boxSize: Float = 0.3
        let mesh = MeshResource.generateBox(size: [boxSize, boxSize, boxSize])
        
        var material = UnlitMaterial()
        material.color = .init(tint: .blue.withAlphaComponent(0.3))
        
        let boxModel = ModelEntity(mesh: mesh, materials: [material])
        boxModel.components.set(OpacityComponent(opacity: 0.3))
        
        let wireframeMesh = MeshResource.generateBox(size: [boxSize, boxSize, boxSize])
        var wireframeMaterial = UnlitMaterial()
        wireframeMaterial.color = .init(tint: .cyan)
        wireframeMaterial.blending = .transparent(opacity: 1.0)
        
        let wireframe = ModelEntity(mesh: wireframeMesh, materials: [wireframeMaterial])
        wireframe.model?.mesh = .generateBox(size: [boxSize, boxSize, boxSize])
        
        self.addChild(boxModel)
        self.boxModel = boxModel
    }
    
    func updatePosition(_ position: SIMD3<Float>) {
        self.position = position
    }
    
    func update(with object: DetectedObject) {
        updatePosition(object.worldPosition)
        
        if let boxModel = boxModel {
            var material = UnlitMaterial()
            
            if object.distance < 1.0 {
                material.color = .init(tint: .green.withAlphaComponent(0.5))
            } else if object.distance < 2.0 {
                material.color = .init(tint: .yellow.withAlphaComponent(0.4))
            } else {
                material.color = .init(tint: .blue.withAlphaComponent(0.3))
            }
            
            boxModel.model?.materials = [material]
        }
    }
}
