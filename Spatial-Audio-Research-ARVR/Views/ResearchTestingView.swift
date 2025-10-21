//
//  ResearchTestingView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//
//  Holds the research testing module/view for controlled scenarios using SwiftUI.
//
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
                openWindow(id: "main-menu")
                dismissWindow(id: "research-testing")
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
        .padding()
    }
}
