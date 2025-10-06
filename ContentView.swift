import SwiftUI
import RealityKit
import ARKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = ObjectRecognitionViewModel()
    
    var body: some View {
        ZStack {
            // AR View for object detection
            ARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay UI
            VStack {
                // Status display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spatial Audio Object Recognition")
                        .font(.headline)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    if !viewModel.detectedObjects.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.detectedObjects) { obj in
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("\(obj.name) - \(String(format: "%.1f", obj.distance))m")
                                        .font(.caption)
                                }
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.toggleAudioFeedback()
                    }) {
                        Image(systemName: viewModel.isAudioEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(viewModel.isAudioEnabled ? Color.green : Color.red)
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        viewModel.announceObjects()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let viewModel: ObjectRecognitionViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        // Enable object detection if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        arView.session.run(configuration)
        arView.session.delegate = context.coordinator
        
        // Store reference
        viewModel.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ObjectRecognitionViewModel
        
        init(viewModel: ObjectRecognitionViewModel) {
            self.viewModel = viewModel
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            viewModel.processFrame(frame)
        }
    }
}

#Preview {
    ContentView()
}
