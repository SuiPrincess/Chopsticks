import SwiftUI

/// 実績解除のトースト1件
struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.goldGradient)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.yellow.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text("実績解除")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(.yellow.opacity(0.9))
                    .tracking(1)
                Text(achievement.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Text("+\(achievement.xpReward)XP")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .frame(maxWidth: 420)
    }
}

/// アプリ最上位に置き、解除された実績を順番にトースト表示する。
struct AchievementToastHost: View {
    @State private var store = AchievementStore.shared
    @State private var current: Achievement?

    var body: some View {
        VStack {
            if let current {
                AchievementToast(achievement: current)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .task(id: store.pendingToasts.first) {
            guard let next = store.pendingToasts.first else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { current = next }
            HapticManager.achievement()
            SoundManager.shared.play(.achievement)
            AccessibilityNotification.Announcement("実績解除: \(next.title)").post()
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) { current = nil }
            try? await Task.sleep(for: .milliseconds(300))
            if store.pendingToasts.first == next {
                store.pendingToasts.removeFirst()
            }
        }
    }
}
