# App Store 申請用ドラフト

## アプリ名
Chopsticks - 割り箸バトル

## サブタイトル（30文字以内）
指1本から始まる頭脳バトル

## プロモーションテキスト（170文字以内）
懐かしの指遊び「割り箸」がスタイリッシュに進化！CPUラダーを勝ち上がるランク戦、白熱の対面2人プレイ、オンライン対戦。毒・爆弾・ミラーなどの特殊ルールで毎回違う戦いを。

## 説明文

指遊びの定番「割り箸（チョップスティックス）」を、美しいネオンデザインで遊べるiOSゲームにしました。

ルールはシンプル。自分の手を選んで相手の手をタップすると、攻撃した指の本数が相手に加算。5本になった手は死亡、全ての手が死んだら負け。

▼ 遊び方いろいろ
・ランク戦 — CPU Lv.1〜10を勝ち上がるラダー。勝つほど賢くなる
・フリー対戦 — かんたん／つよい／鬼の3段階。「鬼」に勝てたら自慢していい
・2人対戦 — 1台を挟んで向かい合って対戦
・近くの人と対戦 — Wi-Fi/Bluetoothでオフライン対戦
・オンライン対戦 — Game Centerで世界と対戦

▼ 特殊ルールで無限に遊べる
オーバーフロー／分割／復活／3本手／毒／爆弾／ミラー／ダブルタップ。「おまかせルール」でランダムに組み合わせれば毎回違うゲームに。

▼ 遊びやすさ
・迷ったらヒント — AIが最善手を教えてくれる
・中断してもOK — 自動保存でいつでも「続きから」
・戦績記録 — 勝率・連勝・連続プレイ日数
・気持ちいい演出 — 効果音・ハプティクス・パーティクル（設定でOFF可）

シンプルなのに奥深い。1ゲーム1分の頭脳バトルをどうぞ。

## キーワード（100文字以内）
割り箸,チョップスティックス,指遊び,ボードゲーム,対戦,2人,オフライン,頭脳,パズル,chopsticks

## カテゴリ
ゲーム > ボード / 戦略

## 収益化（App Store Connectでの設定が必要）

アプリ内課金（StoreKit 2）。以下のプロダクトをASCで作成する。
ローカルテストは `Chopsticks/Products.storekit` をXcodeのスキーム設定
（Run > Options > StoreKit Configuration）で選択すればASC設定なしで動作確認できる。

| Product ID | 種類 | 内容 | 参考価格 |
|---|---|---|---|
| `com.suiprincess.chopsticks.premium` | 非消耗型 | プレミアムテーマ解放＋AIヒント無制限 | ¥480 |
| `com.suiprincess.chopsticks.tip.small` | 消耗型 | 投げ銭（おにぎり） | ¥160 |
| `com.suiprincess.chopsticks.tip.large` | 消耗型 | 投げ銭（お弁当） | ¥600 |

収益設計:
- 無料でフル対戦可能（ゲームプレイは一切課金で制限しない＝レビューを守る）
- ヒントのみ1日3回制限 → プレミアムで無制限（自然な誘導）
- プレミアムテーマ5種（サンセット/マトリックス/サクラ/ゴールド/ディープシー）
- デイリーリマインダー通知（オプトイン）＋連続プレイ日数でリテンション

## 備考（審査メモ）
- オンライン対戦はGame Center必須
- 近接対戦はローカルネットワーク権限を使用（NSLocalNetworkUsageDescription設定済み）
- 広告なし。課金はStoreKit 2のIAPのみ（上記）。復元ボタンあり
- 通知はオプトイン（設定画面のトグルで許可リクエスト）
- Game Centerリーダーボード（任意）: ID `com.suiprincess.chopsticks.rank`（ランク戦の到達レベル）を
  App Store Connectで作成すると自動で送信される。未設定でも問題なく動作する
- Game Center実績（任意）: 以下のIDをApp Store Connectで作成すると自動で解除される。未設定でも問題なく動作する
  - `com.suiprincess.chopsticks.firstwin` — CPU戦で初勝利
  - `com.suiprincess.chopsticks.streak3` — 3連勝
  - `com.suiprincess.chopsticks.streak10` — 10連勝
  - `com.suiprincess.chopsticks.perfect` — 手を1本も失わずに勝利（PERFECT）
  - `com.suiprincess.chopsticks.oni` — 難易度「鬼」に勝利
  - `com.suiprincess.chopsticks.rankmax` — CPU Lv.10を撃破（全CPU制覇）
