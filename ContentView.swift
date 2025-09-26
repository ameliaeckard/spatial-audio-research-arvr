//
//  ContentView.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @EnvironmentObject var spatialAudioManager: SpatialAudioManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Spatial Audio Research")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                switch appModel.currentView {
                case .dashboard:
                    DashboardView()
                case .objectDetection:
                    ObjectDetectionView()
                case .settings:
                    SettingsView()
                case .statistics:
                    StatisticsView()
                }
                
                Spacer()
                
                HStack(spacing: 15) {
                    NavigationButton(title: "Dashboard", view: .dashboard, currentView: appModel.currentView) {
                        appModel.currentView = .dashboard
                    }
                    NavigationButton(title: "Detection", view: .objectDetection, currentView: appModel.currentView) {
                        appModel.currentView = .objectDetection
                    }
                    NavigationButton(title: "Settings", view: .settings, currentView: appModel.currentView) {
                        appModel.currentView = .settings
                    }
                    NavigationButton(title: "Stats", view: .statistics, currentView: appModel.currentView) {
                        appModel.currentView = .statistics
                    }
                }
                
                ToggleImmersiveSpaceButton()
                    .padding(.top)
            }
            .padding()
        }
    }
}

struct NavigationButton: View {
    let title: String
    let view: AppModel.ViewState
    let currentView: AppModel.ViewState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(currentView == view ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(currentView == view ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

// MARK: - View Components

struct DashboardView: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack {
            Text("Research Dashboard")
                .font(.title2)
            
            if let session = appModel.currentSession {
                Text("Session Active")
                    .foregroundColor(.green)
                Text("Started: \(session.startTime.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("No Active Session")
                    .foregroundColor(.secondary)
            }
            
            Button(appModel.currentSession == nil ? "Start Session" : "End Session") {
                if appModel.currentSession == nil {
                    appModel.startNewSession()
                } else {
                    appModel.endSession()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ObjectDetectionView: View {
    @EnvironmentObject var objectRecognitionManager: ObjectRecognitionManager
    @EnvironmentObject var spatialAudioManager: SpatialAudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Object Detection")
                .font(.title2)
            
            HStack {
                Text("Status:")
                Text(objectRecognitionManager.isDetectionActive ? "Active" : "Inactive")
                    .foregroundColor(objectRecognitionManager.isDetectionActive ? .green : .red)
                    .fontWeight(.semibold)
            }
            
            Text("Detected Objects: \(objectRecognitionManager.detectedObjects.count)")
                .font(.headline)
            
            if objectRecognitionManager.detectedObjects.isEmpty {
                Text("No objects detected yet...")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(objectRecognitionManager.detectedObjects) { object in
                            ObjectRowView(object: object)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            
            Button(objectRecognitionManager.isDetectionActive ? "Stop Detection" : "Start Detection") {
                Task {
                    if objectRecognitionManager.isDetectionActive {
                        await objectRecognitionManager.stopObjectDetection()
                    } else {
                        await objectRecognitionManager.startObjectDetection()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ObjectRowView: View {
    let object: DetectedObject
    
    var body: some View {
        HStack {
            Circle()
                .fill(getColorForObjectType(object.type))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(object.type.displayName)
                    .font(.system(size: 14, weight: .medium))
                
                HStack {
                    Text("\(String(format: "%.1f", object.distanceFromUser))m")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(object.confidence * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(object.confidence > 0.8 ? .green : .orange)
                }
            }
            
            Spacer()
            
            Text(object.timestamp.formatted(date: .omitted, time: .complete))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    func getColorForObjectType(_ type: ObjectType) -> Color {
        switch type {
        case .chair: return .blue
        case .table: return .brown
        case .door: return .green
        case .stairs: return .red
        case .sofa: return .purple
        case .desk: return .orange
        case .window: return .cyan
        case .plant: return .green
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var spatialAudioManager: SpatialAudioManager
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Settings")
                .font(.title2)
            
            Toggle("Spatial Audio", isOn: $spatialAudioManager.spatialAudioEnabled)
            Toggle("Voice Descriptions", isOn: $spatialAudioManager.voiceDescriptionsEnabled)
            Toggle("Haptic Feedback", isOn: $accessibilityManager.hapticsEnabled)
            
            VStack(alignment: .leading) {
                Text("Master Volume: \(Int(spatialAudioManager.masterVolume * 100))%")
                Slider(value: $spatialAudioManager.masterVolume, in: 0...1)
            }
        }
    }
}

struct StatisticsView: View {
    var body: some View {
        VStack {
            Text("Statistics")
                .font(.title2)
            Text("Session statistics will appear here")
                .foregroundColor(.secondary)
        }
    }
}
