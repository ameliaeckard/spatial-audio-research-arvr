import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var activeWindow: String = "main-menu"
    
    func openWindow(_ windowId: String) {
        activeWindow = windowId
    }
}
