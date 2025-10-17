//
//  SpatialAudioApp.swift
//  Spatial-Audio-Research-ARVR
//
//

import SwiftUI

@main
struct SpatialAudioApp: App {
    var body: some Scene {
        // Main menu window with standard glass background
        WindowGroup("Main Menu", id: "main-menu") {
            MainMenuView()
        }
        .defaultSize(width: 800, height: 600)
        
        // Live detection as immersive space (completely transparent AR overlay)
        ImmersiveSpace(id: "live-detection") {
            LiveDetectionImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        // Research testing window with standard background
        WindowGroup("Research Testing", id: "research-testing") {
            ResearchTestingView()
        }
        .defaultSize(width: 900, height: 700)
    }
}
