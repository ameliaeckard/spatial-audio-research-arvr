//
//  LiveDetectionImmersiveView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/28/25.
//
//  View for the live detection immersive space. Uses RealityView to display AR content.
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
            appModel.rootEntity = rootEntity
        }
        .overlay(alignment: .top) {
            headerView
        }
        .overlay(alignment: .bottom) {
            objectBubblesView
        }
        .overlay(alignment: .topLeading) {
            exitButton
        }
        .overlay(alignment: .topTrailing) {
            detectionDebugView
        }
        .task {
            await appModel.startComputerVisionTracking()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: appModel.providersStoppedWithError) { _, providersStoppedWithError in
            handleProviderError(providersStoppedWithError)
        }
        .onDisappear {
            appModel.stopComputerVisionDetection()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Live Detection Mode")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .shadow(radius: 4)
            
            if let object = appModel.selectedObject {
                selectedObjectView(object)
            } else {
                Text("Select an object to detect")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            
            trackingStatusView
        }
        .padding(.top, 100)
    }
    
    private func selectedObjectView(_ object: AppModel.DetectionObject) -> some View {
        HStack(spacing: 8) {
            Text("Detecting:")
                .font(.title2)
            
            Text(object.rawValue)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(object.color)
            
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
    }
    
    private var trackingStatusView: some View {
        Group {
            if appModel.isReadyToRun {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("CV Tracking Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(8)
                .background(.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    
                    Text("Initializing...")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background(.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var detectionDebugView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Objects")
                .font(.headline)
                .foregroundStyle(.white)
            
            if appModel.cvDetectedObjects.isEmpty {
                Text("No objects detected")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(appModel.cvDetectedObjects.prefix(5)) { object in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        
                        Text(object.label)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(String(format: "%.1fm", object.distance))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(String(format: "%.0f%%", object.confidence * 100))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            
            Text("\(appModel.cvDetectedObjects.count) total")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .padding()
        .frame(width: 250)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 60)
        .padding(.trailing, 60)
    }
    
    private var objectBubblesView: some View {
        HStack(spacing: 30) {
            ForEach(AppModel.DetectionObject.allCases, id: \.self) { object in
                ObjectBubble(
                    objectName: object.rawValue,
                    icon: object.icon,
                    color: object.color,
                    isSelected: appModel.selectedObject == object,
                    isDetected: appModel.detectedObjects[object] == true
                ) {
                    toggleObjectSelection(object)
                }
            }
        }
        .padding(.bottom, 100)
    }
    
    private var exitButton: some View {
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
    
    private func toggleObjectSelection(_ object: AppModel.DetectionObject) {
        if appModel.selectedObject == object {
            appModel.selectedObject = nil
        } else {
            appModel.selectedObject = object
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
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
    
    private func handleProviderError(_ providersStoppedWithError: Bool) {
        if providersStoppedWithError {
            if appModel.immersiveSpaceState == .open {
                Task {
                    await dismissImmersiveSpace()
                }
            }
            appModel.providersStoppedWithError = false
        }
    }
}
