//
//  Spatial_Audio_Research_ARVRApp.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import SwiftUI

@main
struct SpatialAudioResearchARVRApp: App {
    @State private var appModel = AppModel()
    @State private var objectRecognitionManager = ObjectRecognitionManager()
    @State private var spatialAudioManager = SpatialAudioManager()
    @State private var accessibilityManager = AccessibilityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environmentObject(objectRecognitionManager)
                .environmentObject(spatialAudioManager)
                .environmentObject(accessibilityManager)
        }
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environmentObject(objectRecognitionManager)
                .environmentObject(spatialAudioManager)
                .environmentObject(accessibilityManager)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
    }
}
