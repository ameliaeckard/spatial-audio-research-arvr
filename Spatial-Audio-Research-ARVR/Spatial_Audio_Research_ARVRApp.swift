//
//  Spatial_Audio_Research_ARVRApp.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 4/29/26.
//
//  Simplified to a single main window + the immersive space.
//  The main menu window morphs between menu / loading / live-controls states,
//  so the separate control-panel and research-testing windows are no longer needed.
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
    }
}
