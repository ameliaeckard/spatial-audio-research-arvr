//
//  MainMenuView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 4/29/26.
//
//  Single-window UI that morphs between menu → loading → live controls
//  without opening or dismissing additional windows.
//

import SwiftUI

struct MainMenuView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(AppModel.self) private var appModel

    // Drives all three states from one window
    enum MenuState {
        case menu
        case loading
        case liveControls
    }

    @State private var menuState: MenuState = .menu
    @State private var loadingStatus: String = "Requesting permissions..."

    var body: some View {
        ZStack {
            switch menuState {
            case .menu:
                menuContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))

            case .loading:
                loadingContent
                    .transition(.opacity)

            case .liveControls:
                liveControlsContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
        .frame(width: 800, height: 600)
        .animation(.easeInOut(duration: 0.4), value: menuState)
        .task {
            if appModel.allRequiredProvidersAreSupported {
                await appModel.requestWorldSensingAuthorization()
            }
        }
        .task {
            await appModel.monitorSessionEvents()
        }
    }

    // MARK: - Menu

    private var menuContent: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Text("Spatial Audio Research")
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)

                Text("Enhancing object recognition for visually impaired users")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            if appModel.canEnterImmersiveSpace {
                Button {
                    Task { await startLiveDetection() }
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
                .frame(maxWidth: 600)
            } else {
                ErrorView()
            }

            Spacer()

            footerView
        }
        .padding(40)
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.6)
                    .tint(.green)

                Text("Starting Live Detection")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(loadingStatus)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: loadingStatus)
            }

            Spacer()

            footerView
        }
        .padding(40)
    }

    // MARK: - Live Controls

    private var liveControlsContent: some View {
        VStack(spacing: 0) {
            // Header row — title + status inline to save vertical space
            HStack(alignment: .center) {
                Text("Live Detection")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                if appModel.isReadyToRun {
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Tracking Active").font(.caption).foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Initializing ARKit…").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // Detecting badge — only shown when an object is selected
            if let object = appModel.selectedObject {
                HStack(spacing: 8) {
                    Text("Detecting:")
                    Text(object.rawValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(object.color)
                    if appModel.detectedObjects[object] == true {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 10)
            }

            Divider().padding(.horizontal, 32)

            // Object selection
            VStack(spacing: 10) {
                Text("Select Object to Detect")
                    .font(.headline)

                HStack(spacing: 24) {
                    ForEach(AppModel.DetectionObject.allCases, id: \.self) { object in
                        Button {
                            toggleObjectSelection(object)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(appModel.selectedObject == object
                                              ? object.color.opacity(0.2) : Color.clear)
                                        .frame(width: 64, height: 64)
                                    Image(systemName: object.icon)
                                        .font(.system(size: 26))
                                        .foregroundStyle(appModel.selectedObject == object
                                                         ? object.color : .primary)
                                    if appModel.detectedObjects[object] == true {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.system(size: 16))
                                            .offset(x: 20, y: -20)
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
            .padding(.horizontal, 32)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 32)

            // Detected objects list
            VStack(alignment: .leading, spacing: 8) {
                Text("Detected Objects")
                    .font(.headline)

                if appModel.trackedObjects.isEmpty {
                    Text("No objects detected — point the Vision Pro at your target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(appModel.trackedObjects.prefix(4)) { object in
                        HStack(spacing: 8) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text(object.label).font(.caption)
                            Spacer()
                            Text(String(format: "%.1fm", object.distance))
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", object.confidence * 100))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)

            Spacer()

            // Exit button
            Button {
                Task { await exitLiveDetection() }
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Exit Live Detection")
                }
                .font(.body)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.red.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 12)

            footerView
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 4) {
            Text("Amelia Eckard · University of North Carolina at Charlotte")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Vision Pro Research Study")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func startLiveDetection() async {
        withAnimation { menuState = .loading }
        loadingStatus = "Requesting world sensing permissions..."

        appModel.immersiveSpaceState = .inTransition

        loadingStatus = "Opening immersive space..."
        switch await openImmersiveSpace(id: "live-detection") {
        case .opened:
            loadingStatus = "Initializing ARKit session..."

            // Wait for the tracking provider to actually be running
            var waited = 0
            while !appModel.isReadyToRun && waited < 60 {
                try? await Task.sleep(for: .milliseconds(200))
                waited += 1
                if waited == 10 { loadingStatus = "Loading reference objects..." }
                if waited == 25 { loadingStatus = "Starting object tracking..." }
                if waited == 40 { loadingStatus = "Almost ready..." }
            }

            withAnimation { menuState = .liveControls }

        case .error, .userCancelled:
            appModel.immersiveSpaceState = .closed
            withAnimation { menuState = .menu }

        @unknown default:
            appModel.immersiveSpaceState = .closed
            withAnimation { menuState = .menu }
        }
    }

    private func exitLiveDetection() async {
        withAnimation { menuState = .loading }
        loadingStatus = "Closing session..."

        await dismissImmersiveSpace()

        try? await Task.sleep(for: .milliseconds(300))
        withAnimation { menuState = .menu }
    }

    private func toggleObjectSelection(_ object: AppModel.DetectionObject) {
        appModel.selectedObject = appModel.selectedObject == object ? nil : object
    }
}
