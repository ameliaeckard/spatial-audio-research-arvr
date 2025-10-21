//
//  LiveDetectionImmersiveView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//

import SwiftUI
import RealityKit

struct LiveDetectionImmersiveView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppModel.self) private var appModel
    
    @State private var rootEntity = Entity()
    
    var body: some View {
        RealityView { content in
            content.add(rootEntity)
        }
        .overlay(alignment: .top) {
            // Header text floating in space
            VStack(spacing: 16) {
                Text("Live Detection Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                
                if let object = appModel.selectedObject {
                    HStack(spacing: 8) {
                        Text("Detecting:")
                            .font(.title2)
                        
                        Text(object.rawValue)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(object.color)
                        
                        // Show detection status
                        if appModel.detectedObjects[object] == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                        }
                    }
                    .padding()
                    .background(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                } else {
                    Text("Select an object to detect")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
                
                // Show tracking status
                if appModel.isReadyToRun {
                    Text("Tracking Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Initializing...")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.top, 100)
        }
        .overlay(alignment: .bottom) {
            // Floating bubbles at bottom of view
            HStack(spacing: 30) {
                ForEach(AppModel.DetectionObject.allCases, id: \.self) { object in
                    ObjectBubble(
                        objectName: object.rawValue,
                        icon: object.icon,
                        color: object.color,
                        isSelected: appModel.selectedObject == object,
                        isDetected: appModel.detectedObjects[object] == true
                    ) {
                        if appModel.selectedObject == object {
                            appModel.selectedObject = nil
                        } else {
                            appModel.selectedObject = object
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .overlay(alignment: .topLeading) {
            // Exit button in top corner
            Button {
                Task {
                    await dismissImmersiveSpace()
                    openWindow(id: "main-menu")
                }
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                    Text("Exit")
                        .font(.title3)
                }
                .padding()
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 60)
            .padding(.leading, 60)
        }
        .task {
            await appModel.startTracking(with: rootEntity)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await appModel.queryWorldSensingAuthorization()
                }
            } else {
                if appModel.immersiveSpaceState == .open {
                    Task {
                        await dismissImmersiveSpace()
                    }
                }
            }
        }
        .onChange(of: appModel.providersStoppedWithError) { _, providersStoppedWithError in
            if providersStoppedWithError {
                if appModel.immersiveSpaceState == .open {
                    Task {
                        await dismissImmersiveSpace()
                    }
                }
                appModel.providersStoppedWithError = false
            }
        }
        .onDisappear {
            for (_, visualization) in appModel.objectVisualizations {
                rootEntity.removeChild(visualization.entity)
            }
            appModel.objectVisualizations.removeAll()
        }
    }
}