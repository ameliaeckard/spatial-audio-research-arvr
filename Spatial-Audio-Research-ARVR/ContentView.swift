//
//  ContentView.swift
//  Spatial-Audio-Research-ARVR
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
