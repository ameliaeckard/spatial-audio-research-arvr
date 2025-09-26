//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import Foundation
import SwiftUI
import Combine

class AppModel: ObservableObject {
    @Published var currentView: ViewState = .dashboard
    @Published var isARActive = false
    @Published var sessionStartTime: Date?
    @Published var currentSession: ResearchSession?

    enum ViewState {
        case dashboard
        case objectDetection
        case settings
        case statistics
    }

    func startNewSession() {
        currentSession = ResearchSession()
        sessionStartTime = Date()
        isARActive = true
    }

    func endSession() {
        currentSession?.endTime = Date()
        isARActive = false
    }
}

struct ResearchSession: Identifiable {
    let id = UUID()
    let startTime = Date()
    var endTime: Date?
}
