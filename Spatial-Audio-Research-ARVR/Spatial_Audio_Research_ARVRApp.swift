//
//  Spatial_Audio_Research_ARVRApp.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//
//  Holds the main app structure and windows using SwiftUI.
//

import SwiftUI

@main
struct SpatialAudioApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        // Main menu window with standard glass background
        WindowGroup("Main Menu", id: "main-menu") {
            MainMenuView()
                .environment(appModel)
        }
        .defaultSize(width: 800, height: 600)
        
        // Live detection as immersive space (completely transparent AR overlay)
        ImmersiveSpace(id: "live-detection") {
            LiveDetectionImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        // Research testing window with standard background
        WindowGroup("Research Testing", id: "research-testing") {
            ResearchTestingView()
                .environment(appModel)
        }
        .defaultSize(width: 900, height: 700)
    }
}