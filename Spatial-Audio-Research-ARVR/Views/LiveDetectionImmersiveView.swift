//
//  LiveDetectionImmersiveView.swift
//  Spatial-Audio-Research-ARVR
//
//

import SwiftUI
import RealityKit

struct LiveDetectionImmersiveView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var selectedObject: String? = nil
    
    var body: some View {
        RealityView { content in
            // This is where you'd add RealityKit content for AR object detection
            // For now, we'll keep it minimal
        }
        .overlay(alignment: .top) {
            // Header text floating in space
            VStack(spacing: 16) {
                Text("Live Detection Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                
                if let object = selectedObject {
                    Text("Detecting: \(object)")
                        .font(.title2)
                        .foregroundStyle(.blue)
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
            }
            .padding(.top, 100)
        }
        .overlay(alignment: .bottom) {
            // Floating bubbles at bottom of view
            HStack(spacing: 30) {
                ObjectBubble(
                    objectName: "Mug",
                    icon: "cup.and.saucer.fill",
                    color: .brown,
                    isSelected: selectedObject == "Mug"
                ) {
                    selectedObject = selectedObject == "Mug" ? nil : "Mug"
                }
                
                ObjectBubble(
                    objectName: "Water Bottle",
                    icon: "waterbottle.fill",
                    color: .blue,
                    isSelected: selectedObject == "Water Bottle"
                ) {
                    selectedObject = selectedObject == "Water Bottle" ? nil : "Water Bottle"
                }
                
                ObjectBubble(
                    objectName: "Chair",
                    icon: "chair.fill",
                    color: .orange,
                    isSelected: selectedObject == "Chair"
                ) {
                    selectedObject = selectedObject == "Chair" ? nil : "Chair"
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
        .onAppear {
            // Add any AR setup logic here
        }
    }
}
