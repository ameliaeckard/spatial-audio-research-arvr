//
//  AccessibilityManager.swift
//  SpatialSight - Apple Vision Pro Research App
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
class AccessibilityManager: ObservableObject {
    @Published var isVoiceOverEnabled = false
    @Published var isHighContrastEnabled = false
    @Published var isLargeTextEnabled = false
    @Published var reduceMotionEnabled = false
    @Published var preferredVoice: AccessibilityVoice = .enhanced
    @Published var gestureControlsEnabled = true
    @Published var hapticFeedbackEnabled = true
    @Published var dwellControlEnabled = false
    @Published var pointerControlEnabled = false
    
    @Published var navigationAnnouncementsEnabled = true
    @Published var detailedObjectDescriptions = true
    @Published var spatialAudioGuidanceEnabled = true
    @Published var vibrateOnObjectDetection = true
    
    @Published var researchModeEnabled = false
    @Published var detectionConfidenceAnnouncement = true
    @Published var timeBasedProgress = true
    @Published var accuracyFeedbackEnabled = true
    
    private var cancellables = Set<AnyCancellable>()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    enum AccessibilityVoice: String, CaseIterable {
        case standard = "Standard"
        case enhanced = "Enhanced"
        case compact = "Compact"
        case premium = "Premium"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    init() {
        observeAccessibilityChanges()
        setupAccessibilityNotifications()
    }
    
    // MARK: - Accessibility System Observation
    private func observeAccessibilityChanges() {
        // Monitor system accessibility settings
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateVoiceOverStatus()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateHighContrastStatus()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateReduceMotionStatus()
            }
            .store(in: &cancellables)
        
        // Observe object detection for accessibility feedback
        NotificationCenter.default.publisher(for: .objectDetected)
            .compactMap { $0.object as? DetectedObject }
            .sink { [weak self] object in
                self?.handleObjectDetectionForAccessibility(object)
            }
            .store(in: &cancellables)
    }
    
    private func setupAccessibilityNotifications() {
        // Custom research notifications
        NotificationCenter.default.publisher(for: .accuracyMilestoneReached)
            .sink { [weak self] notification in
                if let milestone = notification.object as? Double {
                    self?.announceAccuracyMilestone(milestone)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Accessibility Status Updates
    private func updateVoiceOverStatus() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
    }
    
    private func updateHighContrastStatus() {
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    private func updateReduceMotionStatus() {
        reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    }
    
    func initializeAccessibilityFeatures() async {
        updateVoiceOverStatus()
        updateHighContrastStatus()
        updateReduceMotionStatus()
        
        // Configure feedback generator
        feedbackGenerator.prepare()
        
        // Announce app launch to VoiceOver users
        if isVoiceOverEnabled {
            announceToVoiceOver("SpatialSight research app loaded. Ready to begin object detection session.")
        }
    }
    
    // MARK: - VoiceOver Integration
    func announceToVoiceOver(_ message: String, priority: AccessibilityNotificationPriority = .medium) {
        guard isVoiceOverEnabled else { return }
        
        DispatchQueue.main.async {
            let notification: UIAccessibility.Notification = priority == .high ? .announcement : .screenChanged
            UIAccessibility.post(notification: notification, argument: message)
        }
    }
    
    func createAccessibilityElement(for object: DetectedObject, in view: UIView) -> UIAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: view)
        
        // Set basic properties
        element.accessibilityLabel = createAccessibilityLabel(for: object)
        element.accessibilityValue = createAccessibilityValue(for: object)
        element.accessibilityHint = createAccessibilityHint(for: object)
        element.accessibilityTraits = [.button, .playsSound]
        
        // Set frame (would be calculated based on object's screen position)
        element.accessibilityFrame = calculateAccessibilityFrame(for: object)
        
        // Custom actions
        let playAudioAction = UIAccessibilityCustomAction(name: "Play Audio Cue") { _ in
            NotificationCenter.default.post(name: .playObjectAudio, object: object)
            return true
        }
        
        let getDirectionsAction = UIAccessibilityCustomAction(name: "Get Directions") { _ in
            NotificationCenter.default.post(name: .getDirections, object: object)
            return true
        }
        
        element.accessibilityCustomActions = [playAudioAction, getDirectionsAction]
        
        return element
    }
    
    private func createAccessibilityLabel(for object: DetectedObject) -> String {
        return "\(object.type.displayName), detected at \(formatTime(object.detectionTime))"
    }
    
    private func createAccessibilityValue(for object: DetectedObject) -> String {
        let distance = formatDistance(object.distanceFromUser)
        let confidence = Int(object.confidence * 100)
        let confidenceText = detectionConfidenceAnnouncement ? ", \(confidence)% confidence" : ""
        
        return "\(distance)\(confidenceText)"
    }
    
    private func createAccessibilityHint(for object: DetectedObject) -> String {
        switch object.type {
        case .stairs:
            return "Navigation hazard. Double tap for audio guidance."
        case .door:
            return "Exit or entrance. Double tap for directions."
        case .chair, .sofa:
            return "Seating available. Double tap for audio cue."
        case .table, .desk:
            return "Surface detected. Double tap for spatial audio."
        default:
            return "Double tap for audio guidance to this object."
        }
    }
    
    private func calculateAccessibilityFrame(for object: DetectedObject) -> CGRect {
        // In a real implementation, this would project the 3D object position
        // to screen coordinates using the camera's projection matrix
        // For now, return a placeholder frame
        return CGRect(x: 100, y: 100, width: 100, height: 100)
    }
    
    // MARK: - Object Detection Accessibility Feedback
    private func handleObjectDetectionForAccessibility(_ object: DetectedObject) {
        // Provide immediate accessibility feedback
        if isVoiceOverEnabled && navigationAnnouncementsEnabled {
            let announcement = createObjectDetectionAnnouncement(object)
            announceToVoiceOver(announcement, priority: object.type == .stairs ? .high : .medium)
        }
        
        // Haptic feedback
        if hapticFeedbackEnabled && vibrateOnObjectDetection {
            provideHapticFeedback(for: object)
        }
        
        // Update accessibility elements
        NotificationCenter.default.post(name: .updateAccessibilityElements, object: object)
    }
    
    private func createObjectDetectionAnnouncement(_ object: DetectedObject) -> String {
        let objectName = object.type.displayName
        let distance = formatDistance(object.distanceFromUser)
        
        if object.type == .stairs {
            return "Caution: \(objectName) \(distance)"
        } else {
            return "\(objectName) \(distance)"
        }
    }
    
    private func provideHapticFeedback(for object: DetectedObject) {
        let intensity: UIImpactFeedbackGenerator.FeedbackStyle
        
        switch object.type {
        case .stairs:
            intensity = .heavy  // Safety priority
        case .door:
            intensity = .medium // Important for navigation
        default:
            intensity = .light  // General objects
        }
        
        let feedbackGenerator = UIImpactFeedbackGenerator(style: intensity)
        feedbackGenerator.impactOccurred()
    }
    
    // MARK: - Research-Specific Accessibility Features
    func announceAccuracyMilestone(_ accuracy: Double) {
        guard isVoiceOverEnabled && accuracyFeedbackEnabled else { return }
        
        let percentage = Int(accuracy * 100)
        let message: String
        
        if accuracy >= 0.85 {
            message = "Excellent! Research target achieved: \(percentage)% accuracy"
        } else if accuracy >= 0.75 {
            message = "Good progress: \(percentage)% accuracy. Target is 85%"
        } else {
            message = "Current accuracy: \(percentage)%. Keep practicing to reach 85% target"
        }
        
        announceToVoiceOver(message, priority: .high)
    }
    
    func announceSessionProgress(objectsDetected: Int, timeElapsed: TimeInterval) {
        guard isVoiceOverEnabled && timeBasedProgress else { return }
        
        let minutes = Int(timeElapsed / 60)
        let timeText = minutes > 0 ? "\(minutes) minutes" : "\(Int(timeElapsed)) seconds"
        
        let message = "Session progress: \(objectsDetected) objects detected in \(timeText)"
        announceToVoiceOver(message)
    }
    
    func announceNavigationGuidance(_ guidance: NavigationGuidance) {
        guard isVoiceOverEnabled else { return }
        
        let message = "Navigation: \(guidance.instructions)"
        announceToVoiceOver(message, priority: .high)
    }
    
    // MARK: - Utility Functions
    private func formatDistance(_ distance: Float) -> String {
        if distance < 0.5 {
            return "very close"
        } else if distance < 1.0 {
            return "nearby"
        } else if distance < 2.0 {
            return "\(Int(distance)) meter away"
        } else {
            return "\(Int(distance)) meters away"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Settings Management
    func updateAccessibilitySettings() {
        // Apply accessibility settings to the app
        if isLargeTextEnabled {
            // Would increase font sizes throughout the app
        }
        
        if isHighContrastEnabled {
            // Would apply high contrast color scheme
        }
        
        if reduceMotionEnabled {
            // Would disable or reduce animations
        }
    }
    
    func toggleDetailedDescriptions() {
        detailedObjectDescriptions.toggle()
        let status = detailedObjectDescriptions ? "enabled" : "disabled"
        announceToVoiceOver("Detailed object descriptions \(status)")
    }
    
    func toggleResearchMode() {
        researchModeEnabled.toggle()
        let status = researchModeEnabled ? "enabled" : "disabled"
        announceToVoiceOver("Research mode \(status). Additional metrics and feedback available.")
    }
    
    // MARK: - Custom Rotor Support
    func createObjectTypeRotor(objects: [DetectedObject]) -> UIAccessibilityCustomRotor {
        let rotor = UIAccessibilityCustomRotor(name: "Object Types") { predicate in
            // Implementation for navigating between different object types
            // This would allow VoiceOver users to quickly jump between chairs, tables, etc.
            return nil // Placeholder
        }
        
        return rotor
    }
    
    func createDistanceRotor(objects: [DetectedObject]) -> UIAccessibilityCustomRotor {
        let rotor = UIAccessibilityCustomRotor(name: "By Distance") { predicate in
            // Implementation for navigating objects by distance (closest first)
            return nil // Placeholder
        }
        
        return rotor
    }
}

// MARK: - Custom Notification Names
extension Notification.Name {
    static let accuracyMilestoneReached = Notification.Name("accuracyMilestoneReached")
    static let updateAccessibilityElements = Notification.Name("updateAccessibilityElements")
    static let playObjectAudio = Notification.Name("playObjectAudio")
    static let getDirections = Notification.Name("getDirections")
}

// MARK: - Accessibility Priority
enum AccessibilityNotificationPriority {
    case low
    case medium
    case high
}
