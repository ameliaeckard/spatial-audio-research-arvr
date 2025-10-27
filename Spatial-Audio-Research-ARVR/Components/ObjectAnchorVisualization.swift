//
//  ObjectAnchorVisualization.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//
//  Visualization for detected Object Anchors in ARKit using RealityKit.
//

import ARKit
import RealityKit
import UIKit

@MainActor
class ObjectAnchorVisualization {
    var entity: Entity
    var objectName: String?
    
    private let textBaseHeight: Float = 0.08
    private let alpha: CGFloat = 0.7
    private let axisScale: Float = 0.05
    
    init(for anchor: ObjectAnchor, withModel model: Entity? = nil) async {
        guard let model else {
            print("Unable to find Reference Object model")
            entity = Entity()
            return
        }
        
        // Store object name for identification
        self.objectName = model.name
        
        let entity = Entity()
        
        // Create simple wireframe overlay for all objects
        var wireframeMaterial = PhysicallyBasedMaterial()
        wireframeMaterial.triangleFillMode = .lines
        wireframeMaterial.faceCulling = .back
        wireframeMaterial.baseColor = .init(tint: .green)
        wireframeMaterial.blending = .transparent(opacity: 0.6)
        model.applyMaterialRecursively(wireframeMaterial)
        
        // Add origin visualization (RGB axes)
        let originVisualization = Entity.createAxes(axisScale: axisScale, alpha: alpha)
        
        // Add text label above object
        let descriptionEntity = Entity.createText(model.name,
                                                  height: textBaseHeight * axisScale)
        descriptionEntity.transform.translation.x = textBaseHeight * axisScale
        descriptionEntity.transform.translation.y = anchor.boundingBox.extent.y * 0.5 + 0.05
        
        entity.addChild(originVisualization)
        entity.addChild(model)
        entity.addChild(descriptionEntity)
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        entity.isEnabled = anchor.isTracked
        
        self.entity = entity
        
        print("Created visualization for: \(model.name)")
    }
    
    func update(with anchor: ObjectAnchor) {
        entity.isEnabled = anchor.isTracked
        
        guard anchor.isTracked else { return }
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
    }
}
