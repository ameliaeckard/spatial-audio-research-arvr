import SwiftUI
import RealityKit
import ARKit

struct LiveDetectionView: View {
    @StateObject private var objectDetector = ObjectDetector()
    @StateObject private var spatialAudio = SpatialAudio()
    @State private var arSession = ARKitSession()
    @State private var worldTracking = WorldTrackingProvider()
    
    var body: some View {
        ZStack {
            RealityView { content in
                setupARScene(content: content)
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                headerView
                
                Spacer()
                
                if !objectDetector.detectedObjects.isEmpty {
                    detectedObjectsList
                }
                
                Spacer()
                
                controlPanel
            }
            .padding()
        }
        .task {
            await startARSession()
        }
        .onDisappear {
            stopARSession()
        }
    }

    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Detection")
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(objectDetector.isProcessing ? .green : .gray)
                        .frame(width: 8, height: 8)
                    
                    Text(objectDetector.isProcessing ? "Active" : "Idle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var detectedObjectsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Objects")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(objectDetector.detectedObjects) { object in
                        ObjectCard(object: object) {
                            spatialAudio.announceObject(object)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var controlPanel: some View {
        HStack(spacing: 20) {
            Button {
                spatialAudio.setEnabled(!spatialAudio.isEnabled)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: spatialAudio.isEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 30))
                    
                    Text(spatialAudio.isEnabled ? "Audio On" : "Audio Off")
                        .font(.caption)
                }
                .frame(width: 100, height: 100)
                .background(spatialAudio.isEnabled ? .green : .red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            Button {
                spatialAudio.announceAllObjects(objectDetector.detectedObjects)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 30))
                    
                    Text("Announce")
                        .font(.caption)
                }
                .frame(width: 100, height: 100)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            VStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 20))
                
                Slider(value: Binding(
                    get: { spatialAudio.volume },
                    set: { spatialAudio.setVolume($0) }
                ), in: 0...1)
                .frame(width: 100)
                
                Text("Volume")
                    .font(.caption)
            }
            .frame(width: 140, height: 100)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
    }
    
    private func setupARScene(content: RealityViewContent) {
        // Setup RealityKit content
    }
    
    private func startARSession() async {
        do {
            let formats = worldTracking.queryRequiredAuthorizations()
            try await worldTracking.requestAuthorization(for: formats)
            
            try await arSession.run([worldTracking])
            
            await processARUpdates()
            
        } catch {
            print("Failed to start AR session: \(error.localizedDescription)")
        }
    }
    
    private func processARUpdates() async {
        for await update in worldTracking.anchorUpdates {
            guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
                continue
            }
            
            let transform = deviceAnchor.originFromAnchorTransform
            
            await MainActor.run {
                objectDetector.processARFrame(
                    ARFrame(),
                    with: transform
                )
                
                spatialAudio.updateAudioCues(for: objectDetector.detectedObjects)
            }
        }
    }
    
    private func stopARSession() {
        arSession.stop()
        spatialAudio.stopAllAudioCues()
        objectDetector.clearDetections()
    }
}

struct ObjectCard: View {
    let object: DetectedObject
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconForObject(object.name))
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(object.name.capitalized)
                        .font(.headline)
                    
                    Text(object.directionDescription())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1fm", object.distance()))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("\(Int(object.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private func iconForObject(_ name: String) -> String {
        switch name.lowercased() {
        case "chair": return "chair.fill"
        case "table": return "table.furniture.fill"
        case "door": return "door.left.hand.open"
        case "cup": return "cup.and.saucer.fill"
        case "bottle": return "waterbottle.fill"
        case "laptop": return "laptopcomputer"
        case "keyboard": return "keyboard.fill"
        case "mouse": return "computermouse.fill"
        case "phone": return "iphone"
        case "book": return "book.fill"
        default: return "cube.fill"
        }
    }
}

#Preview {
    LiveDetectionView()
}