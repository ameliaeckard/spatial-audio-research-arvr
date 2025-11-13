//
//  LiveDetectionImmersiveView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  AR content for the live detection.
//

import SwiftUI
import RealityKit

struct LiveDetectionImmersiveView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppModel.self) private var appModel
    
    @State private var rootEntity = Entity()
    
    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            appModel.rootEntity = rootEntity
        }
        .task {
            await appModel.startObjectTracking()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await appModel.queryWorldSensingAuthorization()
                }
            }
        }
        .onDisappear {
            appModel.stopObjectTracking()
        }
    }
}
