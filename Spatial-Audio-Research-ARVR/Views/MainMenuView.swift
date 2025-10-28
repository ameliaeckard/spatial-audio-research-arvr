//
//  MainMenuView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/28/25.
//
//  Holds the main menu view for the app using SwiftUI.
//

import SwiftUI

struct MainMenuView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(AppModel.self) private var appModel
    
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
                .frame(minHeight: 30)
            
            if appModel.canEnterImmersiveSpace {
                VStack(spacing: 30) {
                    Button {
                        Task {
                            guard appModel.immersiveSpaceState == .closed else {
                                print("Immersive space is already open or in transition")
                                return
                            }
                            
                            appModel.immersiveSpaceState = .inTransition
                            dismissWindow(id: "main-menu")
                            try? await Task.sleep(for: .milliseconds(200))
                            
                            switch await openImmersiveSpace(id: "live-detection") {
                            case .opened:
                                print("Immersive space opened successfully")
                            case .error:
                                print("Failed to open immersive space")
                                appModel.immersiveSpaceState = .closed
                                openWindow(id: "main-menu")
                            case .userCancelled:
                                print("User cancelled immersive space")
                                appModel.immersiveSpaceState = .closed
                                openWindow(id: "main-menu")
                            @unknown default:
                                appModel.immersiveSpaceState = .closed
                                openWindow(id: "main-menu")
                            }
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
                    .frame(height: 110)
                    .disabled(appModel.immersiveSpaceState != .closed)
                    .opacity(appModel.immersiveSpaceState != .closed ? 0.5 : 1.0)
                    
                    Button {
                        Task {
                            dismissWindow(id: "main-menu")
                            try? await Task.sleep(for: .milliseconds(200))
                            openWindow(id: "research-testing")
                        }
                    } label: {
                        MenuCard(
                            title: "Research Testing",
                            subtitle: "Controlled scenarios for data collection",
                            icon: "chart.bar.doc.horizontal.fill",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(height: 110)
                }
                .frame(maxWidth: 600)
            } else {
                ErrorView()
            }
            
            Spacer()
                .frame(minHeight: 30)
            
            VStack(spacing: 8) {
                Text("University of North Carolina at Charlotte")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Vision Pro Research Study")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 40)
        }
        .frame(width: 800, height: 600)
        .padding(40)
        .task {
            if appModel.allRequiredProvidersAreSupported {
                await appModel.requestWorldSensingAuthorization()
            }
        }
        .task {
            await appModel.monitorSessionEvents()
        }
    }
}
