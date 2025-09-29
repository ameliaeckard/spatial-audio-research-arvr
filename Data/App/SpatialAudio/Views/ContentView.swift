//
//  ContentView.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        VStack {
            switch appModel.currentView {
            case .dashboard:
                Text("Dashboard Screen")
            case .objectDetection:
                Text("Object Detection Screen")
            case .settings:
                Text("Settings Screen")
            case .statistics:
                Text("Statistics Screen")
            }
            HStack {
                Button("Dashboard") {
                    appModel.currentView = .dashboard
                }
                Button("Detection") {
                    appModel.currentView = .objectDetection
                }
                Button("Settings") {
                    appModel.currentView = .settings
                }
                Button("Statistics") {
                    appModel.currentView = .statistics
                }
            }
        }
        .padding()
    }
}
