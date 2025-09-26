
import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
class AccessibilityManager {
    var isVoiceOverEnabled = false
    var isHighContrastEnabled = false
    var textSize: AccessibilityTextSize = .medium
    var hapticsEnabled = true
    var audioDescriptionsEnabled = true
    
    enum AccessibilityTextSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        case extraLarge = "Extra Large"
        
        var scaleFactor: CGFloat {
            switch self {
            case .small: return 0.85
            case .medium: return 1.0
            case .large: return 1.2
            case .extraLarge: return 1.4
            }
        }
    }
    
    init() {
        checkAccessibilitySettings()
        observeAccessibilityChanges()
    }
    
    private func checkAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    private func observeAccessibilityChanges() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
    }
    
    func announceToVoiceOver(_ message: String) {
        guard isVoiceOverEnabled else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    func provideHapticFeedback() {
        guard hapticsEnabled else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}
