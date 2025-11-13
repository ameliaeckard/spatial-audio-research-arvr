//
//  ErrorView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//
//  View to display error messages related to ARKit support and permissions.
//

import SwiftUI

struct ErrorView: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text(errorMessage)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 40)
        }
        .padding()
    }
    
    @MainActor
    var errorMessage: String {
        if !appModel.allRequiredProvidersAreSupported {
            return "This app requires ARKit functionality that isn't supported on this device."
        } else if !appModel.allRequiredAuthorizationsAreGranted {
            return "Camera and world sensing permissions are required. Please enable them in Settings > Privacy & Security."
        } else {
            return "Unknown error occurred"
        }
    }
}