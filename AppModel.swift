//
//  AppModel.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import Foundation
import SwiftUI
import Combine

@Observable
class AppModel {
    var currentView: ViewState = .dashboard
    var isARActive = false
    var sessionStartTime: Date?
    var currentSession: ResearchSession?
    
    var immersiveSpaceState: ImmersiveSpaceState = .closed
    let immersiveSpaceID = "ImmersiveSpace"

    enum ViewState {
        case dashboard
        case objectDetection
        case settings
        case statistics
    }
    
    enum ImmersiveSpaceState {
        case open
        case closed
        case inTransition
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
