//
//  Spatial_Audio_Research_ARVRApp.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import SwiftUI

@main
struct SpatialAudioResearchARVRApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
