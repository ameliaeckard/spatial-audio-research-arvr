//
//  ImmersiveView.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject var objectRecognitionManager: ObjectRecognitionManager
    @EnvironmentObject var spatialAudioManager: SpatialAudioManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        RealityView { content in
            setupScene(in: content)
        } update: { content in
            updateScene(in: content)
        }
        .edgesIgnoringSafeArea(.all)
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("Immersive object detection view")
    }

    func setupScene(in content: RealityViewContent) {
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.position = SIMD3<Float>(0, 2, 0)
        content.add(light)
        
        let ambientLight = Entity()
        ambientLight.components[DirectionalLightComponent.self] = DirectionalLightComponent(
            color: .white,
            intensity: 300,
            isRealWorldProxy: false
        )
        content.add(ambientLight)
        
        Task {
            await objectRecognitionManager.startObjectDetection()
        }
    }

    func updateScene(in content: RealityViewContent) {
        let currentObjectIds = Set(objectRecognitionManager.detectedObjects.map { $0.id })
        let existingEntities = content.entities.compactMap { entity in
            entity.name.hasPrefix("detected_") ? entity : nil
        }
        
        for entity in existingEntities {
            let idString = String(entity.name.dropFirst("detected_".count))
            if let uuid = UUID(uuidString: idString), !currentObjectIds.contains(uuid) {
                content.remove(entity)
            }
        }
        
        for object in objectRecognitionManager.detectedObjects {
            let entityName = "detected_\(object.id.uuidString)"
            
            let existingEntity = content.entities.first { $0.name == entityName }
            
            if existingEntity == nil {
                let objectEntity = createVisualEntity(for: object)
                objectEntity.name = entityName
                content.add(objectEntity)
            } else if let entity = existingEntity {
                entity.position = object.position
                entity.orientation = object.orientation
            }
            
            spatialAudioManager.updateAudioPosition(for: object)
        }
    }
    
    func createVisualEntity(for object: DetectedObject) -> Entity {
        let entity = Entity()
        
        let mesh = MeshResource.generateBox(
            size: object.boundingBox.size,
            cornerRadius: 0.05
        )
        
        let color = getColorForObjectType(object.type)
        var material = SimpleMaterial(color: color, isMetallic: false)
        material.roughness = MaterialScalarParameter(floatLiteral: 0.3)
        
        material.baseColor = try! MaterialColorParameter.color(color.withAlphaComponent(0.7))
        
        let modelComponent = ModelComponent(mesh: mesh, materials: [material])
        entity.components[ModelComponent.self] = modelComponent
        
        let wireframeMesh = MeshResource.generateBox(
            size: object.boundingBox.size * 1.01,
            cornerRadius: 0.05
        )
        let wireframeMaterial = SimpleMaterial(color: .white, isMetallic: false)
        
        let wireframeEntity = Entity()
        wireframeEntity.components[ModelComponent.self] = ModelComponent(
            mesh: wireframeMesh,
            materials: [wireframeMaterial]
        )
        wireframeEntity.components[OpacityComponent.self] = OpacityComponent(opacity: 0.3)
        
        entity.addChild(wireframeEntity)
        
        entity.position = object.position
        entity.orientation = object.orientation
        
        let labelEntity = createLabelEntity(for: object)
        labelEntity.position = SIMD3<Float>(0, object.boundingBox.size.y / 2 + 0.1, 0)
        entity.addChild(labelEntity)
        
        let pulseAnimation = AnimationResource.orbit(
            duration: 2.0,
            axis: SIMD3<Float>(0, 1, 0),
            times: .infinity,
            bindTarget: .transform
        )
        entity.playAnimation(pulseAnimation)
        
        return entity
    }
    
    func createLabelEntity(for object: DetectedObject) -> Entity {
        let labelEntity = Entity()
        
        let confidence = Int(object.confidence * 100)
        let distance = String(format: "%.1fm", object.distanceFromUser)
        
        let labelMesh = MeshResource.generateSphere(radius: 0.05)
        let labelColor = object.confidence > 0.8 ? UIColor.green :
                        object.confidence > 0.6 ? UIColor.yellow : UIColor.orange
        
        let labelMaterial = SimpleMaterial(color: labelColor, isMetallic: false)
        labelEntity.components[ModelComponent.self] = ModelComponent(
            mesh: labelMesh,
            materials: [labelMaterial]
        )
        
        return labelEntity
    }
    
    func getColorForObjectType(_ type: ObjectType) -> UIColor {
        switch type {
        case .chair: return .systemBlue
        case .table: return .systemBrown
        case .door: return .systemGreen
        case .stairs: return .systemRed
        case .sofa: return .systemPurple
        case .desk: return .systemOrange
        case .window: return .systemCyan
        case .plant: return .systemGreen
        }
    }
}
