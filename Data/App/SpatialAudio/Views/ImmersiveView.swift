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
    @EnvironmentObject var appModel: AppModel
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
        content.add(light)
        
        Task {
            await objectRecognitionManager.startObjectDetection()
        }
    }

    func updateScene(in content: RealityViewContent) {
        for object in objectRecognitionManager.detectedObjects {
            spatialAudioManager.updateAudioPosition(for: object)
        }
    }
}
