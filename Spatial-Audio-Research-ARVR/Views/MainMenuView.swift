//
//  MainMenuView.swift
//  Spatial-Audio-Research-ARVR
//
//

import SwiftUI

struct MainMenuView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                Text("Hello, User")
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)
                
                Text("Welcome to Spatial Audio Research")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text("Enhancing object recognition for visually impaired users")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 60)
            
            Spacer()
            
            VStack(spacing: 24) {
                // Live Detection Button - Opens Immersive Space
                Button {
                    Task {
                        dismissWindow(id: "main-menu")
                        await openImmersiveSpace(id: "live-detection")
                    }
                } label: {
                    MenuCard(
                        title: "Live Detection",
                        subtitle: "Immersive object detection with spatial audio",
                        icon: "eye.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
                
                // Research Testing Button - Opens Window
                Button {
                    openWindow(id: "research-testing")
                    dismissWindow(id: "main-menu")
                } label: {
                    MenuCard(
                        title: "Research Testing",
                        subtitle: "Controlled scenarios for data collection",
                        icon: "chart.bar.doc.horizontal.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("University of North Carolina at Charlotte")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Vision Pro Research Study")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Text("Made by Amelia Eckard")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
