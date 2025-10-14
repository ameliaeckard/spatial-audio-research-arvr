import SwiftUI

struct MainMenuView: View {
    @State private var showingLiveMode = false
    @State private var showingTestingMode = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    Text("Spatial Audio")
                        .font(.extraLargeTitle)
                        .fontWeight(.bold)
                    
                    Text("Object Recognition Research")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                
                Spacer()
                
                VStack(spacing: 24) {
                    NavigationLink(destination: LiveDetectionView()) {
                        MenuButton(
                            title: "Live Mode",
                            subtitle: "Real-time object detection",
                            icon: "eye.fill",
                            color: .blue
                        )
                    }
                    
                    NavigationLink(destination: TestingView()) {
                        MenuButton(
                            title: "Research Testing",
                            subtitle: "Controlled scenario testing",
                            icon: "chart.bar.doc.horizontal.fill",
                            color: .green
                        )
                    }
                }
                
                Spacer()
                
                Text("Vision Pro Spatial Audio Study")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
            .padding()
            .frame(minWidth: 600, minHeight: 700)
        }
    }
}

struct MenuButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(color)
                .frame(width: 70)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    MainMenuView()
}