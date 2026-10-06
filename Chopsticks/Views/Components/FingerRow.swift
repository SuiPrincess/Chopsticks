import SwiftUI

/// 指の本数を表す4本のカプセル。遊び方の図解やメニューの装飾で使う。
struct FingerRow: View {
    let count: Int
    var color: Color = AppTheme.accent
    var small = false

    var body: some View {
        HStack(spacing: small ? 3 : 5) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(
                        i < count
                            ? AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.white.opacity(0.1))
                    )
                    .frame(width: small ? 8 : 12, height: i < count ? (small ? 24 : 36) : (small ? 14 : 20))
                    .shadow(color: i < count ? color.opacity(0.4) : .clear, radius: 4)
            }
        }
    }
}

/// 遊び方の図解用の小さな手カード
struct MiniHandCard: View {
    let count: Int
    var color: Color = AppTheme.player1Color
    var isDead = false
    var isDanger = false

    var body: some View {
        VStack(spacing: 6) {
            if isDead {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(height: 36)
            } else {
                FingerRow(count: count, color: isDanger ? .red : color)
            }
            Text("\(isDead ? 0 : count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isDanger ? Color(red: 1, green: 0.45, blue: 0.45) : .white.opacity(isDead ? 0.3 : 1))
        }
        .frame(width: 84, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDanger ? Color.red.opacity(0.7) : AppTheme.glassBorder, lineWidth: isDanger ? 1.5 : 0.5)
                )
        )
        .overlay(alignment: .topLeading) {
            if isDanger {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(6)
            }
        }
        .accessibilityHidden(true)
    }
}
