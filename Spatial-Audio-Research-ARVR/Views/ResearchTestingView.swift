//
//  ResearchTestingView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 11/3/25.
//
//  Holds the research testing module/view for controlled scenarios using SwiftUI.
//

import SwiftUI

struct ResearchTestingView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Research Testing View")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Controlled scenarios for data collection will go here")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button {
                Task {
                    // Close research testing FIRST
                    dismissWindow(id: "research-testing")
                    
                    // Small delay for smooth transition
                    try? await Task.sleep(for: .milliseconds(200))
                    
                    // Reopen main menu
                    openWindow(id: "main-menu")
                    print("Returned to main menu from research testing")
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to Menu")
                }
                .font(.title3)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 800, height: 600)
        .padding()
    }
}
