# ローカライズ保守ツール

キーは**日本語の原文**。`en.lproj/Localizable.strings` に英訳を置き、
`ja.lproj` は意図的に空（キーが見つからない場合はキー自体＝日本語が表示される）。

## 使い方

UI文字列を追加・変更したら:

1. `translations.py` の辞書に `"日本語キー": "English"` を追加
   - 補間は SwiftUI/Foundation のキー形式で書く: `\(Int)` → `%lld`、`\(String)` → `%@`
   - 英訳側で語順を変える場合は `%1$lld` などの位置指定子を使う
2. 生成＋検証:
   ```
   python3 tools/localization/gen_localization.py
   ```
   コード中の日本語キーを全抽出して翻訳の**欠落0**を機械検証し、
   `.strings` を再生成する（欠落・型不明の補間があると失敗する）

## コード側のルール（CLAUDE.md にも記載）

- `Text("リテラル")` / `Button("リテラル")` などは自動でキーになる（変更不要）
- `String` 型の文脈（モデルのname、バナー文言、share文など）は `String(localized: "...")`
- **三項演算子で文字列を選ぶ場合は各分岐を `String(localized:)` で包む**
  （`cond ? "A" : "B"` は String に推論されローカライズされない）
- Viewヘルパーの引数は `LocalizedStringKey` 型にする
