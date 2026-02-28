import SwiftUI

struct AIDifficultyPickerView: View {
    @Binding var difficulty: AIDifficulty
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.bgDark.ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.accentGradient)
                    Text("CPU難易度")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 12) {
                    difficultyButton(.easy, icon: "tortoise.fill", description: "ランダムに行動する")
                    difficultyButton(.hard, icon: "bolt.fill", description: "最善手を選ぶ")
                }
                .padding(.horizontal, 24)

                Button("次へ") { onStart() }
                    .buttonStyle(GlassButtonStyle())
                    .padding(.horizontal, 40)
            }
        }
    }

    @ViewBuilder
    private func difficultyButton(_ level: AIDifficulty, icon: String, description: String) -> some View {
        Button {
            difficulty = level
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if difficulty == level {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(difficulty == level ? AppTheme.accent.opacity(0.12) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                difficulty == level ? AppTheme.accent.opacity(0.5) : AppTheme.glassBorder,
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}
