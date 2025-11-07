//
//  LiveDetectionControlPanel.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  Properly handles window transitions
//

import SwiftUI

struct LiveDetectionControlPanel: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Text("Live Detection")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let object = appModel.selectedObject {
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
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Select an object to detect")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                // Status
                if appModel.isReadyToRun {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Tracking Active")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Initializing...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Divider()
            
            // Object Selection
            VStack(spacing: 20) {
                Text("Select Object to Detect")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    ForEach(AppModel.DetectionObject.allCases, id: \.self) { object in
                        Button {
                            toggleObjectSelection(object)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(appModel.selectedObject == object ? object.color.opacity(0.2) : Color.clear)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: object.icon)
                                        .font(.system(size: 30))
                                        .foregroundStyle(appModel.selectedObject == object ? object.color : .primary)
                                    
                                    if appModel.detectedObjects[object] == true {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.system(size: 20))
                                            .offset(x: 25, y: -25)
                                    }
                                }
                                
                                Text(object.rawValue)
                                    .font(.caption)
                                    .fontWeight(appModel.selectedObject == object ? .semibold : .regular)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            // Detection Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Objects")
                    .font(.headline)
                
                if appModel.trackedObjects.isEmpty {
                    Text("No objects detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(appModel.trackedObjects.prefix(5)) { object in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            
                            Text(object.label)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(String(format: "%.1fm", object.distance))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Text(String(format: "%.0f%%", object.confidence * 100))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if appModel.trackedObjects.count > 5 {
                        Text("+\(appModel.trackedObjects.count - 5) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Exit Button
            Button {
                Task {
                    // Close control panel FIRST
                    dismissWindow(id: "live-detection-controls")
                    
                    // Small delay
                    try? await Task.sleep(for: .milliseconds(200))
                    
                    // Dismiss immersive space
                    await dismissImmersiveSpace()
                    
                    // Wait for immersive space to fully close
                    try? await Task.sleep(for: .milliseconds(300))
                    
                    // Reopen main menu
                    openWindow(id: "main-menu")
                    print("Returned to main menu")
                }
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Exit Live Detection")
                }
                .font(.title3)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.red.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(width: 600, height: 700)
    }
    
    private func toggleObjectSelection(_ object: AppModel.DetectionObject) {
        if appModel.selectedObject == object {
            appModel.selectedObject = nil
        } else {
            appModel.selectedObject = object
        }
    }
}
