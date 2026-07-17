# Chopsticks 開発ガイド

SwiftUI製iOSゲーム（iOS 17+ / Xcode 16）。詳細はREADME.md参照。

## プロジェクト構成の要点

- ルールの実装は必ず `Models/GameState.swift` の `apply(_:)` に集約する。
  実プレイ（GameViewModel）とAIシミュレーション（AIEngine）が同じコードを通ることで
  挙動の一致を保証している。ルール追加時もここに書くこと。
- `GameState`/`GameConfig`/`GameAction` はCodable。マルチプレイ同期
  （MultiplayerMessage）と中断保存（GameSessionStore）の両方がこれに依存する。
  フィールド追加時はデコード互換性に注意（古い保存データはdecode失敗で単に無視される）。
- シングルトン: GameStats（戦績）/ GameSessionStore（中断保存）/
  SettingsStore（設定・ヒント回数）/ SoundManager / HapticManager /
  StoreManager（StoreKit 2課金）。すべて@MainActor。
  ThemeStoreのみ非MainActor（AppThemeのstaticアクセサから参照するため）。
- 課金: プレミアム買い切り＝全テーマ解放＋ヒント無制限。プロダクトIDは
  docs/app-store.md参照。ローカルテストはProducts.storekitをスキームで選択。
  「ゲームプレイ自体を課金で制限しない」が設計原則。
- AppThemeはcomputed varでThemeStore.shared.currentを返す。
  新しい色を足すときはThemeの全テーマ定義に追加すること。
- AI探索はメインアクター外（Task.detached）で実行する。AIEngineはnonisolatedな
  純粋ロジックのままにすること。

## ファイル追加時の手順

1. Swiftファイルを適切なディレクトリに置く
2. `Chopsticks/Chopsticks.xcodeproj/project.pbxproj` に登録
   （XcodeGenがあれば `cd Chopsticks && xcodegen` で再生成、
   手編集の場合はPBXBuildFile/PBXFileReference/グループ/Sourcesフェーズの4箇所）
3. `Chopsticks/project.yml` はXcodeGen用の正。pbxprojと両方を同期すること
4. テストは `Chopsticks/ChopsticksTests/`（アプリターゲットからは除外されている）

## テスト

- Xcode: Cmd+U（ChopsticksTestsターゲット、TEST_HOST=アプリ）
- CI: .github/workflows/ci.yml（macOSランナー・iOSシミュレータ）
- Linux環境にはSwiftがないため、ロジック変更の検証には
  tree-sitter-swiftでの構文チェックと、必要ならPythonでの参照実装が有効

## known quirks

- ランク戦は標準ルール固定（MenuView.makeRankedConfig）。ユーザーのルール設定に
  影響されてはいけない（毒ルール等でランク攻略が壊れるため）
- マルチプレイのリマッチではホストが必ず `.gameStart(state)` を送って盤面を配布する
  （両端末が独立にnewGame()するとUUIDが食い違い操作不能になる）
- MultiplayerServiceの実装はonMessageReceived未設定時に受信メッセージをバッファする。
  新しい実装を追加する場合も同じ挙動にすること
- 効果音はSounds/*.wav（scratchpadのPythonスクリプトで合成生成したもの）。
  差し替える場合は同名で上書きすればpbxproj変更は不要
- GameConfigはカスタムinit(from:)でdecodeIfPresent。フィールド追加時も
  同じパターンで書くこと（旧保存データ・バージョン混在マルチプレイ互換のため）
- ローカライズ: キーは日本語原文。en.lprojに英訳、ja.lprojは意図的に空。
  String型の文脈はString(localized:)、三項演算子は各分岐を包む。
  文字列を追加したら tools/localization/gen_localization.py で欠落0を検証すること
- Products.storekitはproject.ymlのexcludesに入っているため、xcodegen再生成後は
  Xcodeナビゲータから消える（ビルドには無関係。必要なら手で再追加）
