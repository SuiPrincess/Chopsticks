import SwiftUI

struct AIDifficultyPickerView: View {
    @Binding var difficulty: AIDifficulty
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.bgDark.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "cpu")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.accentGradient)
                    Text("CPUの強さ")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("好きなルールで遊べるフリー対戦です。勝ち負けは連勝記録に入ります")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    difficultyButton(.easy, icon: "tortoise.fill", description: "ランダムに行動する。気軽に遊びたいときに")
                    difficultyButton(.hard, icon: "bolt.fill", description: "先を読んで最善手を選ぶ。手ごわい！")
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
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    Text(description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.leading)
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
        .accessibilityAddTraits(difficulty == level ? .isSelected : [])
    }
}
