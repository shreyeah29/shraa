import SwiftUI
import SwiftData

struct WellnessView: View {
    @State private var segment = 0
    private let segments = ["Calories", "Gym", "Gallery", "Skincare"]
    private let icons = ["fork.knife", "dumbbell.fill", "photo.stack.fill", "sparkles"]

    var body: some View {
        VStack(spacing: 0) {
            segmentBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
            Divider().opacity(0.3)

            switch segment {
            case 0: NutritionView()
            case 1: GymProgressView()
            case 2: ProgressGalleryView()
            default: SkincareView()
            }
        }
        .background(Color.surfaceBase)
    }

    private var segmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(segments.indices, id: \.self) { i in
                    WellnessTab(title: segments[i], icon: icons[i], isSelected: segment == i) {
                        withAnimation(.spring(response: 0.3)) { segment = i }
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }
}

private struct WellnessTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).imageScale(.small)
                Text(title).fontWeight(isSelected ? .semibold : .regular)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AnyView(LinearGradient.brand) : AnyView(Color.clear))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.secondary.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
