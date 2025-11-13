//
//  ObjectBubble.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//
//  Component representing an interactive bubble for a reference object in the UI.
//

import SwiftUI

struct ObjectBubble: View {
    let objectName: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let isDetected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(isSelected ? color : .primary)
                    
                    // Detection indicator
                    if isDetected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                            .offset(x: 25, y: -25)
                    }
                }
                
                Text(objectName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? color : .primary)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .shadow(radius: isSelected ? 8 : 4)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.bouncy(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}