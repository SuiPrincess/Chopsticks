import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGSize
    var rotation: Double
    var offset: CGSize
    var opacity: Double
}

/// 勝利時の紙吹雪。表示されると自動で降り、数秒後に片付く。
struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var didLaunch = false

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(piece.rotation))
                    .offset(piece.offset)
                    .opacity(piece.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !didLaunch else { return }
            didLaunch = true
            let colors: [Color] = [.red, .yellow, .green, .blue, .pink, .orange, .cyan, .purple]
            pieces = (0..<40).map { _ in
                ConfettiPiece(
                    color: colors.randomElement() ?? .yellow,
                    size: CGSize(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 10...20)),
                    rotation: .random(in: 0...360),
                    offset: CGSize(width: CGFloat.random(in: -30...30), height: CGFloat.random(in: -120 ... -60)),
                    opacity: 1
                )
            }
            // 初期配置が一度描画されてからアニメーションさせる（同じフレームで更新すると動かない）
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 2.0)) {
                pieces = pieces.map { p in
                    var moved = p
                    moved.offset = CGSize(width: CGFloat.random(in: -200...200), height: CGFloat.random(in: 200...520))
                    moved.rotation += .random(in: 180...720)
                    moved.opacity = 0
                    return moved
                }
            }
            try? await Task.sleep(for: .seconds(2.4))
            pieces = []
        }
    }
}
