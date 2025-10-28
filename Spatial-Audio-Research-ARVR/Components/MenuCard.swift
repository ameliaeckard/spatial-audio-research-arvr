//
//  MenuCard.swift
//  Spatial-Audio-Research-ARVR
//  Updated by Amelia Eckard on 10/21/25.
//
//  Component for the main menu of the app. Used in the main menu view.
//

import SwiftUI

struct MenuCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(color)
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
                .frame(width: 20) // Force spacing
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.title3)
                .frame(width: 30)
        }
        .padding(24)
        .frame(width: 500, height: 110) // Increased height
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
}
