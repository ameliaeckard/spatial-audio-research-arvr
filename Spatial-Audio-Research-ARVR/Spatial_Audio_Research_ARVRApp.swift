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
        WindowGroup("Main Menu", id: "main-menu") {
            MainMenuView()
                .environment(appModel)
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        
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
        
        WindowGroup("Research Testing", id: "research-testing") {
            ResearchTestingView()
                .environment(appModel)
        }
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentSize)
    }
}
