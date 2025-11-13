//
//  ContentView.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/16/25.
//
//  Holds the main view for the app using SwiftUI.
//
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    var body: some View {
        MainMenuView()
    }
}
#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}