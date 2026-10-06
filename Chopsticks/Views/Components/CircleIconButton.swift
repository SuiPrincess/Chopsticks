import SwiftUI

/// 見た目は34ptの丸、タップ領域は44ptを確保するアイコンボタン。
struct CircleIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                )
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }
}
